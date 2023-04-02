import 'dart:io';

import 'package:dart_chromecast/casting/cast.dart';
import 'package:dart_chromecast/utils/mdns_find_chromecast.dart'
    as find_chromecast;
import 'package:filesystem_dac/dac.dart';
import 'package:vup/app.dart';

import 'base.dart';

class StreamToCastDeviceVupAction extends VupFSAction {
  @override
  VupFSActionInstance? check(
      bool isFile,
      dynamic entity,
      PathNotifierState pathNotifier,
      BuildContext context,
      bool isDirectoryView,
      bool hasWriteAccess,
      FileState fileState,
      bool isSelected) {
    if (!devModeEnabled) return null;
    if (isDirectoryView) return null;
    if (!isFile) return null;
    if (entity == null) return null;

    return VupFSActionInstance(
      label: 'Stream to Cast device',
      icon: Icons.cast,
    );
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    if (Platform.isAndroid) {
      await requestAndroidBackgroundPermissions();
    }
    showLoadingDialog(
        context, 'Seaching for Cast devices in your local network...');
    final file = instance.entity as FileReference;

    final streamUrl =
        await temporaryStreamingServerService.makeFileAvailable(file);

    List<find_chromecast.CastDevice> devices =
        await find_chromecast.find_chromecasts();
    logger.verbose(devices);
    context.pop();
    if (devices.length == 0) {
      showInfoDialog(
        context,
        'No Cast devices found',
        'No devices with Cast support were found on your local network.',
      );
      return;
    }
    final find_chromecast.CastDevice? selectedDevice = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('Choose a Cast device'),
              content: SizedBox(
                height: dialogHeight,
                width: dialogWidth,
                child: ListView(
                  children: [
                    for (final d in devices)
                      ListTile(
                        title: Text('${d.ip}:${d.port}'),
                        subtitle: Text('${d.name}'),
                        onTap: () => context.pop(d),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => context.pop(),
                  child: Text(
                    'Cancel',
                  ),
                ),
              ],
            ));

    if (selectedDevice != null) {
      final CastSender castSender = CastSender(
        CastDevice(
          name: selectedDevice.name,
          host: selectedDevice.ip,
          port: selectedDevice.port,
          type: '_googlecast._tcp',
        ),
      );

      castSender.castSessionController.stream
          .listen((CastSession? castSession) async {
        if (castSession!.isConnected) {
          logger.verbose('cast state ${castSession.toMap()}');
        }
      });

      CastMediaStatus? prevMediaStatus;
      // Listen for media status updates, such as pausing, playing, seeking, playback etc.
      castSender.castMediaStatusController.stream
          .listen((CastMediaStatus? mediaStatus) {
        // show progress for example
        if (mediaStatus == null) {
          return;
        }
        if (null != prevMediaStatus &&
            mediaStatus.volume != prevMediaStatus!.volume) {
          logger.verbose('Volume just updated to ${mediaStatus.volume}');
        }
        if (null == prevMediaStatus ||
            mediaStatus.position != prevMediaStatus?.position) {
          logger.verbose('Media Position is ${mediaStatus.position}');
        }
        prevMediaStatus = mediaStatus;
      });

      bool connected = false;
      bool didReconnect = false;

      /*    if (null != savedState) {
                      connected = await castSender.reconnect(
                        sourceId: savedState['sourceId'],
                        destinationId: savedState['destinationId'],
                      );
                      if (connected) {
                        didReconnect = true;
                      }
                    } */
      if (!connected) {
        connected = await castSender.connect();
      }

      if (!connected) {
        logger.verbose('COULD NOT CONNECT!');
        return;
      }
      logger.verbose("Connected with device");

      if (!didReconnect) {
        castSender.launch();
      }

      castSender.loadPlaylist([
        CastMedia(
          contentId: streamUrl,
          contentType: file.mimeType ?? 'application/octet-stream',
          autoPlay: true,
          title: file.name,
        ),
      ], append: false);

      // Initiate key press handler
      // space = toggle pause
      // s = stop playing
      // left arrow = seek current playback - 10s
      // right arrow = seek current playback + 10s
      // up arrow = volume up 5%
      // down arrow = volume down 5%
      /* stdin.echoMode = false;
                    stdin.lineMode = false; */

      /* stdin.asBroadcastStream().listen((List<int> data) {
                      _handleUserInput(castSender, data);
                    }); */
    }

    /*   void _handleUserInput(CastSender castSender, List<int> data) {
                    if (data.length == 0) return;

                    int keyCode = data.last;

                    log.info("pressed key with key code: ${keyCode}");

                    if (32 == keyCode) {
                      // space = toggle pause
                      castSender.togglePause();
                    } else if (115 == keyCode) {
                      // s == stop
                      castSender.stop();
                    } else if (27 == keyCode) {
                      // escape = disconnect
                      castSender.disconnect();
                    } else if (65 == keyCode) {
                      // up
                      double? volume =
                          castSender.castSession?.castMediaStatus?.volume;
                      if (volume != null) {
                        castSender.setVolume(min(1, volume + 0.1));
                      }
                    } else if (66 == keyCode) {
                      // down
                      double? volume =
                          castSender.castSession?.castMediaStatus?.volume;
                      if (volume != null) {
                        castSender.setVolume(max(0, volume - 0.1));
                      }
                    } else if (67 == keyCode || 68 == keyCode) {
                      // left or right = seek 10s back or forth
                      double seekBy = 67 == keyCode ? 10.0 : -10.0;
                      if (null != castSender.castSession &&
                          null != castSender.castSession!.castMediaStatus) {
                        castSender.seek(
                          max(
                              0.0,
                              castSender
                                      .castSession!.castMediaStatus!.position! +
                                  seekBy),
                        );
                      }
                    } */

    /*    final results = await CastDiscoveryService().search();
                  logger.verbose('results $results');
                  
                  final session =
                      await CastSessionManager().startSession(results[0]);

                  session.stateStream.listen((state) {
                    logger.verbose('state $state');
                    if (state == CastSessionState.connected) {
                      session.sendMessage(CastSession.kNamespaceMedia, {
                        'type': 'LOAD',
                        'autoplay': true,
                        'currentTime': 0,
                        'media': {
                          "contentId": streamUrl,
                          // "streamType": 'BUFFERED',
                          "contentType": 'video/mp4',
                        }
                        // 'appId': 'YT', // set the appId of your app here
                      });
                    }
                  });

                  session.messageStream.listen((message) {
                    logger.verbose('receive message: $message');
                  });

                  session.sendMessage(CastSession.kNamespaceReceiver, {
                    'type': 'LAUNCH',
                    'appId': 'CC1AD845', // set the appId of your app here
                  }); */
  }
}
