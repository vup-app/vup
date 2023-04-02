import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:lib5/src/upload/tus/client.dart';
import 'package:messagepack/messagepack.dart';
import 'package:pool/pool.dart';
import 'package:stash/stash_api.dart';
import 'package:vup/app.dart';
import 'package:vup/model/cancel_exception.dart';
import 'package:vup/queue/sync.dart';
import 'package:stash_hive/stash_hive.dart';
import 'package:filesystem_dac/dac.dart';
import 'package:path/path.dart';
import 'package:mno_streamer/parser.dart';
import 'package:uuid/uuid.dart';
import 'package:vup/model/sync_task.dart';
import 'package:vup/service/base.dart';
import 'package:vup/utils/process_image.dart';
import 'package:watcher/watcher.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:lib5/util.dart';

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

/* 
Future<String> hashFileSha256(File file) async {
  var output = new AccumulatorSink<Digest>();
  var input = sha256.startChunkedConversion(output);
  await file.openRead().forEach(input.add);
  input.close();
  final hash = output.events.single;
  return hash.toString();
}
 */
/* Future<String> hashFileSha1(File file) async {
  var output = new AccumulatorSink<Digest>();
  var input = sha1.startChunkedConversion(output);
  await file.openRead().forEach(input.add);
  input.close();
  final hash = output.events.single;
  return hash.toString();
} */

class StorageService extends VupService {
  final MySkyService mySky;
  late final FileSystemDAC dac;
  CryptoImplementation get crypto => mySky.crypto;
  final KeyValueDB localFiles;

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

  get trashPath => 'home/.trash';

  Future<void> init() async {}

