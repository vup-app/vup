import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:pool/pool.dart';
import 'package:random_string/random_string.dart';
import 'package:stash/stash_api.dart';
import 'package:vup/generic/state.dart';
import 'package:vup/library/compute.dart';
import 'package:vup/utils/download/generate_download_config.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:dio/dio.dart' as dio;
import 'package:stash_hive/stash_hive.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:filesize/filesize.dart';
import 'package:filesystem_dac/dac.dart';

import 'package:mime/mime.dart';
import 'package:path/path.dart';
import 'package:mno_streamer/parser.dart';
import 'package:sodium/sodium.dart' hide Box;
import 'package:uuid/uuid.dart';
import 'package:vup/model/sync_task.dart';
import 'package:skynet/skynet.dart';
import 'package:skynet/src/mysky_provider/native.dart';
import 'package:vup/service/base.dart';
import 'package:skynet/src/encode_endian/encode_endian.dart';
import 'package:skynet/src/encode_endian/base.dart';
import 'package:skynet/src/mysky/encrypted_files.dart';
import 'package:vup/utils/process_image.dart';
import 'package:watcher/watcher.dart';
import 'package:skynet/src/utils/base32.dart';

import 'mysky.dart';

const skappDomain = 'vup.hns';

//
// const metadataMaxFileSizeNative = 8 * 1000 * 1000;

class SkyFS extends VupService {}

final bookParsers = {
  ".epub": EpubParser(),
  ".cbz": CBZParser(),
  // '.pdf': PdfParser(pdfFactory),
};

const supported3DModelExtensions = [
  '.3mf',
  '.amf',
  '.off',
  '.stl',
];

Future<String> hashFileSha256(File file) async {
  var output = new AccumulatorSink<Digest>();
  var input = sha256.startChunkedConversion(output);
  await file.openRead().forEach(input.add);
  input.close();
  final hash = output.events.single;
  return hash.toString();
}

Future<String> hashFileSha1(File file) async {
  var output = new AccumulatorSink<Digest>();
  var input = sha1.startChunkedConversion(output);
  await file.openRead().forEach(input.add);
  input.close();
  final hash = output.events.single;
  return hash.toString();
}

class StorageService extends VupService {
  final MySkyService mySky;
  late final FileSystemDAC dac;
  final Box localFiles;

  final Box<SyncTask> syncTasks;
  final String temporaryDirectory;
  final String dataDirectory;

  final bool isRunningInFlutterMode;

  StorageService(
    this.mySky, {
    required this.isRunningInFlutterMode,
    required this.temporaryDirectory,
    required this.syncTasks,
    required this.localFiles,
    required this.dataDirectory,
  });

  late NativeMySkyProvider mySkyProvider;

  get trashPath => 'home/.trash';

  late dio.Dio dioClient;

  Future<void> init(Sodium sodium) async {
    mySkyProvider = NativeMySkyProvider(mySky.skynetClient);

    dioClient = dio.Dio();

    final logger = SkyFS();

    final dbDir = Directory(join(
      dataDirectory,
      'stash',
    ));
    dbDir.createSync(recursive: true);

    // Creates a store
    final hiveStore = newHiveDefaultCacheStore(path: dbDir.path);

    final thumbnailCache = hiveStore.cache<Uint8List>(
      name: 'thumbnailCache',
      maxEntries: 1000,
    );

    dac = FileSystemDAC(
      mySkyProvider: mySkyProvider,
      skapp: skappDomain,
      sodium: sodium,
      debugEnabled: true,
      onLog: (s) => logger.verbose(s),
      thumbnailCache: thumbnailCache,
    );
    await dac.init();
  }

