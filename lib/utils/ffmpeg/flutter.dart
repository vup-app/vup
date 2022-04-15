import 'package:ffmpeg_kit_flutter_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_full/ffprobe_kit.dart';
import 'package:vup/utils/ffmpeg/base.dart';

class FlutterFFmpegProvider extends FFmpegProvider {
  Future<FFResult> runFFProbe(List<String> args) async {
    final session = await FFprobeKit.executeWithArgumentsAsync(args);

    int? exitCode;
    while (exitCode == null) {
      final returnCode = await session.getReturnCode();
      exitCode = returnCode?.getValue();
      await Future.delayed(Duration(milliseconds: 10));
    }

    final output = await session.getOutput();
    return FFResult(exitCode: exitCode, stdout: output!);
  }

  Future<FFResult> runFFMpeg(List<String> args) async {
    final session = await FFmpegKit.executeWithArgumentsAsync(args);

    int? exitCode;
    while (exitCode == null) {
      final returnCode = await session.getReturnCode();
      exitCode = returnCode?.getValue();
      await Future.delayed(Duration(milliseconds: 10));
    }

    final output = await session.getOutput();
    return FFResult(exitCode: exitCode, stdout: output!);
  }
}
