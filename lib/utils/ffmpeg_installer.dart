import 'dart:convert';
import 'dart:io';

import 'package:archive2/archive_io.dart';
import 'package:path/path.dart';
import 'package:vup/app.dart';

Future<void> downloadAndInstallFFmpeg() async {
  final res = await mySky.httpClient.get(
    Uri.parse(
      'https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/latest',
    ),
  );
  /* final List releases = 
    releases
        .sort((a, b) => a['published_at'].compareTo(b['published_at']) as int); */

  final latest = json.decode(res.body);
  late Map dlAsset;
  for (final asset in latest['assets']) {
    final String name = asset['name'];
    if (!name.contains('master')) continue;
    if (name.contains('shared')) continue;
    if (name.contains('lgpl')) continue;
    if (Platform.isLinux) {
      if (name.contains('linux64')) {
        logger.verbose(name);
        dlAsset = asset;
        break;
      }
    }
    if (Platform.isWindows) {
      if (name.contains('win64')) {
        logger.verbose(name);
        dlAsset = asset;
        break;
      }
    }
  }
  final ffmpegDir = join(
    storageService.dataDirectory,
    'lib',
    'ffmpeg',
    dlAsset['id'].toString(),
  );
  Directory(ffmpegDir).createSync(recursive: true);

  logger.info('[ffmpeg installer] selected $dlAsset');

  if (Directory(ffmpegDir).listSync().isEmpty) {
    final dlRes = await mySky.httpClient.get(
      Uri.parse(
        dlAsset['browser_download_url'],
      ),
    );
    if (Platform.isLinux) {
      final tempArchiveFile = File(join(ffmpegDir, 'file.tar.xz'));
      tempArchiveFile.writeAsBytesSync(
        /* XZDecoder().decodeBytes( */ dlRes.bodyBytes /* ) */,
      );

      await Process.run(
        'tar',
        [
          '--xz',
          '-xvf',
          'file.tar.xz',
        ],
        workingDirectory: ffmpegDir,
      );
      await tempArchiveFile.delete();
    } else {
      extractArchiveToDisk(
        ZipDecoder().decodeBytes(dlRes.bodyBytes),
        ffmpegDir,
      );
    }
  }

  final binPath = join(Directory(ffmpegDir).listSync().first.path, 'bin');
  logger.verbose(binPath);

  if (Platform.isWindows) {
    dataBox.put('ffmpeg_path', join(binPath, 'ffmpeg.exe'));
    dataBox.put('ffprobe_path', join(binPath, 'ffprobe.exe'));
  } else {
    dataBox.put('ffmpeg_path', join(binPath, 'ffmpeg'));
    dataBox.put('ffprobe_path', join(binPath, 'ffprobe'));
  }
}