  Future<FileData?> uploadOneFile(
    String path,
    File file, {
    bool create = true,
    int? modified,
    bool encrypted = true,
    // Function? onHashAvailable,
    bool returnFileData = false,
    bool metadataOnly = false,
    FileStateNotifier? fileStateNotifier,
  }) async {
    final changeNotifier = dac.getUploadingFilesChangeNotifier(
      dac.parsePath(path).toString(),
    );
    verbose('getUploadingFilesChangeNotifier $path');

    String? name;
    try {
      final multihash = await getMultiHashForFile(file);
      /*     if (onHashAvailable != null) {
        onHashAvailable(multihash);
      } */

      fileStateNotifier ??=
          storageService.dac.getFileStateChangeNotifier(multihash);

      final sha1Hash = await getSHA1HashForFile(file);
      name = basename(file.path);

      final ext = extension(file.path).toLowerCase();

      var generateMetadata = supportedImageExtensions
              .contains(ext) /* &&
              file.lengthSync() < 20000000 */
          ; // 20 MB

      Map<String, dynamic> additionalExt = {};

      File? videoThumbnailFile;
      String? customMimeType;

      //if (generateMetadata) {
      if (supportedAudioExtensionsForPlayback.contains(ext) || ext == '.opus') {
        try {
          final args = [
            '-v',
            'quiet',
            '-print_format',
            'json',
            '-show_format',
            '-show_streams',
            file.path,
          ];

          final res = await ffMpegProvider.runFFProbe(args);

          final metadata = json.decode(res.stdout);

          final format = metadata['format'];

          final audioExt = {
            'format_name': format['format_name'],
            'duration': double.tryParse(format['duration']),
            'bit_rate': int.tryParse(format['bit_rate']),
          };

          if (audioExt['format_name'] == 'ogg') {
            customMimeType = 'audio/ogg';
          }

          final streams = metadata['streams'] ?? [];

          final Map<String, dynamic> tags = (streams.isEmpty
                  ? <String, dynamic>{}
                  : streams[0]?['tags']?.cast<String, dynamic>()) ??
              <String, dynamic>{};
          tags.addAll((format['tags'] ?? {}).cast<String, dynamic>());

          // verbose('tags $tags');

          if (tags.isNotEmpty) {
            for (final key in tags.keys.toList()) {
              tags[key.toLowerCase()] = tags[key];
            }
            final includedTags = [
              'title',
              'artist',
              'album',
              'album_artist',
              'track',
              'date',
              'genre',
              'bpm',
              'isrc',
              'comment',
              'description',
            ];
            for (final tag in includedTags) {
              if (tags[tag] != null) {
                audioExt[tag] = tags[tag];
              }
            }
            if (tags['tsrc'] != null) {
              audioExt['isrc'] = tags['tsrc'].trim();
            }
            if (audioExt['date'] == null && tags['year'] != null) {
              audioExt['date'] = tags['year'].trim();
            }
          }

          additionalExt['audio'] = audioExt;

          final outFile = File(join(
            temporaryDirectory,
            '${Uuid().v4()}-thumbnail-extract.jpg',
          ));
          if (!outFile.existsSync()) {
            final extractThumbnailArgs = [
              '-i',
              file.path,
              '-map',
              '0:v',
              '-map',
              '-0:V',
              '-c',
              'copy',
              outFile.path,
            ];

            final res2 = await ffMpegProvider.runFFMpeg(extractThumbnailArgs);
          }

          if (outFile.existsSync()) {
            videoThumbnailFile = outFile;
            generateMetadata = true;
          }
        } catch (e, st) {
          error(e);
          verbose(st);
        }
      } else if (supportedVideoExtensionsForFFmpeg.contains(ext)) {
        // print('[MetadataExtractor/video] try ffprobe');
        try {
          final args = [
            '-v',
            'quiet',
            '-print_format',
            'json',
            '-show_format',
            '-select_streams',
            'v:0',
            '-show_entries',
            'stream=width,height',
            file.path,
          ];

          final res = await ffMpegProvider.runFFProbe(args);

          final data = json.decode(res.stdout);

          final streams = data['streams'];

          final format = data['format'];

          final videoExt = {
            'format_name': format['format_name'],
            'duration': double.tryParse(format['duration']),
            'bit_rate': int.tryParse(format['bit_rate']),
            'streams': streams,
          };

          if ((format['tags'] ?? {}).isNotEmpty) {
            for (final key in format['tags'].keys.toList()) {
              format['tags'][key.toLowerCase()] = format['tags'][key];
            }
            final includedTags = [
              'title',
              'artist',
              'album',
              'album_artist',
              'track',
              'date',
              'comment',
              'description',
              'show',
              'episode_id',
              'episode_sort',
              'season_number',
            ];
            for (final tag in includedTags) {
              if (format['tags'][tag] != null) {
                videoExt[tag] = format['tags'][tag];
              }
            }
          }

          additionalExt['video'] = videoExt;

          final subtitleRes = await ffMpegProvider.runFFProbe([
            '-v',
            'quiet',
            '-select_streams',
            's',
            '-show_entries',
            'stream=index:stream_tags=language',
            '-of',
            'csv=p=0',
            file.path,
          ]);

          //

          if (res.exitCode == 0) {
            final stdout = subtitleRes.stdout.trim();
            if (stdout.isNotEmpty) {
              final lines = stdout.split('\n');
              logger.info('found $lines subtitle tracks');

              final subtitles = [];
              for (final line in lines) {
                final parts = line.trim().split(',');
                final index = int.parse(parts[0]);
                final lang = parts.length < 2 ? 'eng' : parts[1];

                final subOutFile = File(join(
                  temporaryDirectory,
                  'subtitles',
                  '$lang-${Uuid().v4()}.vtt',
                ));

                logger.info(
                  'extracting $parts subtitle track to ${subOutFile.path}',
                );

                subOutFile.parent.createSync(recursive: true);

                try {
                  await ffMpegProvider.runFFMpeg([
                    '-i',
                    file.path,
                    '-map',
                    '0:$index',
                    subOutFile.path,
                  ]);
                } catch (_) {}

                /* print(res.exitCode);
                print(res.stdout); */
                if (subOutFile.existsSync()) {
                  final fileData = await storageService.uploadOneFile(
                    'vup.hns',
                    subOutFile,
                    returnFileData: true,
                  );

                  subtitles.add({
                    'lang': lang,
                    'index': index,
                    'format_name': 'vtt',
                    'file': fileData,
                  });
                }
              }
              if (subtitles.isNotEmpty) {
                additionalExt['video']['subtitles'] = subtitles;
              }
            } else {
              logger.info('found no subtitle tracks');
            }
          }

          final outFile = File(join(
            temporaryDirectory,
            '${Uuid().v4()}-thumbnail-extract.jpg',
          ));
          verbose('extracting thumbnail to ${outFile.path}');
          if (!outFile.existsSync()) {
            final extractThumbnailArgs = [
              '-i',
              file.path,
              '-map',
              '0:v',
              '-map',
              '-0:V',
              '-c',
              'copy',
              outFile.path,
            ];

            final res2 = await ffMpegProvider.runFFMpeg(extractThumbnailArgs);
          }

          if (outFile.existsSync()) {
            videoThumbnailFile = outFile;
            generateMetadata = true;
          } else {
            try {
              final extractThumbnailArgs = [
                '-ss',
                '00:03:00',
                '-i',
                file.path,
                '-vf',
                'thumbnail,scale=640:-1',
                '-frames:v',
                '1',
                outFile.path,
              ];

              await ffMpegProvider.runFFMpeg(extractThumbnailArgs);
            } catch (_) {}
            if (!outFile.existsSync()) {
              final extractThumbnailArgs = [
                '-i',
                file.path,
                '-vf',
                'thumbnail,scale=640:-1',
                '-frames:v',
                '1',
                outFile.path,
              ];

              await ffMpegProvider.runFFMpeg(extractThumbnailArgs);
            }
            if (outFile.existsSync()) {
              videoThumbnailFile = outFile;
              generateMetadata = true;
            }
          }
        } catch (e, st) {
          warning('video crash $e $st');
        }
      } else if (bookParsers.keys.contains(ext)) {
        var publicationExt = <String, dynamic>{};

        final parser = bookParsers[ext]!;
        try {
          final res = await parser.parse(file.path);

          final metadata = res!.publication.metadata;
          publicationExt = metadata.toJson();

          if (res.publication.coverLink != null) {
            final cover = res.publication.get(res.publication.coverLink!);
            final bytes = await cover.read();

            final outFile = File(join(
              temporaryDirectory,
              'thumbnails',
              '${Uuid().v4()}-thumbnail-extract.jpg',
            ));

            outFile.createSync(recursive: true);
            outFile.writeAsBytesSync(bytes.getOrThrow().buffer.asUint8List());
            print(outFile);
            if (outFile.existsSync()) {
              videoThumbnailFile = outFile;
              generateMetadata = true;
            }
          }

          customMimeType = res.container.rootFile.mimetype;
          print(customMimeType);

          if (res.container.rootFile.mimetype.startsWith('application/epub')) {
            final wordMatcher = RegExp(r'[^\s]+');
            int totalCount = 0;

            for (final chapter in res.publication.readingOrder) {
              final r = res.publication.get(chapter);
              final content = await r.readAsXml();

              totalCount += wordMatcher
                  .allMatches(content.success?.innerText ?? '')
                  .length;
            }
            publicationExt['wordCount'] = totalCount;
          } else if (res.container.rootFile.mimetype
              .startsWith('application/vnd.comicbook')) {
            publicationExt['pageCount'] = res.publication.readingOrder.length;
          }

          // publication

          print(metadata.toJson());
        } catch (e, st) {
          print(e);
          print(st);
        }

        if (publicationExt.isNotEmpty) {
          additionalExt['publication'] = publicationExt;
        }
        // print(res.publication.get(link));
      } else if (supported3DModelExtensions.contains(ext) &&
          (Platform.isLinux || Platform.isWindows)) {
        try {
          final temporaryScadFile = File(join(
            temporaryDirectory,
            'models',
            '${Uuid().v4()}-thumbnail-extract.scad',
          ));

          temporaryScadFile.createSync(recursive: true);
          temporaryScadFile.writeAsStringSync('import("${file.path}");');

          final outFile = File(join(
            temporaryDirectory,
            'thumbnails',
            '${Uuid().v4()}-thumbnail-extract.png',
          ));

          outFile.parent.createSync(recursive: true);
          final colorscheme = 'Tomorrow Night';
          final res = await Process.run('openscad', [
            '--colorscheme=$colorscheme',
            '--imgsize=384,384',
            '-o',
            outFile.path,
            temporaryScadFile.path,
          ]);

          if (outFile.existsSync()) {
            videoThumbnailFile = outFile;
            generateMetadata = true;
          }
        } catch (e, st) {
          warning(e);
          verbose(st);
        }
      } else if (Platform.isLinux && ext == '.pdf') {
        try {
          final outFile = File(join(
            temporaryDirectory,
            'thumbnails',
            '${Uuid().v4()}-thumbnail-extract.png',
          ));

          outFile.parent.createSync(recursive: true);

          final res = await Process.run('convert', [
            '-thumbnail',
            'x384',
            '-background',
            'white',
            '-alpha',
            'remove',
            file.path + '[0]',
            outFile.path,
          ]);

          if (outFile.existsSync()) {
            videoThumbnailFile = outFile;
            generateMetadata = true;
          }
        } catch (e, st) {
          warning(e);
          verbose(st);
        }
      } else if (Platform.isLinux && ext == '.svg') {
        try {
          final outFile = File(join(
            temporaryDirectory,
            'thumbnails',
            '${Uuid().v4()}-thumbnail-extract.png',
          ));

          outFile.parent.createSync(recursive: true);

          final res = await Process.run('inkscape', [
            '-h',
            '384',
            file.path,
            '-o',
            outFile.path,
          ]);

          if (outFile.existsSync()) {
            videoThumbnailFile = outFile;
            generateMetadata = true;
          }
        } catch (e, st) {
          warning(e);
          verbose(st);
        }
      }

      final fileData = await dac.uploadFileData(
        multihash,
        file.lengthSync(),
        customEncryptAndUploadFileFunction: () async {
          if (encrypted) {
            final encryptedCacheFile = File(join(
              temporaryDirectory,
              'encrypted_files',
              Uuid().v4(), /* fileMultiHash */
            ));
            try {
              final res = await encryptAndUploadFileInChunks(
                file,
                multihash,
                encryptedCacheFile,
                fileStateNotifier: fileStateNotifier,
                customRemote: getCustomRemoteForPath(path),
              );
              return res;
            } catch (e, st) {
              if (encryptedCacheFile.existsSync()) {
                await encryptedCacheFile.delete();
              }
              throw '$e: $st';
            }
          } else {
            // return await uploadPlaintextFileTODO(file, multihash);
          }
        },
        generateMetadata: generateMetadata,
        filename: file.path,
        additionalExt: additionalExt,
        hashes: [sha1Hash],
        generateMetadataWrapper: (
          extension,
          rootPathSeed,
        ) async {
          if (videoThumbnailFile != null) {
            // ! This is a media file
            return await compute(processImage, [
              additionalExt.isEmpty ? 'media' : additionalExt.keys.first,
              await videoThumbnailFile.readAsBytes(),
              rootPathSeed,
            ]);
          } else {
            // ! This is an image
            return await compute(processImage, [
              'image',
              await file.readAsBytes(),
              rootPathSeed,
            ]);
          }
        },
        metadataOnly: metadataOnly,
      );

      if (videoThumbnailFile != null) {
        if (videoThumbnailFile.existsSync()) {
          await videoThumbnailFile.delete();
        }
      }
      if (modified != null) {
        fileData.ts = modified;
      }
      if (returnFileData || metadataOnly) {
        return fileData;
      }
      if (create) {
        final res = await dac
            .createFile(
              path,
              name,
              fileData,
              customMimeType: customMimeType,
            )
            .timeout(const Duration(seconds: 60 * 5));
        if (!res.success) {
          throw res.error!;
        }
      } else {
        final res = await dac.updateFile(
          path,
          name,
          fileData,
        );
        if (!res.success) {
          throw res.error!;
        }
      }

      changeNotifier.removeUploadingFile(name);

      return fileData;
    } catch (e, st) {
      if (name != null) {
        changeNotifier.removeUploadingFile(name);
      }
      error(e);
      verbose(st);
      globalErrorsState.addError(e, name);
    }
  }

