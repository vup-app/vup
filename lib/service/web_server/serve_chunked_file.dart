import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:angel3_range_header/angel3_range_header.dart';
import 'package:alfred/alfred.dart';
import 'package:filesystem_dac/dac.dart';
import 'package:path/path.dart';
import 'package:s5_server/download/uri_provider.dart';
import 'package:vup/app.dart';
import 'package:vup/generic/state.dart';
import 'package:lib5/util.dart';

import 'package:http/http.dart' as http;
import 'package:vup/utils/download/generate_download_config.dart';

Future handleChunkedFile(
  HttpRequest req,
  HttpResponse res,
  FileReference df,
  int totalSize, {
  bool storeLocalFile = false,
}) async {
  final rangeHeader = req.headers.value('range');

  logger.verbose(
      'handleChunkedFile $rangeHeader storeLocalFile: $storeLocalFile');

  var ext = extension(df.name).isEmpty
      ? ''
      : extension(df.name).substring(1).toLowerCase();

  if (rangeHeader?.startsWith('bytes=') != true) {
    res.setContentTypeFromExtension(ext);
    await res.addStream(openRead(
      df,
      0,
      totalSize,
      storeLocalFile: storeLocalFile,
    ));
    return res.close();
  } else {
    var header = RangeHeader.parse(rangeHeader!);
    final items = RangeHeader.foldItems(header.items);
    var totalFileSize = totalSize;
    header = RangeHeader(items);

    for (var item in header.items) {
      var invalid = false;

      if (item.start != -1) {
        invalid = item.end != -1 && item.end < item.start;
      } else {
        invalid = item.end == -1;
      }

      if (invalid) {
        res.statusCode = 416;
        res.write('416 Semantically invalid, or unbounded range.');
        return res.close();
      }

      if (item.end >= totalFileSize) {
        res.setContentTypeFromExtension(ext);
        await res.addStream(openRead(
          df,
          0,
          totalSize,
          storeLocalFile: storeLocalFile,
        ));
        return res.close();
      }

      // Ensure it's within range.
      if (item.start >= totalFileSize || item.end >= totalFileSize) {
        res.statusCode = 416;
        res.write('416 Given range $item is out of bounds.');
        return res.close();
      }
    }

    if (header.items.isEmpty) {
      res.statusCode = 416;
      res.write('416 `Range` header may not be empty.');
      return res.close();
    } else if (header.items.length == 1) {
      var item = header.items[0];

      Stream<List<int>> stream;
      var len = 0;

      var total = totalFileSize;

      if (item.start == -1) {
        if (item.end == -1) {
          len = total;
          stream = openRead(
            df,
            0,
            totalSize,
            storeLocalFile: storeLocalFile,
          );
        } else {
          len = item.end + 1;
          stream = openRead(
            df,
            0,
            item.end + 1,
            storeLocalFile: storeLocalFile,
          );
        }
      } else {
        if (item.end == -1) {
          len = total - item.start;
          stream = openRead(
            df,
            item.start,
            totalSize,
            storeLocalFile: storeLocalFile,
          );
        } else {
          len = item.end - item.start + 1;
          stream = openRead(
            df,
            item.start,
            item.end + 1,
            storeLocalFile: storeLocalFile,
          );
        }
      }

      res.setContentTypeFromExtension(ext);

      res.statusCode = 206;
      res.headers.add('content-length', len.toString());
      res.headers.add(
        'content-range',
        'bytes ' + item.toContentRange(total),
      );
      await stream.cast<List<int>>().pipe(res);
      return res.close();
    } else {}
  }
}

Map<String, Completer> downloadingChunkLock = {};

