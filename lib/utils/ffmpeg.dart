import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full/ffprobe_kit.dart';
import 'package:universal_platform/universal_platform.dart';
import 'package:vup/generic/state.dart';

class FFResult {
  final int exitCode;
  final String stdout;

  FFResult({
    required this.exitCode,
    required this.stdout,
  });
  toString() => 'FFResult{$exitCode, $stdout}';
}

String get ffmpegPath => dataBox.get('ffmpeg_path') ?? 'ffmpeg';
String get ffprobePath => dataBox.get('ffprobe_path') ?? 'ffprobe';

bool _useLibrary = !(UniversalPlatform.isLinux || UniversalPlatform.isWindows);

Future<FFResult> runFFProbe(List<String> args) async {
  if (_useLibrary) {
    final session = await FFprobeKit.executeWithArgumentsAsync(args);

    int? exitCode;
    while (exitCode == null) {
      final returnCode = await session.getReturnCode();
      exitCode = returnCode?.getValue();
      await Future.delayed(Duration(milliseconds: 10));
    }

    final output = await session.getOutput();
    return FFResult(exitCode: exitCode, stdout: output!);
  } else {
    final res = await Process.run(ffprobePath, args, stdoutEncoding: utf8);
    return FFResult(
      exitCode: res.exitCode,
      stdout: res.stdout,
    );
  }
}

Future<FFResult> runFFMpeg(List<String> args) async {
  if (_useLibrary) {
    final session = await FFmpegKit.executeWithArgumentsAsync(args);

    int? exitCode;
    while (exitCode == null) {
      final returnCode = await session.getReturnCode();
      exitCode = returnCode?.getValue();
      await Future.delayed(Duration(milliseconds: 10));
    }

    final output = await session.getOutput();
    return FFResult(exitCode: exitCode, stdout: output!);
  } else {
    final res = await Process.run(ffmpegPath, args, stdoutEncoding: utf8);
    return FFResult(
      exitCode: res.exitCode,
      stdout: res.stdout,
    );
  }
}