  bool isSyncTaskLocked(String syncKey) {
    if (!syncTasksLock.containsKey(syncKey)) {
      return false;
    }
    final dt = DateTime.fromMillisecondsSinceEpoch(syncTasksLock.get(syncKey)!);

    if (DateTime.now().difference(dt) > Duration(minutes: 1)) {
      return false;
    } else {
      return true;
    }
  }

  Future<FileData?> startFileUploadingTask(
    String path,
    File file, {
    bool create = true,
    int? modified,
    bool encrypted = true,
    Function? onUploadIdAvailable,
    bool returnFileData = false,
    bool metadataOnly = false,
  }) async {
    final changeNotifier = storageService.dac.getUploadingFilesChangeNotifier(
      storageService.dac.parsePath(path).toString(),
    );

    final uploadId = Uuid().v4();
    if (onUploadIdAvailable != null) {
      onUploadIdAvailable(uploadId);
    }
    final fileStateNotifier =
        storageService.dac.getFileStateChangeNotifier(uploadId);

    fileStateNotifier.updateFileState(
      FileState(
        type: FileStateType.uploading,
        progress: 0, // TODO Maybe use null instead
      ),
    );
    final now = DateTime.now().millisecondsSinceEpoch;

    changeNotifier.addUploadingFile(
      DirectoryFile(
        created: now,
        file: FileData(
          chunkSize: null,
          encryptionType: null,
          hash: uploadId,
          hashes: [],
          key: null,
          size: file.lengthSync(),
          ts: now,
          url: '',
        ),
        modified: now,
        name: basename(file.path),
        version: 0,
      ),
    );

    final customRemote = getCustomRemoteForPath(path);
    if (!uploadPools.containsKey(customRemote)) {
      uploadPools[customRemote] = Pool(customRemote == null ? 3 : 16);
    }
    final pool = uploadPools[customRemote]!;

    return await pool.withResource(
      () => uploadOneFile(
        path,
        file,
        fileStateNotifier: fileStateNotifier,
        create: create,
        modified: modified,
        encrypted: encrypted,
        // onHashAvailable: onHashAvailable,
        returnFileData: returnFileData,
        metadataOnly: metadataOnly,
      ),
    );
  }

