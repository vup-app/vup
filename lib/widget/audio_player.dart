/* import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';

import 'package:vup/app.dart';

class MediaPlayerWidget extends StatefulWidget {
  const MediaPlayerWidget({Key? key}) : super(key: key);

  @override
  _MediaPlayerWidgetState createState() => _MediaPlayerWidgetState();
}

// TODO Mobile layout (desktop first!)

class _MediaPlayerWidgetState extends State<MediaPlayerWidget> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<dynamic>(
      // TODO Click on this opens new page on mobile
      stream: audioPlayer.playerStateStream,
      builder: (context, snapshot) {
        if (audioPlayer.audioSource == null) return SizedBox();
        final controlWidgets = [
          Expanded(
            child: StreamBuilder<Duration>(
              stream: audioPlayer.positionStream,
              builder: (context, snapshot) => Padding(
                padding: const EdgeInsets.only(
                  right: 16.0,
                  left: 4.0,
                ),
                child: ProgressBar(
                  progress: snapshot.data ?? Duration.zero,
                  // buffered: Duration(milliseconds: 2000),
                  total: audioPlayer.duration ?? Duration.zero,
                  onSeek: (duration) {
                    audioPlayer.seek(duration);
                  },
                ),
              ),
            ),
          ),
          StreamBuilder<double>(
              stream: audioPlayer.speedStream,
              builder: (context, snapshot) {
                return DropdownButton<double>(
                  items: [
                    for (final speed in [
                      0.25,
                      0.5,
                      0.75,
                      1.0,
                      1.5,
                      2.0,
                      3.0,
                      4.0
                    ])
                      DropdownMenuItem(
                        child: Text(
                          '${speed}x',
                        ),
                        value: speed,
                      ),
                  ],
                  value: snapshot.data,
                  onChanged: (value) {
                    audioPlayer.setSpeed(value!);
                    // TODO audioPlayer.skipSilenceEnabled
                    // TODO Playlist and loop
                  },
                );
              }),
          SizedBox(
            width: 100, // TODO Better mobile slider
            child: StreamBuilder<double>(
              stream: audioPlayer.volumeStream,
              builder: (content, snapshot) => Slider(
                value: snapshot.data ?? 0,
                onChanged: (value) {
                  audioPlayer.setVolume(value);
                },
              ),
            ),
          )
        ];

        final playPauseWidget = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: IconButton(
            onPressed: () {
              /*  logger.verbose(audioPlayer.volume);
              logger.verbose(audioPlayer.speed); */
              if (audioPlayer.playing) {
                audioPlayer.pause();
              } else {
                audioPlayer.play();
              }
            },
            icon:
                // AnimatedIcon(icon: AnimatedIcons.play_pause, progress: Animation(0),),
                Icon(
              audioPlayer.playing ? UniconsLine.pause : UniconsLine.play,
            ),
          ),
        );
        return LayoutBuilder(builder: (context, cons) {
          final wrap = cons.maxWidth < 700;
          return Column(
            children: [
              Divider(
                height: 1,
                thickness: 1,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (wrap) playPauseWidget,
                  Padding(
                    padding: EdgeInsets.only(
                      left: wrap ? 0 : 16.0,
                    ),
                    child: SizedBox(
                      width: wrap ? (cons.maxWidth - 48) : 300,
                      child: Text(
                        Uri.decodeFull(
                          (audioPlayer.audioSource as ProgressiveAudioSource)
                              .uri
                              .pathSegments
                              .last,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        /* +
                              '\nmore text' */
                      ),
                    ),
                  ),
                  if (!wrap) playPauseWidget,
                  if (!wrap) ...controlWidgets,
                  /* Text(
                      (audioPlayer.audioSource as ProgressiveAudioSource)
                          .uri
                          .toString(),
                    ), */

                  /**/
                ],
              ),
              if (wrap)
                Row(
                  children: controlWidgets,
                )
            ],
          );
        });
      },
    );
  }
}
 */