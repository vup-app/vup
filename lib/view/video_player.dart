import 'package:vup/app.dart';

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class VideoPlayerView extends StatefulWidget {
  final FileReference video;
  const VideoPlayerView(this.video, {Key? key}) : super(key: key);

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  late final player =
      Player(configuration: PlayerConfiguration(title: widget.video.name));
  // Create a [VideoController] to handle video output from [Player].
  late final controller = VideoController(
    player,
    // configuration: VideoControllerConfiguration(),
  );

  @override
  void initState() {
    MediaKit.ensureInitialized();

    super.initState();

    player.open(Media(
      temporaryStreamingServerService.makeFileAvailableLocalhost(widget.video),
    ));
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Video(
            controller: controller,
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                },
                child: Material(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(4),
                  ),
                  color: Theme.of(context).primaryColor,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      UniconsLine.times,
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