  final _webDavClientCache = <String, webdav.Client>{};

  final uploadPools = <String?, Pool>{};

  Future<void> syncDirectory(
    Directory dir,
    String remotePath,
    SyncMode mode, {
    required String syncKey,
    bool overwrite = true,
    int level = 0,
  }) async {
    StreamSubscription? sub;
    // TODO ! SPLIT
    if (level == 0) {
      verbose('[sync] update lock');
      syncTasksLock.put(syncKey, DateTime.now().millisecondsSinceEpoch);
      sub = Stream.periodic(Duration(seconds: 30)).listen((event) {
        verbose('[sync] update lock');
        syncTasksLock.put(syncKey, DateTime.now().millisecondsSinceEpoch);
      });

      notificationProvider.show(
        1,
        'Started Sync',
        dir.path,
        // syncNotificationChannelSpecifics,
        payload: 'sync:$syncKey',
      );
    }

    // print('syncDirectory ${dir.path} ${remotePath} ${mode} ${overwrite}');

    dac.setFileState(
      remotePath,
      FileState(
        type: FileStateType.sync,
        progress: 0,
      ),
    );

    final futures = <Future>[];

    final index = (mode == SyncMode.sendOnly
            ? dac.getDirectoryIndexCached(remotePath)
            : null) ??
        await dac.getDirectoryIndex(remotePath);

    final syncedDirs = <String>[];
    final syncedFiles = <String>[];

    if (dir.existsSync()) {
      final list = await dir.listSync(followLinks: false);

      int i = 0;
      for (final entity in list) {
        dac.setFileState(
          remotePath,
          FileState(
            type: FileStateType.sync,
            progress: list.length == 0 ? 0 : i / list.length,
          ),
        );
        i++;
        if (entity is Directory) {
          /* if (entity.path.contains('ABC123')) {
            print('SKIPPING $entity');
            continue;
          }
          if (entity.statSync().modified.isBefore(DateTime(2022, 2, 10))) {
            print('SKIPPING $entity');
            continue;
          } */
          final dirName = basename(entity.path);
          if (mode != SyncMode.receiveOnly) {
            if (!index.directories.containsKey(dirName)) {
              await dac.createDirectory(remotePath, dirName);
            }
          }
          //final future =
          await syncDirectory(
            entity,
            '$remotePath/$dirName',
            mode,
            level: level + 1,
            overwrite: overwrite,
            syncKey: syncKey,
          );
          /* if (level != 0) {
            await future;
          } else {
            futures.add(future);
          } */
          syncedDirs.add(dirName);
        } else if (entity is File) {
          try {
            final filename = basename(entity.path);
            syncedFiles.add(filename);

            final existing = index.files[filename];

            if (existing == null) {
              if (mode != SyncMode.receiveOnly) {
                futures.add(storageService.startFileUploadingTask(
                  remotePath,
                  entity,
                  modified: (entity.lastModifiedSync()).millisecondsSinceEpoch,
                ));
              }
            } else {
              // ! server-side: existing
              // ! local: entity

              final remoteModified = existing.modified;

              final localModified =
                  entity.lastModifiedSync().millisecondsSinceEpoch;

              final check1 = (remoteModified / 1000).floor() !=
                  (localModified / 1000).floor();

              if (check1 || existing.file.size != entity.lengthSync()) {
                final multihash = await getMultiHashForFile(entity);

                if (multihash != existing.file.hash) {
                  // print('MODIFIED');
                  if (localModified > remoteModified) {
                    if (mode != SyncMode.receiveOnly) {
                      // print('UPLOAD');

                      futures.add(
                        storageService.startFileUploadingTask(
                          remotePath,
                          entity,
                          create: false,
                          modified: localModified,
                        ),
                      );
                    }
                  } else {
                    if (mode != SyncMode.sendOnly) {
                      // print('DOWNLOAD');
                      info('[sync] Downloading file ${existing.uri}');
                      futures.add(downloadPool.withResource(
                        () => storageService.downloadAndDecryptFile(
                          fileData: existing.file,
                          name: existing.name,
                          outFile: entity,
                          modified: existing.modified,
                        ),
                      ));
                    }
                  }
                } else {
                  // print('Unchanged (hash)');
                }
              } else {
                // print('Unchanged');
              }
            }
          } catch (e, st) {
            error('[sync] file ERROR: $e: $st');
          }
        }
      }
    }

    if (mode != SyncMode.sendOnly) {
      for (final d in index.directories.values) {
        if (!syncedDirs.contains(d.name)) {
          final subDir = Directory(join(dir.path, d.name));
          await subDir.create();
          await syncDirectory(
            subDir,
            '$remotePath/${d.name}',
            mode,
            level: level + 1,
            overwrite: overwrite,
            syncKey: syncKey,
          );
        }
      }
      for (final file in index.files.values) {
        if (!syncedFiles.contains(file.name)) {
          info('[sync] Downloading file ${file.uri}');
          futures.add(downloadPool.withResource(
            () => storageService.downloadAndDecryptFile(
              fileData: file.file,
              name: file.name,
              outFile: File(join(dir.path, file.name)),
              modified: file.modified,
            ),
          ));
        }
      }
    }

    // TODO Handle errors

    await Future.wait(futures);

    dac.setFileState(
      remotePath,
      FileState(
        type: FileStateType.idle,
        progress: null,
      ),
    );

    // TODO ! SPLIT
    if (level == 0) {
      sub?.cancel();

      syncTasksLock.delete(syncKey);
      syncTasksTimestamps.put(syncKey, DateTime.now().millisecondsSinceEpoch);
      notificationProvider.show(
        1,
        'Finished Sync',
        dir.path,
        // syncNotificationChannelSpecifics,
        payload: 'sync:$syncKey',
      );
    }
  }

