import 'package:dart_discord_rpc/dart_discord_rpc.dart';
import 'package:hive/hive.dart';
import 'package:vup/generic/state.dart';
import 'package:vup/service/base.dart';

class RichStatusService extends VupService {
  bool get isDiscordRPCEnabled =>
      dataBox.get('rich_status_service_discord_rpc_enabled') ?? false;

  bool get isDiscordThumbnailsEnabled =>
      dataBox.get('rich_status_service_discord_thumbnails_enabled') ?? false;

  DiscordRPC? rpc;

  late final Box<String> audioCovers;

  Future<void> init() async {
    audioCovers = await Hive.openBox('rich_status_service-audio_covers');
  }

  void stop() {
    if (rpc != null) {
      rpc!.clearPresence();
      rpc!.shutDown();
      rpc = null;
    }
  }

  void setStatus({
    required String title,
    List<String> artists = const [],
    String? album,
    String? date,
    required int duration,
    required int progress,
    required String? thumbnailKey,
    required RichStatusType type,
    int? indexNumber,
    String? seasonName,
    String? seriesName,
    required bool isPaused,
  }) async {
    if (!isDiscordRPCEnabled) {
      return;
    }
    if (rpc == null) {
      DiscordRPC.initialize();

      rpc = DiscordRPC(
        applicationId: '995006639734272130',
      );

      rpc!.start(autoRegister: true);
    }
    info('setStatus');

    late String line1;
    late String line2;

    if (type == RichStatusType.music) {
      if (album == null) {
        line1 = title;
        line2 = 'by ${artists.join(', ')}';
      } else {
        line1 = '$title by ${artists.join(', ')}';
        line2 = 'from $album';

        if (date != null) {
          line2 += ' ($date)';
        }
      }
    } else {
      if (seriesName == null || seasonName == null) {
        line1 = '$title';
        line2 = '';
      } else {
        line1 = '$seriesName • $seasonName';
        line2 = (indexNumber == null ? '' : '$indexNumber. ') + '$title';
      }
    }

    String? thumbnailSkylink;

    // TODO Fix this
    /* if (isDiscordThumbnailsEnabled) {
      if (thumbnailKey != null && !audioCovers.containsKey(thumbnailKey)) {
        try {
          info('uploading thumbnail...');
          final bytes = await storageService.dac.loadThumbnail(
            thumbnailKey,
          );
          final cid = await mySky.api.uploadRawFile(bytes!);

          audioCovers.put(thumbnailKey, cid.toBase64Url());
        } catch (e, st) {
          error('$e: $st');
        }
      }

      thumbnailSkylink = audioCovers.get(thumbnailKey ?? '');
      info('thumbnailSkylink $thumbnailSkylink');
    } */

    rpc!.updatePresence(
      DiscordPresence(
        details: line1,
        state: line2,
        endTimeStamp: isPaused
            ? null
            : DateTime.now()
                .add(Duration(
                  milliseconds: duration - progress,
                ))
                .millisecondsSinceEpoch,
        largeImageKey: thumbnailSkylink == null
            ? 'large-vup-logo-single'
            : 'https://s5.garden/s5/blob/$thumbnailSkylink',
        largeImageText: 'Using Vup Cloud Storage',
        smallImageText:
            type == RichStatusType.music ? 'Listening to music' : 'Watching',
        smallImageKey: type == RichStatusType.music ? 'music-circle' : 'eye',
      ),
    );
  }
}

enum RichStatusType {
  music,
  video,
  // read,
}
