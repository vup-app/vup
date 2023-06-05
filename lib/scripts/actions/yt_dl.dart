import 'dart:convert';
import 'dart:io';

import 'package:pool/pool.dart';
import 'package:vup/scripts/actions/base.dart';
import 'package:vup/generic/state.dart';
import 'package:vup/utils/yt_dl.dart';

class YTDLAction extends VupAction {
  @override
  Future<void> run(Map<String, dynamic> config) async {
    final String url = config['url'];
    final String format = config['format'];
    final String targetURI = config['targetURI'];

    final dirIndex = storageService.dac.getDirectoryMetadataCached(
      targetURI,
    )!;
    final existingUrls = [];
    for (final file in dirIndex.files.values) {
      final fileUrl =
          file.ext?['audio']?['comment'] ?? file.ext?['video']?['comment'];
      if (fileUrl != null) {
        existingUrls.add(fileUrl);
      }
    }
    // info('existingUrls $existingUrls');
    final videos = [];

    final process = await Process.start(
      ytDlPath,
      [
        '--dump-json',
        '--flat-playlist',
        url,
      ],
    );

    process.stdout
        .transform(systemEncoding.decoder)
        .transform(const LineSplitter())
        .listen((event) {
      if (event.isNotEmpty) {
        final video = json.decode(event.toString());

        final url = video['webpage_url'] ?? video['original_url'];
        // info('got video $url');

        if (existingUrls.contains(url)) {
          // process.kill();
        } else {
          existingUrls.add(url);
          videos.add(video);
        }
      }
    });

    process.stderr
        .transform(systemEncoding.decoder)
        .transform(const LineSplitter())
        .listen((event) {
      if (event.isNotEmpty) {
        error('$event');
        // setState(() {});
      }
    });

    final exitCode = await process.exitCode;
    // if (exitCode != 0) throw 'yt-dlp exit code $exitCode';

    info('total videos ${videos.length}');

    final pool = Pool(8);

    final futures = <Future>[];

    for (final video in videos) {
      final url = video['webpage_url'] ?? video['original_url'];
      info('[process] ${url}');

      futures.add(
        pool.withResource(
          () => YTDLUtils.downloadAndUploadVideo(
            url,
            targetURI,
            format,
            videoResolution: '1080', // TODO Configurable
            /* onProgress: (progress) {
        setState(() {
          downloadProgress[url] = progress;
        });
      } */
          ),
        ),
      );
    }
    await Future.wait(futures);
  }
}