  Future<void> onAuth() async {
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
      api: mySky.api,
      skapp: skappDomain,
      debugEnabled: true,
      onLog: (s) => logger.verbose(s),
      thumbnailCache: thumbnailCache,
      hiddenDB: mySky.identity.hiddenDB,
      fsRootKey: mySky.identity.fsRootKey,
    );
    await dac.init();
  }

  Future<FileVersion?> uploadOneFile(
    String path,
    File file, {
    bool create = true,
    int? modified,
    bool encrypted = true,
    // Function? onHashAvailable,
    bool returnFileData = false,
    bool metadataOnly = false,
    required FileStateNotifier fileStateNotifier,
  }) async {
    logger.verbose('upload-timestamp-1 ${DateTime.now()}');
    final changeNotifier = dac.getUploadingFilesChangeNotifier(
      dac.parsePath(path).toString(),
    );
    verbose('getUploadingFilesChangeNotifier $path');

    String? name;
    try {
      name = basename(file.path);

      logger.verbose('getMultiHashForFile');
      final multihash = await getMultiHashForFile(file);

      final currentDirState = dac.getDirectoryMetadataCached(path) ??
          await dac.getDirectoryMetadata(path);

      if (currentDirState.files.containsKey(name)) {
        final currentFileData = currentDirState.files[name]!;

        if (currentFileData.file.cid.hash == multihash) {
          throw 'Directory already contains this file (same hash)';
        } else {
          create = false;
        }
      }

      if (fileStateNotifier.isCanceled) {
        throw CancelException();
      }
      /*     if (onHashAvailable != null) {
        onHashAvailable(multihash);
      } */

      /* fileStateNotifier ??=
          storageService.dac.getFileStateChangeNotifier(multihash); */

      // final sha1Hash = await getSHA1HashForFile(file);

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
            '${Uuid().v4()}-thumbnail-extract.png',
          ));
          print('ffmpeg1 $outFile');
          if (!outFile.existsSync()) {
            final extractThumbnailArgs = [
              '-hide_banner',
              '-loglevel',
              'warning',
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
        // logger.verbose('[MetadataExtractor/video] try ffprobe');
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

                /* logger.verbose(res.exitCode);
                logger.verbose(res.stdout); */
                if (subOutFile.existsSync()) {
                  final fileData = await storageService.startFileUploadingTask(
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
            '${Uuid().v4()}-thumbnail-extract.png',
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
              '${Uuid().v4()}-thumbnail-extract.png',
            ));

            outFile.createSync(recursive: true);
            outFile.writeAsBytesSync(bytes.getOrThrow().buffer.asUint8List());
            logger.verbose(outFile);
            if (outFile.existsSync()) {
              videoThumbnailFile = outFile;
              generateMetadata = true;
            }
          }

          customMimeType = res.container.rootFile.mimetype;
          logger.verbose(customMimeType);

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

          logger.verbose(metadata.toJson());
        } catch (e, st) {
          logger.verbose(e);
          logger.verbose(st);
        }

        if (publicationExt.isNotEmpty) {
          additionalExt['publication'] = publicationExt;
        }
        // logger.verbose(res.publication.get(link));
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

      if (fileStateNotifier.isCanceled) {
        throw CancelException();
      }

      logger.verbose('upload-timestamp-3 ${DateTime.now()}');
      //generateMetadata = false;

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
            encryptedCacheFile.parent.createSync(recursive: true);

            try {
              final res = await encryptAndUploadFileInChunks(
                file,
                multihash,
                encryptedCacheFile,
                fileStateNotifier: fileStateNotifier,
                customRemote: getCustomRemoteForPath(path),
              );
              return res;
            } catch (e) {
              if (encryptedCacheFile.existsSync()) {
                await encryptedCacheFile.delete();
              }
              rethrow;
            }
          } else {
            // return await uploadPlaintextFileTODO(file, multihash);
          }
        },
        generateMetadata: generateMetadata,
        filename: file.path,
        additionalExt: additionalExt,
        // hashes: [sha1Hash],
        generateMetadataWrapper: (
          extension,
          rootThumbnailSeed,
        ) async {
          logger.verbose('upload-timestamp-process-image-0 ${DateTime.now()}');
          if (videoThumbnailFile != null) {
            // ! This is a media file
            return await /* compute( */ processImage2([
              additionalExt.isEmpty ? 'media' : additionalExt.keys.first,
              videoThumbnailFile.path,
              rootThumbnailSeed,
            ]);
          } else {
            // ! This is an image
            return await processImage2([
              'image',
              file.path,
              rootThumbnailSeed,
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
        await dac
            .createFile(
              path,
              name,
              fileData,
              customMimeType: customMimeType,
            )
            .timeout(const Duration(seconds: 60 * 5));
      } else {
        await dac.updateFile(
          path,
          name,
          fileData,
        );
      }

      changeNotifier.removeUploadingFile(name);

      return fileData;
    } catch (e, st) {
      if (name != null) {
        changeNotifier.removeUploadingFile(name);
      }
      if (e is CancelException || e is S5TusClientCancelException) {
        verbose('$e: $st');
      } else {
        error(e);
        verbose(st);
        globalErrorsState.addError(e, name);
      }
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

  Future<FileVersion?> startFileUploadingTask(
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

    final uploadId = Multihash(crypto.generateRandomBytes(32));
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
      FileReference(
        created: now,
        file: FileVersion(
          encryptedCID: EncryptedCID(
            encryptedBlobHash: uploadId,
            originalCID: CID(cidTypeRaw, uploadId, size: file.lengthSync()),
            encryptionKey: Uint8List(0),
            padding: 0,
            chunkSizeAsPowerOf2: 0,
            encryptionAlgorithm: 0,
          ),
          hashes: [],
          ts: now,
        ),
        modified: now,
        name: basename(file.path),
        version: -1,
      ),
    );

    final customRemote = getCustomRemoteForPath(path);
    if (!uploadPools.containsKey(customRemote)) {
      uploadPools[customRemote] = Pool(customRemote == null ? 8 : 16);
    }
    final pool = uploadPools[customRemote]!;

    final cancelSub = fileStateNotifier.onCancel.listen((event) {
      changeNotifier.removeUploadingFile(basename(file.path));
    });

    return await pool.withResource(
      () {
        cancelSub.cancel();
        if (fileStateNotifier.isCanceled) {
          throw CancelException();
        }
        return uploadOneFile(
          path,
          file,
          fileStateNotifier: fileStateNotifier,
          create: create,
          modified: modified,
          encrypted: encrypted,
          // onHashAvailable: onHashAvailable,
          returnFileData: returnFileData,
          metadataOnly: metadataOnly,
        );
      },
    );
  }

  final uploadPools = <String?, Pool>{};

  Future<void> startSyncTask(
    Directory dir,
    String remotePath,
    SyncMode mode, {
    required String syncKey,
    // bool overwrite = true,
  }) async {
    StreamSubscription? sub;

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

    final paths = <String>{};
    if (mode != SyncMode.receiveOnly) {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is Directory) {
          paths.add(
            entity.path.substring(dir.path.length + 1).replaceAll('\\', '/'),
          );
        }
      }
    }
    if (mode != SyncMode.sendOnly) {
      final startUri = dac.parsePath(remotePath).toString().length;
      final dm = await dac.getAllFiles(
        startDirectory: remotePath,
        includeDirectories: true,
        includeFiles: false,
      );
      for (final key in dm.directories.keys) {
        final path = Uri.decodeFull(key.substring(startUri + 1));
        paths.add(path);
      }
    }
    final pathList = paths.toList();
    pathList.sort();

    final remainingTaskIds = <String>{};

    for (final path in pathList) {
      final task = SyncQueueTask(
        id: '$remotePath/$path',
        remotePath: '$remotePath/$path',
        dir: Directory(join(dir.path, joinAll(path.split('/')))),
        mode: mode,
        dependencies: [],
      );
      if (path.contains('/')) {
        final pathParts = path.split('/');
        pathParts.removeLast();
        task.dependencies.add('$remotePath/${pathParts.join('/')}');
      } else {
        task.dependencies.add(remotePath);
      }
      remainingTaskIds.add(task.id);

      queue.add(task);
    }
    queue.add(SyncQueueTask(
      id: remotePath,
      remotePath: remotePath,
      dir: dir,
      mode: mode,
      dependencies: [],
    ));

    final notifier = dac.getDirectoryStateChangeNotifier(remotePath);

    int totalTaskCount = remainingTaskIds.length;

    while (true) {
      for (final id in remainingTaskIds.toList()) {
        if (!queue.tasks.containsKey(id) &&
            !queue.runningTasks.containsKey(id)) {
          remainingTaskIds.remove(id);
        }
      }

      if (remainingTaskIds.isEmpty) {
        break;
      }

      notifier.updateFileState(
        FileState(
          type: FileStateType.sync,
          progress: 1 - (remainingTaskIds.length / totalTaskCount),
        ),
      );
      await Future.delayed(Duration(milliseconds: 50));
    }

    sub.cancel();

    notifier.updateFileState(
      FileState(
        type: FileStateType.idle,
        progress: null,
      ),
    );

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

  Future<void> syncSingleDirectory(
    SyncQueueTask task, {
    bool overwrite = true,
  }) async {
    final dir = task.dir;
    final remotePath = task.remotePath;
    final mode = task.mode;

    // logger.verbose('syncDirectory ${dir.path} ${remotePath} ${mode} ${overwrite}');

    dac.setDirectoryState(
      remotePath,
      FileState(
        type: FileStateType.sync,
        progress: 0,
      ),
    );

    final futures = <Future>[];

    final index = (mode == SyncMode.sendOnly
            ? dac.getDirectoryMetadataCached(remotePath)
            : null) ??
        await dac.getDirectoryMetadata(remotePath);

    final syncedDirs = <String>[];
    final syncedFiles = <String>[];

    if (dir.existsSync()) {
      final list = dir.listSync(followLinks: false);

      int i = 0;
      for (final entity in list) {
        /* dac.setDirectoryState(
          remotePath,
          FileState(
            type: FileStateType.sync,
            progress: list.length == 0 ? 0 : i / list.length,
          ),
        ); */
        i++;
        if (entity is Directory) {
          /* if (entity.path.contains('ABC123')) {
            logger.verbose('SKIPPING $entity');
            continue;
          }
          if (entity.statSync().modified.isBefore(DateTime(2022, 2, 10))) {
            logger.verbose('SKIPPING $entity');
            continue;
          } */
          final dirName = basename(entity.path);
          if (mode != SyncMode.receiveOnly) {
            if (!index.directories.containsKey(dirName)) {
              futures.add(
                dac.createDirectory(remotePath, dirName),
              );
            }
          }
          //final future =
          /* TODO? await syncDirectory(
            entity,
            '$remotePath/$dirName',
            mode,
            level: level + 1,
            overwrite: overwrite,
            syncKey: syncKey,
          ); */
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

              if (check1 || existing.file.cid.size != entity.lengthSync()) {
                final multihash = await getMultiHashForFile(entity);

                if (multihash != existing.file.cid.hash) {
                  // logger.verbose('MODIFIED');
                  if (localModified > remoteModified) {
                    if (mode != SyncMode.receiveOnly) {
                      // logger.verbose('UPLOAD');

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
                      // logger.verbose('DOWNLOAD');
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
                  // logger.verbose('Unchanged (hash)');
                }
              } else {
                // logger.verbose('Unchanged');
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
          /* TODO? await syncDirectory(
            subDir,
            '$remotePath/${d.name}',
            mode,
            level: level + 1,
            overwrite: overwrite,
            syncKey: syncKey,
          ); */
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
    final completer = Completer();

    int remaining = 0;
    int total = futures.length;

    try {
      for (var future in futures) {
        future.then((_) {
          remaining--;

          task.progress = 1 - (remaining / total);

          if (remaining == 0) {
            return completer.complete();
          }
        }, onError: (e, st) {
          completer.completeError(e, st);
        });
        remaining++;
      }
      if (remaining == 0) {
        return completer.complete();
      }
    } catch (e, st) {
      completer.completeError(e, st);
    }
    await completer.future;

    dac.setDirectoryState(
      remotePath,
      FileState(
        type: FileStateType.idle,
        progress: null,
      ),
    );
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

          await storageService.startSyncTask(
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
        /* if (!watchers.containsKey(syncKey)) {
          info('[watcher] new');
          dynamic watcher = DirectoryWatcher(task.localPath!);
          watchers[syncKey] = watcher;
          watcher.events.listen((WatchEvent event) async {
            info('[watcher] event ${event.type} ${event.path}');
            if (isSyncTaskLocked(syncKey)) return;

            await storageService.startSyncTask(
              Directory(
                task.localPath!,
              ),
              task.remotePath,
              task.mode,
              syncKey: syncKey,
            );
          });
        } */
      } else {
        if (watchers.containsKey(syncKey)) {
          info('[watcher] close');
          watchers[syncKey].close();
          watchers.remove(syncKey);
        }
      }
    }
  }

  // TODO Check if this works for Jellyfin! (all implementations)
  Future<Multihash> getMultiHashForFile(File file) async {
    final hash = await s5Node.rust.hashBlake3File(path: file.path);

    final multihash = Multihash(
      Uint8List.fromList(
        [mhashBlake3Default] + hash,
      ),
    );
    return multihash;
  }

/*   Future<String> getSHA256HashForFile(File file) async {
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
  } */

/*   Future<String> getSHA1HashForFile(File file) async {
    final hash = await nativeRustApi.hashSha1File(path: file.path);
/*     if (Platform.isLinux) {
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
    final hash = await compute(hashFileSha1, file); */
    return '1114${hex.encode(hash).toLowerCase()}';
  } */

  String getLocalFilePath(Multihash hash, String name) {
    return join(
      dataDirectory,
      'local_files',
      hash.toBase32(),
      name,
    );
  }

  File? getLocalFile(FileReference file) {
    final fileVersion = file.file;
    if (!localFiles.contains(fileVersion.cid.hash.fullBytes)) {
      return null;
    }
    final path = getLocalFilePath(fileVersion.cid.hash, file.name);

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
          if (list[0].lengthSync() == fileVersion.cid.size) {
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
    required FileVersion fileData,
    required String name,
    bool isTemporary = true,
    File? outFile,
    int? modified,
    int? created,
  }) async {
    final decryptedFile = File(getLocalFilePath(fileData.cid.hash, name));

    logger.verbose('downloadAndDecryptFile ${decryptedFile}');

    bool doDownload = false;

    if (localFiles.contains(fileData.cid.hash.fullBytes)) {
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
            if (list[0].lengthSync() == fileData.cid.size) {
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
        // TODO verify integrity first
        if (decryptedFile.lengthSync() != fileData.cid.size) {
          doDownload = true;
        }
      }
    } else {
      doDownload = true;
    }

    if (doDownload) {
      /*   if (fileData.encryptedCID!.encryptionAlgorithm ==
          encryptionAlgorithmLibsodiumSecretbox) {
        throw 'Not supported';
        /* final stream = await dac.downloadAndDecryptFileInChunks(
          fileData,
          /*  downloadConfig: fileData.url.startsWith('remote-')
                ? (await generateDownloadConfig(fileData))
                : null */
        );
        decryptedFile.createSync(recursive: true);
        final sink = decryptedFile.openWrite();
        await sink.addStream(stream.map((e) => e.toList()));

        await sink.flush();
        await sink.close(); */
      } else */
      if (fileData.encryptedCID == null) {
        throw 'Not implemented';
        /*    decryptedFile.createSync(recursive: true);
        final dc = await generateDownloadConfig(fileData);

        await dioClient.download(
          dc.url,
          decryptedFile.path,
          onReceiveProgress: (count, total) {
            dac.setFileState(
              fileData.cid.hash,
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
          fileData.cid.hash,
          FileState(
            type: FileStateType.idle,
            progress: null,
          ),
        ); */
      } else {
        final encryptedCacheFile = File(join(
          temporaryDirectory,
          'encrypted_files_dl',
          Uuid().v4(),
        ));
        encryptedCacheFile.parent.createSync(recursive: true);

        logger.verbose('encryptedCacheFile $encryptedCacheFile');

        final fullChunkCount =
            (fileData.cid.size! / fileData.encryptedCID!.chunkSize).floor();

        final totalEncSize =
            fullChunkCount * (fileData.encryptedCID!.chunkSize + 16) +
                (fileData.cid.size! % fileData.encryptedCID!.chunkSize) +
                16 +
                fileData.encryptedCID!.padding;

        final fileStateNotifier =
            dac.getFileStateChangeNotifier(fileData.cid.hash);

        final cancelToken = CancellationToken();
        final cancelSub = fileStateNotifier.onCancel.listen((event) async {
          cancelToken.cancel();
        });

        try {
          await s5Node.downloadFileByHash(
            hash: fileData.encryptedCID!.encryptedBlobHash,
            size: totalEncSize,
            outputFile: encryptedCacheFile,
            onProgress: (progress) {
              dac.setFileState(
                fileData.cid.hash,
                FileState(
                  type: FileStateType.downloading,
                  progress: progress,
                ),
              );
            },
            cancelToken: cancelToken,
          );
          cancelSub.cancel();
        } catch (_) {
          fileStateNotifier.updateFileState(
            FileState(
              type: FileStateType.idle,
              progress: null,
            ),
          );
          cancelSub.cancel();
          rethrow;
        }

        logger.verbose('totalEncSize $totalEncSize');

        dac.setFileState(
          fileData.cid.hash,
          FileState(
            type: FileStateType.downloading,
            progress: null,
          ),
        );

        /*  await sink.addStream(openRead(
          dlUriProvider,
          hash: encryptedBlobHash,
          start: 0,
          totalSize: ,
          cachePath: s5Node.cachePath,
          logger: s5Node.logger,
          node: s5Node,
        ).map((event) {
         
          return event;
        })); */

        (outFile ?? decryptedFile).parent.createSync(recursive: true);

        logger.verbose('decrypting to ${(outFile ?? decryptedFile).path}');

        dac.setFileState(
          fileData.cid.hash,
          FileState(
            type: FileStateType.decrypting,
            progress: null,
          ),
        );

        await nativeRustApi.decryptFileXchacha20(
          inputFilePath: encryptedCacheFile.path,
          outputFilePath: (outFile ?? decryptedFile).path,
          key: fileData.encryptedCID!.encryptionKey,
          padding: fileData.encryptedCID!.padding,
          lastChunkIndex: fullChunkCount,
        );

        await encryptedCacheFile.delete();
        dac.setFileState(
          fileData.cid.hash,
          FileState(
            type: FileStateType.idle,
            progress: null,
          ),
        );
        /*  final stream = await dac.downloadAndDecryptFile(fileData);
        decryptedFile.createSync(recursive: true);
        final sink = decryptedFile.openWrite();

        await sink.addStream(stream.map((e) => e.toList()));

        await sink.flush();
        await sink.close(); */
      }

      if (outFile == null) {
        final p = Packer();
        p.packInt(1);
        p.packBool(isTemporary);
        p.packInt((DateTime.now().millisecondsSinceEpoch / 1000).round());

        localFiles.set(
          fileData.cid.hash.fullBytes,
          p.takeBytes(),
        );
      }
    }

    if (outFile == null) {
      return decryptedFile.path;
    }

    // outFile.parent.createSync(recursive: true);
    // await decryptedFile.copy(outFile.path);

    try {
      outFile.setLastModifiedSync(
          DateTime.fromMillisecondsSinceEpoch(modified ?? 0));
    } catch (e, st) {
      warning('Could not set lastModified attribute.');
    }

    return '';
  }
/* 
  Future<EncryptAndUploadResponse> encryptAndUploadFileDeprecated(
    File file,
    Multihash fileMultiHash,
  ) async {
    final fileStateNotifier = dac.getFileStateChangeNotifier(fileMultiHash);

    fileStateNotifier.updateFileState(FileState(
      type: FileStateType.encrypting,
      progress: 0,
    ));

    final outFile = File(join(
      temporaryDirectory,
      'encrypted_files',
      fileMultiHash.toBase32(),
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
          // logger.verbose('onProgress $value');
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
  } */

  Future<EncryptAndUploadResponse> encryptAndUploadFileInChunks(
    File file,
    Multihash fileMultiHash,
    File outFile, {
    required FileStateNotifier fileStateNotifier,
    required String? customRemote,
  }) async {
    logger.verbose('upload-timestamp-4 ${DateTime.now()}');
    int padding = 0;
    const maxChunkSizeAsPowerOf2 = 18;
    const maxChunkSize = 262144; // 256 KiB

    fileStateNotifier.updateFileState(FileState(
      type: FileStateType.encrypting,
      progress: 0,
    ));

/* 
    bool isCancelled = false;

    final _cancelSub = fileStateNotifier.onCancel.listen((_) {
      isCancelled = true;
    }); */

    // outFile.createSync(recursive: true);

    final totalSize = file.lengthSync();

    final chunkCount = (totalSize / maxChunkSize).ceil();

    final totalSizeWithPadding = totalSize + chunkCount * 16;

    padding = padFileSizeDefault(totalSizeWithPadding) - totalSizeWithPadding;

    final lastChunkSize = totalSize % maxChunkSize;

    if ((padding + lastChunkSize) >= maxChunkSize) {
      padding = maxChunkSize - lastChunkSize;
    }

    logger.verbose('encryptFileXchacha20 ${file.path} ${outFile.path}');

    final key = await nativeRustApi.encryptFileXchacha20(
      inputFilePath: file.path,
      outputFilePath: outFile.path,
      padding: padding,
    );

    if (fileStateNotifier.isCanceled) {
      await outFile.delete();
      throw CancelException();
    }

    /* verbose(
        'padding: ${filesize(padding)} | $padding | ${chunk.bytes.length} | ${totalSize}'); */

    // final secretKey = dac.sodium.crypto.secretBox.keygen().extractBytes();

    /* int internalSize = 0;
    int currentSize = 0; */

    // final sink = outFile.openWrite();

    // final streamCtrl = StreamController<PlaintextChunk>();

/*     final List<int> data = [];

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
        encodeEndian(
          i,
          12,
          endianType: EndianType.littleEndian,
        ) as List<int>,
      );

      i++;

      if (chunk.isLast) {

        final bytes = Uint8List.fromList(
          chunk.bytes +
              Uint8List(
                padding,
              ),
        );
        chunk = PlaintextChunk(bytes, true);
      }

      final res = await nativeRustApi.encryptChunk(
        key: secretKey,
        nonce: nonce,
        bytes: chunk.bytes,
      );

      /* final res = dac.sodium.crypto.secretBox.easy(
        message: chunk.bytes,
        nonce: nonce,
        key: secretKey,
      ); */

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
    } */

    /* await completer.future;

    await sink.flush();
    await sink.close(); */

/*     fileStateNotifier.updateFileState(
      FileState(
        type: FileStateType.encrypting,
        progress: 1,
      ),
    ); */

    fileStateNotifier.updateFileState(
      FileState(
        type: FileStateType.uploading,
        progress:
            0, // TODO Why is the upload speed slowed down when setting this to null?!?!
      ),
    );

    Multihash? encryptedBlobHash;

    logger.verbose('upload-timestamp-6 ${DateTime.now()}');

    // final TUS_CHUNK_SIZE = (1 << 22) * 10; // ~ 41 MB

    final SMALL_FILE_SIZE = 33554432; // 32 MiB

    if (customRemote != null) {
      /*    final rem = dac.customRemotes[customRemote]!;
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
      } */
      throw UnimplementedError();
    } else {
      if (outFile.lengthSync() > SMALL_FILE_SIZE) {
        logger.verbose('fileMultiHash $fileMultiHash');

        encryptedBlobHash = await getMultiHashForFile(outFile);

        for (final uc in mySky.api.storageServiceConfigs +
            mySky.api.storageServiceConfigs +
            mySky.api.storageServiceConfigs) {
          try {
            final tusClient = S5TusClient(
              url: uc.getAPIUrl('/s5/upload/tus'),
              fileLength: outFile.lengthSync(),
              headers: uc.headers,
              hash: encryptedBlobHash,
              httpClient: mySky.httpClient,
              onCancel: fileStateNotifier.onCancel,
              openRead: (start) {
                return outFile.openRead(start);
              },
            );
            await tusClient.upload(
              onProgress: (value) {
                fileStateNotifier.updateFileState(
                  FileState(
                    type: FileStateType.uploading,
                    progress: value,
                  ),
                );
              },
            );
            break;
          } catch (e, st) {
            logger.error(e);
            logger.verbose(st);
          }
        }
      } else {
        final ts = DateTime.now();

        encryptedBlobHash = await getMultiHashForFile(outFile);

        // final cid = await mySky.api.uploadRawFile(outFile.readAsBytesSync());
        await uploadFileWithStream(
          encryptedBlobHash,
          outFile.lengthSync(),
          outFile.openRead(),
          fileStateNotifier: fileStateNotifier,
          onProgress: (value) {
            fileStateNotifier.updateFileState(
              FileState(
                type: FileStateType.uploading,
                progress: value,
              ),
            );
          },
        ).timeout(const Duration(minutes: 5));

        /*       final cid = await mySky.skynetClient.upload.uploadFileWithStream(
          SkyFile(
            content: Uint8List(0),
            filename: 'encrypted-file.skyfs',
            type: 'application/octet-stream',
          ),
          outFile.lengthSync(),
          outFile.openRead(),
          onProgress: (value) {
            fileStateNotifier!.updateFileState(
              FileState(
                type: FileStateType.uploading,
                progress: value,
              ),
            );
          },
          raw: true,
        ); */
        logger
            .verbose('upload-timestamp-delay ${DateTime.now().difference(ts)}');
      }
    }

    await outFile.delete();

    /* if (encryptedBlobHash == null) {
      throw 'File Upload failed';
    } */
    fileStateNotifier.updateFileState(
      FileState(
        type: FileStateType.idle,
        progress: null,
      ),
    );

    logger.verbose('upload-timestamp-8 ${DateTime.now()}');

    return EncryptAndUploadResponse(
      encryptedBlobHash: encryptedBlobHash,
      secretKey: key,
      // encryptionType: 'ChaCha20-Poly1305',
      chunkSizeAsPowerOf2: maxChunkSizeAsPowerOf2,
      padding: padding,
    );
  }

// TODO Implement uploadPlaintextFile
/*   Future<EncryptAndUploadResponse> uploadPlaintextFileTODO(
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
  } */

  final ioHttpClient = HttpClient();

  Future<CID?> uploadFileWithStream(
    Multihash hash,
    int length,
    Stream<List<int>> readStream, {
    Function(double)? onProgress,
    int retryCount = 0,
    required FileStateNotifier fileStateNotifier,
  }) async {
    final errors = <String>[];
    for (final sc in mySky.api.storageServiceConfigs) {
      try {
        if (fileStateNotifier.isCanceled) {
          throw CancelException();
        }

        var uri = sc.getAPIUrl(
          '/s5/upload',
        );

        final headers = {
          'content-type': 'application/octet-stream',
        };

        headers.addAll(sc.headers);

        final req = await ioHttpClient.openUrl(
          'POST',
          uri,
        );
        for (final h in headers.entries) {
          req.headers.set(h.key, h.value);
        }

        var uploadedLength = 0;

        StreamSubscription? sub;

        if (onProgress != null) {
          sub = Stream.periodic(Duration(milliseconds: 100)).listen((event) {
            onProgress(uploadedLength / length);
          });
        }
        final cancelSub = fileStateNotifier.onCancel.listen((_) {
          req.abort();
        });

        logger.verbose('[upload] start');
        await req
            .addStream(readStream.transform(
              StreamTransformer.fromHandlers(
                handleData: (data, sink) {
                  uploadedLength += data.length;
                  sink.add(data);
                },
                handleError: (error, stack, sink) {},
                handleDone: (sink) {
                  sink.close();
                },
              ),
            ))
            .timeout(const Duration(minutes: 10));
        logger.verbose('[upload] end');
        final res = await req.close();

        sub?.cancel();

        cancelSub.cancel();

        if (res.statusCode != 200) {
          throw Exception('HTTP ${res.statusCode}');
        }

        final resBody = await utf8.decoder.bind(res).join();

        if (fileStateNotifier.isCanceled) {
          throw CancelException();
        }

        final cidStr = json.decode(resBody)['cid'];

        if (cidStr == null) throw Exception('Upload failed');

        // if (!skynetClient.trusted) {
        final cid = CID.decode(cidStr);

        if (cid.hash != hash) {
          throw 'Trustless raw upload failed';
        }
        return cid;
      } catch (e, st) {
        errors.add('${sc.authority}: $e: $st');
        logger.verbose(e);
        logger.verbose(st);
      }
    }

    if (fileStateNotifier.isCanceled) {
      throw CancelException();
    }

    logger.error(
      'Could not upload file: ${json.encode(errors)}, retryCount: $retryCount',
    );

    if (retryCount < 8) {
      await Future.delayed(Duration(seconds: pow(2, retryCount) as int));
      return uploadFileWithStream(
        hash,
        length,
        readStream,
        onProgress: onProgress,
        fileStateNotifier: fileStateNotifier,
        retryCount: retryCount + 1,
      );
    }

    throw 'Could not upload file: ${json.encode(errors)}';
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