  Future<void> setupSyncTasks() async {
    while (true) {
      for (final syncKey in syncTasks.keys) {
        final task = syncTasks.get(syncKey)!;
        if (task.interval == 0) continue;
        verbose('sync check ${task.interval}');
        final ts = DateTime.fromMillisecondsSinceEpoch(
            syncTasksTimestamps.get(syncKey) ?? 0);
        final now = DateTime.now();

        if (now.difference(ts) > Duration(seconds: task.interval)) {
          if (isSyncTaskLocked(syncKey)) continue;

          await storageService.syncDirectory(
            Directory(
              task.localPath!,
            ),
            task.remotePath,
            task.mode,
            syncKey: syncKey,
          );
        }
      }
      await Future.delayed(Duration(minutes: 1));
    }
  }

  Map<String, dynamic> watchers = {};

  // TODO Make watchers more efficient and only process the changes
  Future<void> setupWatchers() async {
    for (final syncKey in syncTasks.keys) {
      final task = syncTasks.get(syncKey)!;
      if (task.watch) {
        if (!watchers.containsKey(syncKey)) {
          info('[watcher] new');
          dynamic watcher = DirectoryWatcher(task.localPath!);
          watchers[syncKey] = watcher;
          watcher.events.listen((WatchEvent event) async {
            info('[watcher] event ${event.type} ${event.path}');
            if (isSyncTaskLocked(syncKey)) return;

            await storageService.syncDirectory(
              Directory(
                task.localPath!,
              ),
              task.remotePath,
              task.mode,
              syncKey: syncKey,
            );
          });
        }
      } else {
        if (watchers.containsKey(syncKey)) {
          info('[watcher] close');
          watchers[syncKey].close();
          watchers.remove(syncKey);
        }
      }
    }
  }

  Future<String> getMultiHashForFile(File file) async {
    if (Platform.isLinux) {
      final res = await Process.run('sha256sum', [file.path]);
      String hash = res.stdout.split(' ').first;
      if (hash.startsWith('\\')) {
        hash = hash.substring(1);
      }
      if (hash.length != 64) {
        throw 'Hash function failed';
      }
      return '1220$hash';
    }
    final hash = await compute(hashFileSha256, file);
    return '1220$hash';
  }

