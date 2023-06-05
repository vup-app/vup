import 'package:vup/generic/state.dart';
import 'package:vup/utils/yt_dl.dart';

import 'task.dart';

class MediaDownloadQueueTask extends QueueTask {
  @override
  final String id;
  @override
  final List<String> dependencies;
  @override
  final threadPool = 'mdl';

  @override
  double progress = 0;

  final String url;
  final String path;
  final String format;
  final String videoResolution;
/*   final Function? onProgress;
  final Function? onUploadIdAvailable; */
  final Stream<void>? cancelStream;
  final List<String>? additionalArgs;

  MediaDownloadQueueTask({
    required this.id,
    required this.dependencies,
    required this.url,
    required this.path,
    required this.format,
    required this.videoResolution,
/*     required this.onProgress,
    required this.onUploadIdAvailable, */
    required this.cancelStream,
    required this.additionalArgs,
  });

  @override
  Future<void> execute() async {
    logger.verbose('mdl "$id"');
    return YTDLUtils.downloadAndUploadVideo(
      url,
      path,
      format,
      videoResolution: videoResolution,
      onProgress: (value) {
        progress = value;
      },
      // onUploadIdAvailable: onUploadIdAvailable,
      cancelStream: cancelStream,
      additionalArgs: additionalArgs,
    );
  }
}
