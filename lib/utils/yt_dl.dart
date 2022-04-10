import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:vup/generic/state.dart';

class YTDLUtils {
  static final audioFormats = [
    'm4a',
    'mp3',
  ];

  static Future<void> downloadAndUploadVideo(
    String url,
    String path,
    String format, {
    Function? onProgress,
    Function? onUploadIdAvailable,
    Stream<Null>? cancelStream,
    List<String>? additionalArgs,
  }) async {
    final dlCount = 1;

    final outDirectory = Directory(join(
      storageService.temporaryDirectory,
      'yt_dl',
      Uuid().v4(),
    ));

    List<String> args;

    if (audioFormats.contains(format)) {
      args = [
        '--format-sort',
        'aext:$format',
        '--embed-metadata',
        '--embed-thumbnail',
        '--max-downloads',
        '$dlCount',
        '--match-filter',
        '!is_live & !live',
        '--extract-audio',
        '--audio-format',
        format,
        ...(additionalArgs ?? []),
        url,
      ];
    } else {
      args = [
        '--format-sort',
        'res:1080',
        '--embed-metadata',
        '--embed-thumbnail',
        '--embed-chapters',
        '--all-subs',
        '--embed-subs',
        '--max-downloads',
        '$dlCount',
        '--match-filter',
        '!is_live & !live',
        '--merge-output-format',
        format,
        ...(additionalArgs ?? []),
        url,
      ];
    }
    logger.verbose('yt-dlp args: $args');
/*     setState(() {
      _isDownloading = true;
    }); */

    void setDLState(double? progress) {
      if (onProgress != null) {
        onProgress(progress);
      }
    }

    setDLState(0);

    await outDirectory.create(recursive: true);

    final process = await Process.start(
      'yt-dlp',
      args,
      workingDirectory: outDirectory.path,
    );

    bool isCancelled = false;

    cancelStream?.listen((event) {
      isCancelled = true;
      process.kill();
    });

    final percentRegExp = RegExp(r'([0-9\.]+)% of ');
    process.stdout
        .transform(systemEncoding.decoder)
        .transform(const LineSplitter())
        .listen((event) {
      if (event.isNotEmpty) {
        // print('$event');
        // print(event.toString());
        // logOutput.add(event.toString());
        final match = percentRegExp.firstMatch(event.toString());
        if (match != null) {
          setDLState(double.parse(match.group(1)!) / 100);
        } else {
          logger.verbose('[yt-dlp] $event');
        }
        // setState(() {});
      }
    });

    process.stderr
        .transform(systemEncoding.decoder)
        .transform(const LineSplitter())
        .listen((event) {
      if (event.isNotEmpty) {
        // TODO Handle errors
        // throw event.toString();
      }
    });

    final exitCode = await process.exitCode;

    if (isCancelled) {
      throw 'cancel';
    }
    // if (exitCode != 0) throw 'yt-dlp exit code $exitCode';

    final files = <File>[];
    for (final file in outDirectory.listSync()) {
      if (file is File) {
        files.add(file);
      }
    }

    if (files.length > 1 &&
        (additionalArgs?.contains('--split-chapters') ?? false)) {
      files.removeLast();
    }

    /* uploadPool.withResource(
      () async { */
    final futures = <Future>[];
    if (!isCancelled) {
      for (final file in files) {
        futures.add(storageService.startFileUploadingTask(
          path,
          file,
          onUploadIdAvailable: onUploadIdAvailable,
        ));
      }
    }
    await Future.wait(futures);

    for (final file in files) {
      print('[yt-dlp] delete $file from cache');
      await file.delete();
    }

    if (isCancelled) {
      throw 'cancel';
    }

    /*   setState(() {
      _isDownloading = false;
    }); */
  }
}
