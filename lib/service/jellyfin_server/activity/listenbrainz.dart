import 'dart:convert';

import 'package:vup/generic/state.dart';
import 'package:vup/service/base.dart';
import 'package:vup/service/jellyfin_server/id.dart';
import 'package:http/http.dart' as http;

const tickMultiplier = 1000 * 1000 * 10;

const fourMinutesInMilliseconds = 240000;

class ListenBrainzService extends VupService {
  JellyID? lastListenSubmit;
  JellyID? lastPlayingNowSubmit;
  DateTime nextPlayingNowSubmitTime = DateTime(2000);

  final httpClient = http.Client();

  bool get isEnabled => authToken != null;

  String? get authToken => dataBox.get('listenbrainz_auth_token');

  void onProgress({
    required JellyID itemId,
    required Map item,
    required int positionMillis,
    required bool isPaused,
  }) async {
    if ((authToken ?? '').trim().isEmpty) return;

    final headers = {
      'Authorization': 'Token $authToken',
      'Content-Type': 'application/json',
    };
    if (isPaused) return;
    // verbose('onProgress');
    final String trackName = item['Name'];
    final String artistName = item['Artist'] ?? item['Artists'][0];
    final String releaseName = item['Album'];

    final int duration =
        (item['RunTimeTicks']! / tickMultiplier * 1000).round();

    final additionalInfo = <String, dynamic>{};

    // TODO https://listenbrainz.readthedocs.io/en/latest/users/json.html#payload-json-details

    final _more_additional_info = {
      // TODO maybe "date": "2020-01-22",
      "media_player": "Jellyfin",
      "submission_client": "Vup",
      "media_player_version": "0.14.0",
      "submission_client_version": "0.14.0",
      // TODO This should be the original "url" source for downloads
      // TODO optional: cid
      // "origin_url": "https://s5.cx/S5HASH.m4a",
      // "spotify_id": "https://open.spotify.com/track/TRACK_ID",
      // TODO ProductionYear
    };

    if (item['ISRC'] != null) {
      additionalInfo['isrc'] = item['ISRC'];
    }
    if (item['IndexNumber'] != 1) {
      additionalInfo['tracknumber'] = item['IndexNumber'] as int;
    }

    if (item['Artists'].length > 1) {
      additionalInfo['artist_names'] = item['Artists'];
    }
    additionalInfo['duration_ms'] = duration;

    final trackMetadata = {
      "additional_info": additionalInfo,
      "artist_name": artistName,
      "track_name": trackName,
      "release_name": releaseName,
    };

    if (lastPlayingNowSubmit != itemId ||
        DateTime.now().isAfter(nextPlayingNowSubmitTime)) {
      lastPlayingNowSubmit = itemId;

      nextPlayingNowSubmitTime =
          DateTime.now().add(const Duration(seconds: 30));

      info('playing_now $itemId');
      final res = await httpClient.post(
        Uri.parse(
          'https://api.listenbrainz.org/1/submit-listens',
        ),
        headers: headers,
        body: json.encode(
          {
            "listen_type": "playing_now",
            "payload": [
              {
                "track_metadata": trackMetadata,
              }
            ]
          },
        ),
      );
      verbose(res.statusCode);
      verbose(res.body);
      nextPlayingNowSubmitTime = DateTime.now().add(
        const Duration(
          minutes: 4,
          seconds: 20,
        ),
      );
    }

    // ! isPaused,

    if (positionMillis > fourMinutesInMilliseconds ||
        (positionMillis > (duration / 2))) {
      if (lastListenSubmit == itemId) {
        return;
      }

      info('submit single $itemId');
      final res = await httpClient.post(
        Uri.parse(
          'https://api.listenbrainz.org/1/submit-listens',
        ),
        headers: headers,
        body: json.encode(
          {
            "listen_type": "single",
            "payload": [
              {
                "listened_at":
                    ((DateTime.now().millisecondsSinceEpoch - positionMillis) /
                            1000)
                        .round(),
                "track_metadata": trackMetadata,
              }
            ]
          },
        ),
      );
      verbose(res.statusCode);
      verbose(res.body);
      lastListenSubmit = itemId;
    }
  }
}