Stream<List<int>> openRead(
    FileReference fileReference, int start, int totalSize,
    {required bool storeLocalFile}) async* {
  logger.verbose('using openRead $start < $totalSize');

  final fileVersion = fileReference.file;

  final encryptedCID = fileVersion.encryptedCID!;

  final chunkSize = encryptedCID.chunkSize;
  final padding = encryptedCID.padding;

  int chunk = (start / chunkSize).floor();

  int offset = start % chunkSize;

  final outDir = Directory(join(
    storageService.temporaryDirectory,
    'streamed_files',
    encryptedCID.encryptedBlobHash.toBase32(),
  ));

  outDir.createSync(recursive: true);

  Map<String, String>? customHeaders;

  final dlUriProvider =
      StorageLocationProvider(s5Node, encryptedCID.encryptedBlobHash);

  dlUriProvider.start();

  // TODO Make this more reliable, try multiple nodes
  final url = Uri.parse((await dlUriProvider.next()).location.bytesUrl);

  /*  if (df.file.url.startsWith('remote-')) {
    final dc = await generateDownloadConfig(df.file);

    url = Uri.parse(dc.url);
    customHeaders = dc.headers;
  } else {
    url = Uri.parse(
      storageService.mySky.skynetClient.resolveSkylink(
        df.file.url,
      )!,
    );
  } */

  final secretKey = encryptedCID.encryptionKey;

  StreamSubscription? sub;

  final totalEncSize =
      ((fileVersion.cid.size! / chunkSize).floor() * (chunkSize + 16)) +
          (fileVersion.cid.size! % chunkSize) +
          16 +
          padding;

  final downloadedEncData = <int>[];

  bool isDone = false;

  int servedBytes = start;

  while (start < totalSize) {
    final chunkCacheFile = File(join(outDir.path, chunk.toString()));

    if (!chunkCacheFile.existsSync()) {
      final chunkLockKey =
          encryptedCID.encryptedBlobHash.toBase32() + '-' + chunk.toString();
      if (downloadingChunkLock.containsKey(chunkLockKey)) {
        logger.verbose('[chunk] wait $chunk');
        sub?.cancel();
        while (!downloadingChunkLock[chunkLockKey]!.isCompleted) {
          await Future.delayed(Duration(milliseconds: 10));
        }
      } else {
        final completer = Completer();
        downloadingChunkLock[chunkLockKey] = completer;

        int retryCount = 0;

        while (true) {
          // TODO Check if retry makes sense with multi-chunk streaming
          try {
            logger.verbose('[chunk] dl $chunk');
            final encChunkSize = (chunkSize + 16);
            final encStartByte = chunk * encChunkSize;

            final end = min(encStartByte + encChunkSize - 1, totalEncSize - 1);

            bool hasDownloadError = false;

            if (downloadedEncData.isEmpty) {
              logger.info('[chunk] send http range request');
              final request = http.Request('GET', url);

              /* if (customHeaders != null) {
                request.headers.addAll(
                  customHeaders,
                );
              } else {
                request.headers.addAll(
                  storageService.mySky.skynetClient.headers ?? {},
                );
              } */
              request.headers['range'] =
                  'bytes=$encStartByte-${totalEncSize - 1}';

              final response = await mySky.httpClient.send(request);

              if (response.statusCode != 206) {
                throw 'HTTP ${response.statusCode}';
              }

              final maxMemorySize = (32 * (chunkSize + 16));
              // totalDownloadLength = response.contentLength!;
              sub = response.stream.listen(
                (value) {
                  // TODO Stop request when too fast
                  if (downloadedEncData.length > maxMemorySize) {
                    sub?.cancel();
                    downloadedEncData.removeRange(
                        maxMemorySize, downloadedEncData.length);
                    return;
                  }
                  downloadedEncData.addAll(value);
                },
                onDone: () {
                  isDone = true;
                },
                onError: (e, st) {
                  hasDownloadError = true;
                  logger.error('[chunk] $e $st');
                },
              );
            }
            bool isLastChunk = (end + 1) == totalEncSize;

            if (isLastChunk) {
              while (!isDone) {
                if (hasDownloadError) throw 'Download HTTP request failed';
                await Future.delayed(Duration(milliseconds: 10));
              }
            } else {
              while (downloadedEncData.length < (chunkSize + 16)) {
                if (hasDownloadError) throw 'Download HTTP request failed';
                await Future.delayed(Duration(milliseconds: 10));
              }
            }

            final bytes = Uint8List.fromList(
              isLastChunk
                  ? downloadedEncData
                  : downloadedEncData.sublist(0, (chunkSize + 16)),
            );
            if (isLastChunk) {
              downloadedEncData.clear();
            } else {
              downloadedEncData.removeRange(0, (chunkSize + 16));
            }

            final nonce = encodeEndian(
              chunk,
              encryptionAlgorithmXChaCha20Poly1305NonceSize,
            );

            logger.verbose('decryptXChaCha20Poly1305 ${bytes.length}');

            final r = await mySky.api.crypto.decryptXChaCha20Poly1305(
              key: secretKey,
              nonce: nonce,
              ciphertext: bytes,
            );

            if (isLastChunk) {
              await chunkCacheFile.writeAsBytes(
                r.sublist(
                  0,
                  r.length - padding,
                ),
              );
            } else {
              await chunkCacheFile.writeAsBytes(r);
            }
            completer.complete();
            break;
          } catch (e, st) {
            retryCount++;
            if (retryCount > 10) {
              completer.complete();
              downloadingChunkLock.remove(chunkLockKey);
              throw 'Too many retries. ($e $st)';
            }
            try {
              sub?.cancel();
            } catch (_) {}
            downloadedEncData.clear();

            logger.warning('[chunk] download error (try #$retryCount): $e $st');
            await Future.delayed(Duration(seconds: 1));
          }
        }
      }
    } else {
      sub?.cancel();
    }
    logger.verbose('[chunk] serve $chunk');

    start += chunkCacheFile.lengthSync() - offset;

    if (start > totalSize) {
      final end = chunkCacheFile.lengthSync() - (start - totalSize);
      logger.verbose('[chunk] LIMIT to $end');
      yield* chunkCacheFile.openRead(
        offset,
        end,
      );
    } else {
      yield* chunkCacheFile.openRead(
        offset,
      );
    }

    offset = 0;
    // servedBytes+=offset

    chunk++;

    // TODO Implement
/*     if (storeLocalFile) {
      if (!localFiles.containsKey(df.file.hash)) {
        final chunkFiles = outDir.listSync();
        final totalSize = chunkFiles.fold<int>(
          0,
          (previousValue, element) =>
              previousValue + (element as File).lengthSync(),
        );

        if (totalSize == df.file.size) {
          logger.verbose('[serve_chunked_file] storing file offline.');
          final decryptedFile = File(
            storageService.getLocalFilePath(
              df.file.hash,
              df.name,
            ),
          );

          decryptedFile.createSync(recursive: true);

          final sink = decryptedFile.openWrite();

          for (int i = 0; i < chunkFiles.length; i++) {
            await sink.addStream(File(join(outDir.path, '$i')).openRead());
          }

          await sink.flush();
          await sink.close();

          final hash = await storageService.getMultiHashForFile(decryptedFile);

          if (hash == df.file.hash) {
            localFiles.put(df.file.hash, {
              'ts': DateTime.now().millisecondsSinceEpoch,
            });
          } else {
            logger.error(
              '[serve_chunked_file] offline file hash check failed',
            );
          }
        }
      }
    } */
  }

  sub?.cancel();
}