  Future<String> getSHA1HashForFile(File file) async {
    if (Platform.isLinux) {
      final res = await Process.run('sha1sum', [file.path]);
      String hash = res.stdout.split(' ').first;

      if (hash.startsWith('\\')) {
        hash = hash.substring(1);
      }

      if (hash.length != 40) {
        throw 'Hash function failed';
      }
      return '1114$hash';
    }
    final hash = await compute(hashFileSha1, file);
    return '1114$hash';
  }

  String getLocalFilePath(String hash, String name) {
    return join(
      dataDirectory,
      'local_files',
      hash,
      name,
    );
  }

  File? getLocalFile(DirectoryFile file) {
    if (!localFiles.containsKey(file.file.hash)) {
      return null;
    }
    final path = getLocalFilePath(file.file.hash, file.name);

    final f = File(path);
    if (f.existsSync()) {
      return f;
    } else {
      if (f.parent.existsSync()) {
        final List<File> list = f.parent
            .listSync()
            .where((element) => element is File)
            .toList()
            .cast<File>();

        if (list.length == 1) {
          if (list[0].lengthSync() == file.file.size) {
            info('renaming local file to ${f.path}');
            list[0].renameSync(f.path);

            return f;
          }
        }
      }

      return null;
    }
  }

  Future<String> downloadAndDecryptFile({
    required FileData fileData,
    required String name,
    File? outFile,
    int? modified,
    int? created,
  }) async {
    final decryptedFile = File(getLocalFilePath(fileData.hash, name));

    bool doDownload = false;

    if (localFiles.containsKey(fileData.hash)) {
      var exists = decryptedFile.existsSync();
      if (!exists) {
        doDownload = true;

        if (decryptedFile.parent.existsSync()) {
          final List<File> list = decryptedFile.parent
              .listSync()
              .where((element) => element is File)
              .toList()
              .cast<File>();

          if (list.length == 1) {
            if (list[0].lengthSync() == fileData.size) {
              info('renaming local file to ${decryptedFile.path}');
              list[0].renameSync(decryptedFile.path);
              doDownload = false;
              exists = true;
            }
          }
        }
      }

      // if(!doDownload && !exists){}

      if (!doDownload && exists) {
        if (decryptedFile.lengthSync() != fileData.size) {
          doDownload = true;
        }
      }
    } else {
      doDownload = true;
    }

    if (doDownload) {
      if (fileData.encryptionType == 'libsodium_secretbox') {
        final stream = await dac.downloadAndDecryptFileInChunks(fileData,
            downloadConfig: fileData.url.startsWith('remote-')
                ? (await generateDownloadConfig(fileData))
                : null);
        decryptedFile.createSync(recursive: true);
        final sink = decryptedFile.openWrite();
        await sink.addStream(stream.map((e) => e.toList()));

        await sink.flush();
        await sink.close();
      } else if (fileData.encryptionType == null) {
        decryptedFile.createSync(recursive: true);
        final dc = await generateDownloadConfig(fileData);

        await dioClient.download(
          dc.url,
          decryptedFile.path,
          onReceiveProgress: (count, total) {
            dac.setFileState(
              fileData.hash,
              FileState(
                type: FileStateType.downloading,
                progress: count / total,
              ),
            );
          },
          options: dio.Options(
            headers: dc.headers,
          ),
        );
        dac.setFileState(
          fileData.hash,
          FileState(
            type: FileStateType.idle,
            progress: null,
          ),
        );
      } else {
        final stream = await dac.downloadAndDecryptFile(fileData);
        decryptedFile.createSync(recursive: true);
        final sink = decryptedFile.openWrite();

        await sink.addStream(stream.map((e) => e.toList()));

        await sink.flush();
        await sink.close();
      }

      localFiles.put(fileData.hash, {
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
    }

    if (outFile == null) {
      return decryptedFile.path;
    }
    // TODO Maybe directly download+decrypt to outFile

    outFile.createSync(recursive: true);

    await decryptedFile.copy(outFile.path);

    try {
      outFile.setLastModifiedSync(
          DateTime.fromMillisecondsSinceEpoch(modified ?? 0));
    } catch (e, st) {
      warning('Could not set lastModified attribute.');
    }

    return '';
  }

  Future<EncryptAndUploadResponse> encryptAndUploadFileDeprecated(
    File file,
    String fileMultiHash,
  ) async {
    final fileStateNotifier = dac.getFileStateChangeNotifier(fileMultiHash);

    fileStateNotifier.updateFileState(FileState(
      type: FileStateType.encrypting,
      progress: 0,
    ));

    final outFile = File(join(
      temporaryDirectory,
      'encrypted_files',
      fileMultiHash,
    ));

    outFile.createSync(recursive: true);

    final totalSize = file.lengthSync();

    final secretKey = dac.sodium.crypto.secretStream.keygen();

    int internalSize = 0;
    int currentSize = 0;

    final sink = outFile.openWrite();

    final streamCtrl = StreamController<SecretStreamPlainMessage>();

    final List<int> data = [];

    file.openRead().listen((event) {
      data.addAll(event);

      internalSize += event.length;

      while (data.length >= (maxChunkSize)) {
        streamCtrl.add(
          SecretStreamPlainMessage(
            Uint8List.fromList(
              data.sublist(0, maxChunkSize),
            ),
          ),
        );
        data.removeRange(0, maxChunkSize);
      }
      if (internalSize == totalSize) {
        streamCtrl.add(SecretStreamPlainMessage(
          Uint8List.fromList(
            data,
          ),
          tag: SecretStreamMessageTag.finalPush,
        ));
        streamCtrl.close();
      }
    });
    final completer = Completer<bool>();

    final sub = dac.sodium.crypto.secretStream
        .pushEx(
      messageStream: streamCtrl.stream,
      key: secretKey,
    )
        .listen((event) {
      currentSize += event.message.length;
      fileStateNotifier.updateFileState(
        FileState(
          type: FileStateType.encrypting,
          progress: currentSize / totalSize,
        ),
      );
      sink.add(event.message);
      if (currentSize >= totalSize) {
        completer.complete(true);
      }
    });
    await completer.future;

    await sink.close();

    fileStateNotifier.updateFileState(
      FileState(
        type: FileStateType.encrypting,
        progress: 1,
      ),
    );

    fileStateNotifier.updateFileState(
      FileState(
        type: FileStateType.uploading,
        progress:
            0, // TODO Why is the upload speed slowed down when setting this to null?!?!?!?!
      ),
    );

    String? skylink;

    final TUS_CHUNK_SIZE = (1 << 22) * 10; // ~ 41 MB

    if (outFile.lengthSync() > TUS_CHUNK_SIZE) {
      // await Future.delayed(Duration(seconds: 10));
      skylink = await mySky.skynetClient.upload.uploadLargeFile(
        XFileDart(outFile.path),
        filename: 'encrypted-file.skyfs',
        fingerprint: Uuid().v4(),
        onProgress: (value) {
          // print('onProgress $value');
          fileStateNotifier.updateFileState(
            FileState(
              type: FileStateType.uploading,
              progress: value,
            ),
          );
        },
      );
    } else {
      skylink = await mySky.skynetClient.upload.uploadFileWithStream(
        SkyFile(
          content: Uint8List(0),
          filename: 'encrypted-file.skyfs',
          type: 'application/octet-stream',
        ),
        outFile.lengthSync(),
        outFile.openRead().map((event) => Uint8List.fromList(event)),
      );
    }

    await outFile.delete();

    if (skylink == null) {
      throw 'File Upload failed';
    }
    fileStateNotifier.updateFileState(
      FileState(
        type: FileStateType.idle,
        progress: null,
      ),
    );

    return EncryptAndUploadResponse(
      blobUrl: 'sia://$skylink',
      secretKey: secretKey.extractBytes(),
      encryptionType: 'AEAD_XCHACHA20_POLY1305',
      maxChunkSize: maxChunkSize,
      padding: 0,
    );
  }

  Future<EncryptAndUploadResponse> encryptAndUploadFileInChunks(
    File file,
    String fileMultiHash,
    File outFile, {
    FileStateNotifier? fileStateNotifier,
    required String? customRemote,
  }) async {
    int padding = 0;
    const maxChunkSize = 1 * 1000 * 1000; // 1 MiB

    fileStateNotifier ??= dac.getFileStateChangeNotifier(fileMultiHash);

    fileStateNotifier.updateFileState(FileState(
      type: FileStateType.encrypting,
      progress: 0,
    ));
/* 
    bool isCancelled = false;

    final _cancelSub = fileStateNotifier.onCancel.listen((_) {
      isCancelled = true;
    }); */

    outFile.createSync(recursive: true);

    final totalSize = file.lengthSync();

    final secretKey = dac.sodium.crypto.secretBox.keygen();

    int internalSize = 0;
    int currentSize = 0;

    final sink = outFile.openWrite();

    final streamCtrl = StreamController<PlaintextChunk>();

    final List<int> data = [];

    file.openRead().listen((event) {
      data.addAll(event);

      internalSize += event.length;

      while (data.length >= (maxChunkSize)) {
        streamCtrl.add(
          PlaintextChunk(
            Uint8List.fromList(
              data.sublist(0, maxChunkSize),
            ),
            false,
          ),
        );
        data.removeRange(0, maxChunkSize);
      }
      if (internalSize == totalSize) {
        streamCtrl.add(PlaintextChunk(
          Uint8List.fromList(
            data,
          ),
          true,
        ));
        streamCtrl.close();
      }
    });
    final completer = Completer<bool>();

    int i = 0;

    await for (var chunk in streamCtrl.stream) {
      final nonce = Uint8List.fromList(
        encodeEndian(i, dac.sodium.crypto.secretBox.nonceBytes,
            endianType: EndianType.littleEndian) as List<int>,
      );

      i++;

      if (chunk.isLast) {
        padding = padFileSize(totalSize) - totalSize;
        if ((padding + chunk.bytes.length) >= maxChunkSize) {
          padding = maxChunkSize - chunk.bytes.length;
        }

        // 5807 bytes

        verbose(
            'padding: ${filesize(padding)} | $padding | ${chunk.bytes.length} | ${totalSize}');

        final bytes = Uint8List.fromList(
          chunk.bytes +
              Uint8List(
                padding,
              ),
        );
        chunk = PlaintextChunk(bytes, true);
      }

      final res = dac.sodium.crypto.secretBox.easy(
        message: chunk.bytes,
        nonce: nonce,
        key: secretKey,
      );

      currentSize += chunk.bytes.length;
      fileStateNotifier.updateFileState(
        FileState(
          type: FileStateType.encrypting,
          progress: currentSize / totalSize,
        ),
      );
      sink.add(res);
      if (currentSize >= totalSize) {
        completer.complete(true);
      }
    }

    await completer.future;

    await sink.flush();
    await sink.close();

    fileStateNotifier.updateFileState(
      FileState(
        type: FileStateType.encrypting,
        progress: 1,
      ),
    );

    fileStateNotifier.updateFileState(
      FileState(
        type: FileStateType.uploading,
        progress:
            0, // TODO Why is the upload speed slowed down when setting this to null?!?!
      ),
    );

    String? blobUrl;

    final TUS_CHUNK_SIZE = (1 << 22) * 10; // ~ 41 MB

    if (customRemote != null) {
      final rem = dac.customRemotes[customRemote]!;
      final config = rem['config']! as Map;
      final type = rem['type']!;

      final fileId = base32.encode(dac.sodium.randombytes.buf(32)).replaceAll(
            '=',
            '',
          );

      if (type == 'webdav') {
        var path = '';

        for (int i = 0; i < 8; i += 2) {
          path += '/${fileId.substring(i, i + 2)}';
        }

        final filename = fileId.substring(8);

        if (!_webDavClientCache.containsKey(customRemote)) {
          _webDavClientCache[customRemote] = webdav.newClient(
            config['url'] as String,
            user: config['user'] as String,
            password: config['pass'] as String,
            debug: false,
          );
        }
        final client = _webDavClientCache[customRemote]!;

        final c = dio.CancelToken();
        await client.c.wdWriteWithStream(
          client,
          '/skyfs$path/$filename',
          outFile.openRead(),
          outFile.lengthSync(),
          onProgress: (c, t) {
            fileStateNotifier!.updateFileState(
              FileState(
                type: FileStateType.uploading,
                progress: c / t,
              ),
            );
          },
          cancelToken: c,
        );
        blobUrl = 'remote-$customRemote:/$path/$filename';
      } else if (type == 's3') {
        final client = dac.getS3Client(customRemote, config);

        final bucket = config['bucket'] as String;

        final totalBytes = outFile.lengthSync();

        final res = await client.putObject(
          bucket,
          'skyfs/$fileId',
          outFile.openRead().map((event) => Uint8List.fromList(event)),
          onProgress: (bytes) {
            fileStateNotifier!.updateFileState(
              FileState(
                type: FileStateType.uploading,
                progress: bytes / totalBytes,
              ),
            );
          },
        );
        if (res.isEmpty) {
          throw 'S3: Empty upload response';
        }
        blobUrl = 'remote-$customRemote://$fileId';
      } else {
        throw 'Remote type "$type" not supported';
      }
    } else {
      if (outFile.lengthSync() > TUS_CHUNK_SIZE) {
        blobUrl = await mySky.skynetClient.upload.uploadLargeFile(
          XFileDart(outFile.path),
          filename: 'encrypted-file.skyfs',
          fingerprint: Uuid().v4(),
          onProgress: (value) {
            fileStateNotifier!.updateFileState(
              FileState(
                type: FileStateType.uploading,
                progress: value,
              ),
            );
          },
        );
      } else {
        blobUrl = await mySky.skynetClient.upload.uploadFileWithStream(
          SkyFile(
            content: Uint8List(0),
            filename: 'encrypted-file.skyfs',
            type: 'application/octet-stream',
          ),
          outFile.lengthSync(),
          outFile.openRead().map((event) => Uint8List.fromList(event)),
          onProgress: (value) {
            fileStateNotifier!.updateFileState(
              FileState(
                type: FileStateType.uploading,
                progress: value,
              ),
            );
          },
        );
      }
      if (blobUrl != null) {
        blobUrl = 'sia://' + blobUrl;
      }
    }

    await outFile.delete();

    if (blobUrl == null) {
      throw 'File Upload failed';
    }
    fileStateNotifier.updateFileState(
      FileState(
        type: FileStateType.idle,
        progress: null,
      ),
    );

    return EncryptAndUploadResponse(
      blobUrl: blobUrl,
      secretKey: secretKey.extractBytes(),
      encryptionType: 'libsodium_secretbox',
      maxChunkSize: maxChunkSize,
      padding: padding,
    );
  }

  Future<EncryptAndUploadResponse> uploadPlaintextFileTODO(
    File outFile,
    String fileMultiHash,
  ) async {
    info('uploadPlaintextFile ${outFile.path}');

    final fileStateNotifier = dac.getFileStateChangeNotifier(fileMultiHash);

    fileStateNotifier.updateFileState(FileState(
      type: FileStateType.uploading,
      progress: 0,
    ));

    String? skylink;
    final TUS_CHUNK_SIZE = (1 << 22) * 10; // ~ 41 MB

    if (outFile.lengthSync() > TUS_CHUNK_SIZE) {
      skylink = await mySky.skynetClient.upload.uploadLargeFile(
        XFileDart(outFile.path),
        filename: basename(outFile.path),
        fingerprint: Uuid().v4(),
        onProgress: (value) {
          fileStateNotifier.updateFileState(
            FileState(
              type: FileStateType.uploading,
              progress: value,
            ),
          );
        },
      );
    } else {
      skylink = await mySky.skynetClient.upload.uploadFileWithStream(
        SkyFile(
          content: Uint8List(0),
          filename: basename(outFile.path),
          type: lookupMimeType(outFile.path),
        ),
        outFile.lengthSync(),
        outFile.openRead().map((event) => Uint8List.fromList(event)),
        onProgress: (value) {
          fileStateNotifier.updateFileState(
            FileState(
              type: FileStateType.uploading,
              progress: value,
            ),
          );
        },
      );
    }
    if (skylink == null) {
      throw 'File Upload failed';
    }

    fileStateNotifier.updateFileState(
      FileState(
        type: FileStateType.idle,
        progress: null,
      ),
    );
    return EncryptAndUploadResponse(
      blobUrl: 'sia://$skylink',
      secretKey: null,
      encryptionType: null,
      maxChunkSize: null,
      padding: null,
    );
  }

  String? getCustomRemoteForPath(String path) {
    final uri = dac.parsePath(path).toString();

    for (final remoteId in storageService.dac.customRemotes.keys) {
      final List usedForUris =
          storageService.dac.customRemotes[remoteId]!['used_for_uris'] ??
              const <String>[];

      for (final usedForUri in usedForUris) {
        if (usedForUri == uri || uri.startsWith(usedForUri)) {
          return remoteId;
        }
      }
    }

    return null;
  }
}

class PlaintextChunk {
  final Uint8List bytes;
  final bool isLast;
  PlaintextChunk(this.bytes, this.isLast);
}
