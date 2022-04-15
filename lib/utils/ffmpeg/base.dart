import 'package:vup/generic/state.dart';

abstract class FFmpegProvider {
  Future<FFResult> runFFProbe(List<String> args);

  Future<FFResult> runFFMpeg(List<String> args);
}

String get ffmpegPath => dataBox.get('ffmpeg_path') ?? 'ffmpeg';
String get ffprobePath => dataBox.get('ffprobe_path') ?? 'ffprobe';

class FFResult {
  final int exitCode;
  final String stdout;

  FFResult({
    required this.exitCode,
    required this.stdout,
  });
  toString() => 'FFResult{$exitCode, $stdout}';
}
