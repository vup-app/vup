import 'dart:convert';
import 'dart:io';

import 'package:vup/utils/ffmpeg/base.dart';

class IOFFmpegProvider extends FFmpegProvider {
  Future<FFResult> runFFProbe(List<String> args) async {
    final res = await Process.run(ffprobePath, args, stdoutEncoding: utf8);
    return FFResult(
      exitCode: res.exitCode,
      stdout: res.stdout,
    );
  }

  Future<FFResult> runFFMpeg(List<String> args) async {
    final res = await Process.run(ffmpegPath, args, stdoutEncoding: utf8);
    return FFResult(
      exitCode: res.exitCode,
      stdout: res.stdout,
    );
  }
}
