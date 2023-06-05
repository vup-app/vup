import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:alfred/alfred.dart';
import 'package:convert/convert.dart';
import 'package:lib5/util.dart';

import 'package:path/path.dart';
import 'package:tuple/tuple.dart';
import 'package:uuid/uuid.dart';
import 'package:vup/app.dart';
import 'package:vup/generic/state.dart';
import 'package:vup/service/base.dart';
import 'package:vup/service/jellyfin_server/metadata_cleanup.dart';
import 'package:vup/service/jellyfin_server/statistics.dart';
import 'package:vup/service/rich_status_service.dart';
import 'package:vup/service/web_server/serve_chunked_file.dart';
import 'package:alfred/src/type_handlers/websocket_type_handler.dart';
import 'package:vup/utils/temp_dir.dart';
import 'package:subtitle/subtitle.dart';

import 'package:archive/archive_io.dart';
import 'package:vup/service/web_server/serve_plaintext_file.dart';

import 'jellyfin_server/activity/listenbrainz.dart';
import 'jellyfin_server/id.dart';

const tickMultiplier = 1000 * 1000 * 10;
/* 
JellyID createIdHash(Uint8List bytes) {
  return hex.encode(mySky.crypto.hashBlake3Sync(bytes).sublist(0, 16));
} */

class JellyfinServerService extends VupService {
  bool isRunning = false;

  late Alfred app;
  // Alfred? vueWebApp;

  final folderCollectionIds = <JellyID>{};

  late JellyID serverId;

  void stop() {
    info('stopping server...');
    app.close(force: true);
    isRunning = false;
    // vueWebApp?.close(force: true);
    info('stopped server.');
  }

  final allItems = <JellyID, Map<String, dynamic>>{};

  // TODO Fix this
  final allCoverKeysMap = <JellyID, EncryptedCID?>{};

  final parentToChildMap = <JellyID, List<JellyID>>{};
  final recursiveParentToChildMap = <JellyID, List<JellyID>>{};

  //final latestCollectionItemIdsMap = <String, List<String>>{};

  final mediaFilesByHash = <JellyID, FileReference>{};

  final mediaStreamsByHash = <JellyID, Map<String, dynamic>>{};

  final collectionsMap = <JellyID, Map<String, dynamic>>{};

  List<JellyID> musicCollectionIds = [];

  final ignoreProgressEventsForIds = <JellyID>{};

  Future<void> processCollectionConfig(Map config) async {
    info('processCollectionConfig $config');
    final String name = config['name'] ?? '';
    final String type = config['type'] ?? '';
    String uri = config['uri'] ?? '';
    if (!uri.startsWith('skyfs://')) {
      final u = storageService.dac.parsePath(uri);

      uri = u.replace(queryParameters: {'recursive': 'true'}).toString();
    }
    verbose('uri $uri');

    final bool autoSeasonModeEnabled = false;

    final rootPath = Uri.parse(uri).pathSegments;

    final collectionId = JellyID.fromHex(config['id']);
    parentToChildMap[collectionId] = [];
    recursiveParentToChildMap[collectionId] = [];

    final latestKey = JellyID.hash('latest-$collectionId');

    parentToChildMap[latestKey] = [];

    void addLatestItem(JellyID id) {
      parentToChildMap[latestKey]!.add(id);
      // music: Albums
      // tvshows: Episodes
      // movies: Movie
      // books: Audio items
    }

    final minTicksForMusicProgressEvents = tickMultiplier * 900; // 15 minutes

    final index = await storageService.dac.getDirectoryMetadata(
      uri,
    );

    info('processCollectionConfig found ${index.files.length} files');

    final customMediaItems = <String, Map>{};
    for (final e in index.files.entries) {
      if (e.value.ext?.containsKey('media') ?? false) {
        final directoryPath = getDirectoryPath(rootPath, e.value.uri!);
        final Map media = e.value.ext!['media']!;

        customMediaItems[directoryPath.join('/')] = media;
      }
    }

    for (final file in index.files.values) {
      mediaFilesByHash[JellyID.file(file)] = file;
    }

    final coverImages = <String, String>{};
    final backdropImages = <String, String>{};
    final allImageFiles = <String, List<String>>{};

    for (final key in index.files.keys) {
      final video = index.files[key]!;

      if (video.file.thumbnail != null) {
        final directoryPath = getDirectoryPath(rootPath, video.uri!);

        final name = basenameWithoutExtension(video.name);

        if (['cover', 'folder', 'poster', 'default', 'show', 'movie']
            .contains(name)) {
          coverImages[directoryPath.join('/')] = key;
        } else if (['backdrop', 'fanart', 'background', 'art'].contains(name)) {
          backdropImages[directoryPath.join('/')] = key;
        }

        allImageFiles[key] = directoryPath;
      }
    }
    String? getThumbnailForPath(Map<String, String> images, String path) {
      if (images.containsKey(path)) {
        return images[path];
      }

      // final parts = path.split('/');
    }

    EncryptedCID? addThumbnail(
        {required Map<String, dynamic> map,
        required JellyID id,
        required String type,
        String? uri}) {
      if (uri == null) return null;
      final image = index.files[uri]!;

      if (image.file.thumbnail == null) {
        // TODO warn
        return null;
      }
      map['ImageTags'] ??= {};
      // map['ImageBlurHashes'] ??= {};

      final coverId = id.subhash(type);

      map['ImageTags']![type] = id;
      /* map['ImageBlurHashes']![type] = {
        id: image.ext?['thumbnail']['blurHash'],
      }; */

      allCoverKeysMap[coverId] = image.file.thumbnail!.cid;

      return image.file.thumbnail!.cid;
    }

    if (type == 'music') {
      musicCollectionIds.add(collectionId);
      final processedAlbumIds = <JellyID>{};
      final totalAlbumMusicLength = <JellyID, int>{};
      final totalArtistMusicLength = <JellyID, int>{};
      final albumGenres = <JellyID, Set<JellyID>>{};
      /*  for(final key in index.files.keys){
        logger.verbose('key $key');
      } */

      JellyID processArtist(String name) {
        final id = JellyID.hash('artist_$name');

        if (!recursiveParentToChildMap[collectionId]!.contains(id)) {
          recursiveParentToChildMap[collectionId]!.add(id);
        }
        if (!totalArtistMusicLength.containsKey(id)) {
          totalArtistMusicLength[id] = 0;
        }

        allItems[id] = {
          "Name": name,
          "ServerId": serverId,
          "Id": id,
          "ChannelId": null,
          "RunTimeTicks": 0,
          "Type": "MusicArtist",
          "ImageTags": {},
          "BackdropImageTags": [],
          "ImageBlurHashes": {},
          "LocationType": "Remote"
        };
        return id;
      }

      JellyID processGenre(String name) {
        final id = JellyID.hash('genre_' + name);

        if (!recursiveParentToChildMap[collectionId]!.contains(id)) {
          recursiveParentToChildMap[collectionId]!.add(id);
        }
        // parentToChildMap[collectionId]!.add(id);
        /*   if (!totalArtistMusicLength.containsKey(id)) {
          totalArtistMusicLength[id] = 0;
        } */

        allItems[id] = {
          "Name": name,
          "ServerId": serverId,
          "Id": id,
          "ChannelId": null,
          "Type": "MusicGenre",
          "PrimaryImageAspectRatio": 1,
          "ImageTags": {},
          "BackdropImageTags": [],
          "ImageBlurHashes": {},
          "LocationType": "Remote"
        };
        return id;
      }

      for (final song in index.files.values) {
        if (song.ext?['audio'] == null) continue;

        if (song.ext?['audio']?['duration'] is String) continue;

        final title = song.ext?['audio']?['title'] ?? song.name;

        final albumName = song.ext?['audio']['album'] ?? title;
        final artist = song.ext?['audio']['artist'] ?? 'Unknown';
        final albumArtist = song.ext?['audio']['album_artist'] ??
            song.ext?['audio']['artist'] ??
            'Unknown';

        final String? isrc = song.ext?['audio']['isrc'];

        final coverKey = song.file.thumbnail?.cid;

        final artists = MetadataCleanup.parseArtists(artist);
        final albumArtists = MetadataCleanup.parseArtists(albumArtist);

        final albumId = JellyID.hash('album_' +
            (song.ext?['audio']['album_artist'] ?? artists[0]) +
            '###' +
            albumName);

        final artistIds = artists.map<JellyID>(processArtist).toList();
        final albumArtistIds =
            albumArtists.map<JellyID>(processArtist).toList();

        if (!processedAlbumIds.contains(albumId)) {
          processedAlbumIds.add(albumId);

          recursiveParentToChildMap[collectionId]!.add(albumId);
          addLatestItem(albumId);

          if (coverKey != null) allCoverKeysMap[albumId] = coverKey;
          parentToChildMap[albumId] = [];

          totalAlbumMusicLength[albumId] = 0;

          allItems[albumId] = {
            "Name": albumName,
            "ServerId": serverId,
            "Id": albumId,
            "DateCreated": DateTime.fromMillisecondsSinceEpoch(song.created)
                .toIso8601String(),
            "ChannelId": null,
            "Genres": [],
            "RunTimeTicks": 0,
            "ProductionYear": song.ext?['audio']['date'] == null
                ? null
                : int.tryParse(song.ext?['audio']['date'].substring(0, 4)),
            "IsFolder": true,
            "Type": "MusicAlbum",
            "GenreItems": [],
            "UserData": {
              "PlaybackPositionTicks": 0,
              "PlayCount": 0, // TODO Aggregate from songs in album
              "IsFavorite": false,
              "Played": false,
              "Key": "a8b472e7763145e28526af47adac43f0"
            },
            "Artists": artists,
            "ArtistItems": [
              for (int i = 0; i < artists.length; i++)
                {
                  "Name": artists[i],
                  "Id": artistIds[i],
                }
            ],
            "AlbumArtist": albumArtists.first,
            "AlbumArtists": [
              for (int i = 0; i < albumArtists.length; i++)
                {
                  "Name": albumArtists[i],
                  "Id": albumArtistIds[i],
                }
            ],
            "ImageTags":
                allCoverKeysMap[albumId] == null ? {} : {"Primary": albumId},
            "BackdropImageTags": [],
            /* "ImageBlurHashes": allCoverKeysMap[albumId] == null
                ? {}
                : {
                    "Primary": {
                      albumId: song.ext?['thumbnail']?['blurHash'],
                    }
                  }, */
            "LocationType": "Remote"
          };
        }

        for (final artistId in artistIds) {
          parentToChildMap[artistId] ??= [];
          parentToChildMap[artistId]!.add(albumId);
        }

        final songId = JellyID.file(song);

        for (final artistId in artistIds) {
          parentToChildMap[artistId]!.add(songId);
        }

        final genre = song.ext?['audio']['genre'];
        JellyID? genreId;
        if (genre != null) {
          genreId = processGenre(genre);
          parentToChildMap[genreId] ??= [];
          parentToChildMap[genreId]!.add(songId);

          albumGenres[albumId] ??= <JellyID>{};
          albumGenres[albumId]!.add(genreId);
        }

        parentToChildMap[albumId]!.add(songId);
        recursiveParentToChildMap[collectionId]!.add(songId);

        if (coverKey != null) allCoverKeysMap[songId] = coverKey;

        final int ticks =
            ((song.ext?['audio']['duration'] ?? 1) * tickMultiplier).round();

        totalAlbumMusicLength[albumId] =
            (totalAlbumMusicLength[albumId]! + ticks).round();

        for (final artistId in artistIds) {
          totalArtistMusicLength[artistId] =
              (totalArtistMusicLength[artistId]! + ticks).round();
        }

        final songItem = _buildAudioItemForFile(
          song,
          isAudiobook: false,
          genreId: genreId,
          rootPath: rootPath,
          collectionId: collectionId,
        );
        if (ticks < minTicksForMusicProgressEvents) {
          ignoreProgressEventsForIds.add(songId);
        }

        songItem.addAll(<String, dynamic>{
          "Artists": artists,
          "ArtistItems": [
            for (int i = 0; i < artists.length; i++)
              {
                "Name": artists[i],
                "Id": artistIds[i],
              }
          ],
          "Artist": artist,
          "Album": albumName,
          "AlbumId": albumId,
          "AlbumPrimaryImageTag": albumId,
          "AlbumArtist": albumArtists.first,
          "AlbumArtists": [
            for (int i = 0; i < albumArtists.length; i++)
              {
                "Name": albumArtists[i],
                "Id": albumArtistIds[i],
              }
          ],
        });

        if (isrc != null) {
          songItem['ISRC'] = isrc;
        }

        allItems[songId] = songItem;
/* 
             for (final song in musicIndex.files.values)
            {
              "id": song.file.hash,
              "album_id": /* song.ext?['audio']['album'] == null
                  ? null
                  : */
                  albumMap[song.ext?['audio']['album']],
              "artist_id": song.ext?['audio']['artist'] == null
                  ? 0
                  : artistMap[song.ext?['audio']['artist']],
              "title": (song.ext?['audio']['title'] ?? song.name),
              "length": song.ext?['audio']['duration'] ?? 1,
              "track": song.ext?['audio']['track'] == null
                  ? null
                  : int.tryParse(song.ext?['audio']['track']),
              "disc": 1,
              "created_at": DateTime.fromMillisecondsSinceEpoch(song.created)
                  .toIso8601String(),
            },
        ], */
      }

      for (final albumId in totalAlbumMusicLength.keys) {
        allItems[albumId]!['RunTimeTicks'] = totalAlbumMusicLength[albumId];
        allItems[albumId]!['ChildCount'] = parentToChildMap[albumId]!.length;
      }

      for (final albumId in albumGenres.keys) {
        allItems[albumId]!['Genres'] = [
          for (final genreId in albumGenres[albumId]!)
            allItems[genreId]!['Name'],
        ];

        allItems[albumId]!["GenreItems"] = [
          for (final genreId in albumGenres[albumId]!)
            {
              'Name': allItems[genreId]!['Name'],
              'Id': genreId,
            }
        ];
      }

      for (final artistId in totalArtistMusicLength.keys) {
        allItems[artistId]!['RunTimeTicks'] = totalArtistMusicLength[artistId];
      }
    } else if (type == 'tvshows') {
      /*    String processSeries(String name) {
        final id = sha1.convert(utf8.encode('artist_' + name)).toString();

        if (!recursiveParentToChildMap[collectionId]!.contains(id)) {
          recursiveParentToChildMap[collectionId]!.add(id);
        }
        if (!totalArtistMusicLength.containsKey(id)) {
          totalArtistMusicLength[id] = 0;
        }

        allItems[id] = {
          "Name": name,
          "ServerId": serverId,
          "Id": id,
          "ChannelId": null,
          "RunTimeTicks": 0,
          "Type": "MusicArtist",
          "ImageTags": {},
          "BackdropImageTags": [],
          "ImageBlurHashes": {},
          "LocationType": "Remote"
        };
        return id;
      } */
      final endDates = <JellyID, DateTime>{};
      final premiereDates = <JellyID, DateTime>{};

      JellyID processSeries(
        String name, {
        required String path,
        String? displayName,
      }) {
        // logger.verbose('media path $path');
        final media = customMediaItems[path];

        final JellyID id =
            media != null ? media['item']['Id'] : JellyID.hash('series_$name');

        if (!recursiveParentToChildMap[collectionId]!.contains(id)) {
          recursiveParentToChildMap[collectionId]!.add(id);
        }
        if (allItems.containsKey(id)) {
          return id;
        }

        addLatestItem(id);
        /* if (!totalArtistMusicLength.containsKey(id)) {
          totalArtistMusicLength[id] = 0;
        } */

        final item = {
          "Name": displayName ?? name,
          "ServerId": serverId,
          "Id": id,
          "Etag": DateTime.now().toIso8601String(),
          "DateCreated": "2022-02-07T17:15:59.937Z",
          "DateLastMediaAdded": "2022-02-07T17:15:59.937Z",
          "CanDelete": true,
          "CanDownload": false,
          "PreferredMetadataLanguage": "",
          "PreferredMetadataCountryCode": "",
          "SortName": convertToSortName(displayName ?? name),
          "ForcedSortName": "",
          // "PremiereDate": "2000-01-01T00:00:00.0000000Z",
          "ExternalUrls": [
            /* {"Name": "IMDb", "Url": "https://www.imdb.com/title/"},
            {"Name": "Trakt", "Url": "https://trakt.tv/shows/"} */
            {
              "Name": "Watch on YouTube",
              "Url": "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
            }
          ],
          "Path": path,
          "EnableMediaSourceDisplay": true,
          "CustomRating": "",
          "ChannelId": null,
          "Overview":
              "This is a very interesting overview of the series. Lorem ipsum dolor sit amet consectur.",
          "Taglines": [],
          "Genres": [/* "Horror" */],
          "CommunityRating": 6.9,
          "CumulativeRunTimeTicks": 70333195900,
          "RunTimeTicks": 70333195900,
          "PlayAccess": "Full",
          // "ProductionYear": 2020,
          "RemoteTrailers": [],
          // "ProviderIds": {"Tvdb": "", "Imdb": ""},
          "IsFolder": true,
          "ParentId": collectionId,
          "Type": "Series",
          "People": [
            {
              "Name": "Random Actor",
              "Id": "a8b472e7763145e28526af47adac43f1",
              "Role": "Moderator",
              "Type": "Actor",
            },
          ],
          "Studios": [
            // {"Name": "Vup TV Studio", "Id": ""}
          ],
          "GenreItems": [],
          "LocalTrailerCount": 0,
          "UserData": {
            "PlayedPercentage": 0,
            "UnplayedItemCount": 3,
            "PlaybackPositionTicks": 0,
            "PlayCount": 0,
            "IsFavorite": false,
            "Played": false,
            "Key": "a8b472e7763145e28526af47adac43f0"
          },
          "RecursiveItemCount": 3,
          "ChildCount": 1,
          "SpecialFeatureCount": 0,
          "DisplayPreferencesId": "f63033ff6886ecc7083a696cbeced1b0",
          // "Status": "Continuing",
          /* "AirTime": "8:15 PM",
          "AirDays": ["Thursday"], */
          "Tags": [],
          "PrimaryImageAspectRatio": 0.6666666666666666,
          "DisplayOrder": "",

          "LocationType": "Remote",
          "LockedFields": [],
          "LockData": false
        };
        if (media != null) {
          item.addAll(media['item'].cast<String, dynamic>());
          for (final item in (media['items'] ?? [])) {
            allItems[item['Id']] = item;
          }
        }
        allItems[id] = item;

        return id;
      }

      Tuple2<JellyID, int> processSeason(
        JellyID seriesId,
        String name, {
        required String path,
      }) {
        // final indexNumber = int.parse(numberMatcher.stringMatch(name) ?? '1');
        int? indexNumber;
        if (indexNumber == null) {
          final matches = numberMatcher.allMatches(name);

          for (final m in matches) {
            /*   if (m.group(1) == 'S') {
              continue;
            } */
            indexNumber = int.parse(m.group(2)!);
            break;
          }
        }
        indexNumber ??= 1;

        final id = JellyID.hash('${seriesId}_season_' + name);

        if (!recursiveParentToChildMap[collectionId]!.contains(id)) {
          recursiveParentToChildMap[collectionId]!.add(id);
        }

        allItems[id] = {
          "Name": name,
          "ServerId": serverId,
          "Id": id,
          "Etag": DateTime.now().toIso8601String(),
          "DateCreated": "2022-02-07T17:15:59.937Z",
          "CanDelete": false,
          "CanDownload": false,
          "Path": path,
          "PreferredMetadataLanguage": "",
          "PreferredMetadataCountryCode": "",
          "SortName": indexNumber.toString().padLeft(6, '0'),
          "ForcedSortName": "",
          "PremiereDate": "2022-02-07T17:15:59.937Z",
          "ExternalUrls": [],
          "EnableMediaSourceDisplay": true,
          "CustomRating": "",
          "ChannelId": null,
          "Overview": "",
          "Taglines": [],
          "Genres": [],
          "PlayAccess": "Full",
          "ProductionYear": 2021,
          "IndexNumber": indexNumber,
          "RemoteTrailers": [],
          "ProviderIds": {},
          "IsFolder": true,
          "ParentId": seriesId,
          "Type": "Season",
          "People": [],
          "Studios": [],
          "GenreItems": [],
          "LocalTrailerCount": 0,
          "UserData": {
            "PlayedPercentage": 0,
            "UnplayedItemCount": 3,
            "PlaybackPositionTicks": 0,
            "PlayCount": 0,
            "IsFavorite": false,
            "Played": false,
            "Key": "a8b472e7763145e28526af47adac43f0"
          },
          "RecursiveItemCount": 3,
          "ChildCount": 3,
          "SeriesName": allItems[seriesId]!['Name'],
          "SeriesId": seriesId,
          "SpecialFeatureCount": 0,
          "DisplayPreferencesId": "dfd065f5787fb957a750d76dcf835aad",
          "Tags": [],
          "PrimaryImageAspectRatio": 0.6666666666666666,
          "SeriesPrimaryImageTag": "110d5a5cfaad64f5a71a11a7bbeef893",
          "ImageTags": {},
          "BackdropImageTags": [],
          "ScreenshotImageTags": [],
          "ImageBlurHashes": {},
          "SeriesStudio": "Vup TV Studio",
          "LocationType": "Virtual",
          "LockedFields": [],
          "LockData": false
        };
        return Tuple2(id, indexNumber);
      }

      for (final key in index.files.keys) {
        final video = index.files[key]!;
        final directoryPath = getDirectoryPath(rootPath, video.uri!);

        if (video.ext?['video'] == null) {
          continue;
        }

        if (directoryPath.isEmpty) continue;

        // logger.verbose('dir $directoryPath');
        final seriesName = directoryPath[0];
        late final String seasonName;
        if (autoSeasonModeEnabled) {
          seasonName =
              video.ext?['video']['date']?.substring(0, 4) ?? 'All Videos';
        } else {
          seasonName =
              directoryPath.length < 2 ? 'Season 01' : directoryPath[1];
        }

        final seriesId = processSeries(
          seriesName,
          path: directoryPath[0],
          // displayName: video.ext?['video']?['artist'], // TODO Opt-in
        );
        // logger.verbose('seriesId $seriesId');

        final seasonRes = processSeason(
          seriesId,
          seasonName,
          path: directoryPath.length == 1
              ? directoryPath.first
              : directoryPath.sublist(0, 2).join('/'),
        );
        final seasonId = seasonRes.item1;

        final videoId = JellyID.file(video);
        // addLatestItem(videoId);

        recursiveParentToChildMap[seriesId] ??= [];
        recursiveParentToChildMap[seriesId]!.add(videoId);

        parentToChildMap[seriesId] ??= [];

        if (!parentToChildMap[seriesId]!.contains(seasonId)) {
          parentToChildMap[seriesId]!.add(seasonId);
        }

        parentToChildMap[seasonId] ??= [];
        parentToChildMap[seasonId]!.add(videoId);

        final videoItem = _buildVideoItemForFile(
          video,
          isMovie: false,
          collectionId: collectionId,
          rootPath: rootPath,
        );
        // if (videoItem['PremiereDate'] != null) {

        premiereDates[seriesId] ??= DateTime(3000);
        endDates[seriesId] ??= DateTime(0);

        final date = DateTime.parse(videoItem['PremiereDate']);
        // logger.verbose('PremiereDate $date');
        if (date.isBefore(premiereDates[seriesId]!)) {
          premiereDates[seriesId] = date;
        }
        if (date.isAfter(endDates[seriesId]!)) {
          endDates[seriesId] = date;
        }
        // premiereDates
        // }

        videoItem.addAll({
          // TODO Swap season and series name for YT videos
          'SeasonId': seasonId,
          'SeasonName': seasonName,
          'SeriesId': seriesId,
          'SeriesName': seriesName,
          // 'IndexNumber': 1,
          'ParentIndexNumber': seasonRes.item2,
        });

        videoItem['SortName'] = seasonRes.item2.toString().padLeft(6, '0') +
            '-' +
            videoItem['IndexNumber'].toString().padLeft(6, '0');

        allItems[videoId] = videoItem;
        recursiveParentToChildMap[collectionId]!.add(videoId);
      }

      for (final id in allItems.keys) {
        if (!recursiveParentToChildMap[collectionId]!.contains(id)) continue;

        final item = allItems[id]!;

        final map = <String, dynamic>{
          "ImageTags": {},
          "BackdropImageTags": [],
          "ScreenshotImageTags": [],
          "ImageBlurHashes": {},
        };

        void addBackdropThumbnail(String? uri) {
          if (uri == null) return;
          final image = index.files[uri]!;

          map['ImageBlurHashes'] ??= {};
          map['ImageBlurHashes']['Backdrop'] ??= {};
          final type = 'Backdrop';

          map['BackdropImageTags'] = [id];

          allCoverKeysMap[id.subhash(type)] = image.file.thumbnail?.cid;
        }

        if (item['Type'] == 'Series') {
          final coverKey = getThumbnailForPath(coverImages, item['Path']);
          addThumbnail(
            map: map,
            id: id,
            type: 'Primary',
            uri: coverKey,
          );
          final backdropKey = getThumbnailForPath(backdropImages, item['Path']);
          addBackdropThumbnail(backdropKey);

          if (premiereDates.containsKey(id)) {
            map['PremiereDate'] = premiereDates[id]!.toIso8601String();
            map['ProductionYear'] = premiereDates[id]!.year;
            map['EndDate'] = endDates[id]!.toIso8601String();
            map['Status'] = 'Ended';
          }
        } else if (item['Type'] == 'Season') {
          final coverKey = getThumbnailForPath(coverImages, item['Path']);
          addThumbnail(
            map: map,
            id: id,
            type: 'Primary',
            uri: coverKey,
          );
          final backdropKey = getThumbnailForPath(backdropImages, item['Path']);

          addBackdropThumbnail(backdropKey);
        }
        if (map.isNotEmpty) {
          for (final key in map.keys) {
            allItems[id]![key] ??= map[key];
          }
        }

        // "Type": "Series",
      }

      /*     for (final imageKey in imageFiles.keys) {
        final imageFile = index.files[imageKey]!;
        final path = imageFiles[imageKey]!;

        final directoryId = sha1
            .convert(utf8.encode(
              'directory_' + collectionId + '_' + path.join('/'),
            ))
            .toString();

        final coverKey = imageFile.ext?['thumbnail']['cid'];

        for (final audioId in parentToChildMap[directoryId] ?? []) {
          allCoverKeysMap[audioId] = coverKey;
          allItems[audioId]!.addAll(<String, dynamic>{
            "ImageTags": {"Primary": audioId},
            "ImageBlurHashes": {
              "Primary": {
                audioId: imageFile.ext?['thumbnail']?['blurHash'],
              }
            },
          });
        }

        while (path.isNotEmpty) {
          final directoryId = sha1
              .convert(utf8.encode(
                'directory_' + collectionId + '_' + path.join('/'),
              ))
              .toString();

          allCoverKeysMap[directoryId] = coverKey;

          allItems[directoryId]!.addAll(<String, dynamic>{
            "ImageTags": {"Primary": directoryId},
            "ImageBlurHashes": {
              "Primary": {
                directoryId: imageFile.ext?['thumbnail']?['blurHash'],
              }
            },
          });

          path.removeLast();
        }
      } */
    } else if (type == 'movies') {
      // final coverImages = <String, String>{};

      for (final movie in index.files.values) {
        // if (movie.ext?['video'] == null) continue;

        final directoryPath = getDirectoryPath(rootPath, movie.uri!);
        if (movie.ext?['video'] == null) {
          /*   if (movie.ext?['thumbnail'] != null) {
            final name = basenameWithoutExtension(movie.name);

            if (['cover', 'folder', 'poster', 'default', 'show']
                .contains(name)) {
              coverImages[directoryPath.join('/')] = movie.key!;
            }
          } */
          continue;
        }

        if (directoryPath.isEmpty) continue;

        final media = customMediaItems[directoryPath.join('/')];

        final movieId = JellyID.file(movie);

        addLatestItem(movieId);

        // final movieId = movie.file.hash;

        final video = _buildVideoItemForFile(
          movie,
          isMovie: true,
          collectionId: collectionId,
          rootPath: rootPath,
        );

        final coverKey = getThumbnailForPath(coverImages, video['Path']);

        final map = <String, dynamic>{};

        final thumbnailKey = addThumbnail(
          map: map,
          id: movieId,
          type: 'Primary',
          uri: coverKey,
        );

        if (map.isNotEmpty) {
          video.addAll(map);
        }

        allCoverKeysMap[movieId] = thumbnailKey ?? movie.file.thumbnail?.cid;

        if (media != null) {
          for (final me in media['item'].cast<String, dynamic>().entries) {
            if (me.key != 'Id') {
              video[me.key] = me.value;
            }
          }

          for (final item in (media['items'] ?? [])) {
            allItems[item['Id']] = item;
          }
        }

        /*  final coverKey = coverImages[video['Path']];

        if (coverKey != null) {
          final image = index.files[uri]!;
          video['ImageTags'] ??= {};
          video['ImageBlurHashes'] ??= {};

          final coverId = '$movieId/Primary';

          video['ImageTags']!['Primary'] = movieId;
          video['ImageBlurHashes']!['Primary'] = {
            movieId: image.ext?['thumbnail']['blurHash'],
          };
          allCoverKeysMap[coverId] = image.ext?['thumbnail']['cid'];
        } */

        allItems[movieId] = video;
        recursiveParentToChildMap[collectionId]!.add(movieId);
      }

      final ytDLResponse = [];
      for (final media in ytDLResponse) {
        final id = JellyID.hash(media['url'] as String);

        mediaStreamsByHash[id] = media;

        final ticks = ((media['duration'] as double) * tickMultiplier).round();
        allItems[id] = {
          "Name": media['title'] as String,
          "ServerId": serverId,
          "Id": id,
          "Container": 'mp4',
          "ChannelId": null,
          "RunTimeTicks": ticks,
          "IsFolder": false,
          "Type": "Movie",
          'MediaSources': [
            {
              "Protocol": "File",
              "Id": id,
              "Path": 'video.mp4',
              "Type": "Default",
              "Container": 'mp4',
              "Size": 10000,
              "Name": media['title'] as String,
              "IsRemote": false,
              "ETag": id,
              "RunTimeTicks": ticks,
              "ReadAtNativeFramerate": false,
              "IgnoreDts": false,
              "IgnoreIndex": false,
              "GenPtsInput": false,
              "SupportsTranscoding": false,
              "SupportsDirectStream": true,
              "SupportsDirectPlay": true,
              "IsInfiniteStream": false,
              "RequiresOpening": false,
              "RequiresClosing": false,
              "RequiresLooping": false,
              "SupportsProbing": true,
              "VideoType": "VideoFile",
              "MediaStreams": [
                {
                  "Codec": "h264",
                  "CodecTag": "avc1",
                  "Language": "und",
                  "TimeBase": "1/90000",
                  "CodecTimeBase": "1/100",
                  "VideoRange": "SDR",
                  "DisplayTitle": "1080p H264 SDR",
                  "NalLengthSize": "0",
                  "IsInterlaced": false,
                  "IsAVC": false,
                  "BitRate": 1165758,
                  "BitDepth": 8,
                  "RefFrames": 1,
                  "IsDefault": true,
                  "IsForced": false,
                  "Height": 1080,
                  "Width": 1920,
                  "AverageFrameRate": 50,
                  "RealFrameRate": 50,
                  "Profile": "High",
                  "Type": "Video",
                  "AspectRatio": "16:9",
                  "Index": 0,
                  "IsExternal": false,
                  "IsTextSubtitleStream": false,
                  "SupportsExternalStream": false,
                  "PixelFormat": "yuv420p",
                  "Level": 42
                },
              ],
              "MediaAttachments": [],
              "Formats": [],
              "Bitrate": 1165758,
              "RequiredHttpHeaders": {},
              "DefaultAudioStreamIndex": 1
            }
          ],
          "UserData": {},
          "PrimaryImageAspectRatio": 1.777777777777778,
          // (movie.ext?['thumbnail']?['aspectRatio'] ?? 1),
          "VideoType": "VideoFile",
          "ImageTags": /*   allCoverKeysMap[movieId] == null ? */ {},
          /* : {"Primary": movieId}, */
          "BackdropImageTags": [],
          "ImageBlurHashes": /* allCoverKeysMap[movieId] == null
              ? */
              {}
          /* : {
                  "Primary": {
                    movieId: movie.ext?['thumbnail']?['blurHash'],
                  }
                } */
          ,
          "LocationType": "Remote",
          "MediaType": "Video"
        };

        // parentToChildMap[albumId]!.add(songId);
        recursiveParentToChildMap[collectionId]!.add(id);
      }
    } else if (type == 'books' || type == 'mixed') {
      // final booksCoverMap = {};
      folderCollectionIds.add(collectionId);

      for (final key in index.files.keys) {
        final file = index.files[key]!;

        // final directoryPath = getDirectoryPath(rootPath, file.uri!);

        /*  */
        /*     final directoryId = createDirectory(
          collectionId: collectionId,
          directoryPath: directoryPath,
        ); */

        final fileId = JellyID.file(file);

        if (file.ext?['audio'] != null) {
          final coverKey = file.file.thumbnail?.cid;
          if (coverKey != null) allCoverKeysMap[fileId] = coverKey;

          final item = _buildAudioItemForFile(
            file,
            isAudiobook: true,
            rootPath: rootPath,
            collectionId: collectionId,
          );

          final parts = file.name.split('-');

          try {
            item['IndexNumber'] = int.parse(parts[0]);

            int year = int.parse(parts[1]);
            int month = int.parse(parts[2]);
            int day = int.parse(parts[3]);

            // item.remove('ProductionYear');

            item['PremiereDate'] =
                DateTime(year, month, day).toUtc().toIso8601String();

            item['Name'] = parts.sublist(4).join(' ');
          } catch (e) {}

          allItems[fileId] = item;
          addLatestItem(fileId);

          // TODO "PremiereDate": "2020-10-20T20:00:00.0000000Z",
        } else if (file.ext?['video'] != null) {
          final coverKey = file.file.thumbnail?.cid;

          if (coverKey != null) allCoverKeysMap[fileId] = coverKey;

          final item = _buildVideoItemForFile(
            file,
            isMovie: true,
            rootPath: rootPath,
            collectionId: collectionId,
          );

          allItems[fileId] = item;
          addLatestItem(fileId);
        }
      }

      for (final imageKey in allImageFiles.keys) {
        final imageFile = index.files[imageKey]!;
        final path = allImageFiles[imageKey]!;

        final directoryId = JellyID.hash(
          'directory_$collectionId' + '_' + path.join('/'),
        );

        final coverKey = imageFile.file.thumbnail?.cid;

        for (final audioId in parentToChildMap[directoryId] ?? []) {
          allCoverKeysMap[audioId] = coverKey;
          allItems[audioId]!.addAll(<String, dynamic>{
            "ImageTags": {"Primary": audioId},
            /*  "ImageBlurHashes": {
              "Primary": {
                audioId: imageFile.ext?['thumbnail']?['blurHash'],
              }
            }, */
          });
        }

        while (path.isNotEmpty) {
          final directoryId = JellyID.hash(
            'directory_$collectionId' + '_' + path.join('/'),
          );

          allCoverKeysMap[directoryId] = coverKey;

          allItems[directoryId]?.addAll(<String, dynamic>{
            "ImageTags": {"Primary": directoryId},
            /*  "ImageBlurHashes": {
              "Primary": {
                directoryId: imageFile.ext?['thumbnail']?['blurHash'],
              }
            }, */
          });

          path.removeLast();
        }
      }
    }
    allCoverKeysMap[collectionId] =
        allCoverKeysMap.isEmpty ? null : allCoverKeysMap.values.last;

    info('create collection $collectionId $name');

    final collectionMap = {
      "Name": name,
      "ServerId": serverId,
      "Id": collectionId,
      "ChannelId": null,
      "IsFolder": true,
      "Type": "CollectionFolder",
      "UserData": {
        "PlaybackPositionTicks": 0,
        "PlayCount": 0,
        "IsFavorite": false,
        "Played": false,
        "Key": "a8b472e7763145e28526af47adac43f0"
      },
      "CollectionType": type,
      "ImageTags": {},
      "ImageBlurHashes": {},
      "BackdropImageTags": [],
      "LocationType": "Remote",
      // ---
      "Etag": DateTime.now().toIso8601String(),
      "DateCreated": "2021-02-20T18:28:00.000000Z",
      "CanDelete": false,
      "CanDownload": false,
      "SortName": convertToSortName(name),
      "ExternalUrls": [],
      "Path": uri,
      "EnableMediaSourceDisplay": true,
      "Taglines": [],
      "Genres": [],
      "PlayAccess": "Full",
      "RemoteTrailers": [],
      "ProviderIds": {},
      "ParentId": serverId,
      "People": [],
      "Studios": [],
      "GenreItems": [],
      "LocalTrailerCount": 0,

      "ChildCount": 1,
      "SpecialFeatureCount": 0,
      "DisplayPreferencesId": "fcc7edaa068ebdee843a2b5834b2d651",
      "Tags": [],
      "PrimaryImageAspectRatio": 1.7777777777777777,

      "ScreenshotImageTags": [],

      "LockedFields": [],
      "LockData": false
    };
    if (coverImages[''] != null) {
      final key = addThumbnail(
        map: collectionMap,
        id: collectionId,
        type: 'Primary',
        uri: coverImages[''],
      );

      allCoverKeysMap[collectionId] = key;
    }

    collectionsMap[collectionId] = collectionMap;
    allItems[collectionId] = collectionsMap[collectionId]!;
  }

  List<String> getDirectoryPath(List<String> rootPath, String uri) {
    final path = storageService.dac.parseFilePath(uri);
    return Uri.parse(path.directoryPath).pathSegments.sublist(rootPath.length);
  }

  JellyID createDirectory(
      {required JellyID collectionId, required List<String> directoryPath}) {
    final startDirectoryId = JellyID.hash(
      'directory_$collectionId' + '_' + directoryPath.join('/'),
    );

    if (directoryPath.isEmpty) {
      return collectionId;
    }

    while (true) {
      final directoryId = JellyID.hash(
        'directory_$collectionId' + '_' + directoryPath.join('/'),
      );
      var parentId = collectionId;

      if (directoryPath.length > 1) {
        parentId = JellyID.hash(
          'directory_$collectionId' +
              '_' +
              directoryPath.sublist(0, directoryPath.length - 1).join('/'),
        );
      }

      if (!allItems.containsKey(directoryId)) {
        if (!parentToChildMap.containsKey(parentId)) {
          parentToChildMap[parentId] = [];
        }
        parentToChildMap[parentId]!.add(directoryId);

        allItems[directoryId] = {
          "Name": directoryPath.last,
          "ServerId": serverId,
          "Id": directoryId,
          "ChannelId": null,
          "IsFolder": true,
          "Type": "Folder",
          "UserData": {
            "UnplayedItemCount": 0,
            "PlaybackPositionTicks": 0,
            "PlayCount": 0,
            "IsFavorite": false,
            "Played": false,
            "Key": "a8b472e7763145e28526af47adac43f0"
          },
          "ImageTags": {},
          "BackdropImageTags": [],
          "ImageBlurHashes": {},
          "ParentId": parentId,
          "LocationType": "Remote"
        };
      }
      directoryPath.removeLast();
      if (directoryPath.isEmpty) {
        return startDirectoryId;
        // break;
      }
    }
  }

  final numberMatcher = RegExp(r'(S)?([0-9]+)');
  // final numberMatcher = RegExp(r'[0-9]+');

  Map<String, dynamic> _buildVideoItemForFile(
    FileReference file, {
    required bool isMovie,
    required JellyID collectionId,
    required List<String> rootPath,
  }) {
    final directoryPath = getDirectoryPath(rootPath, file.uri!);
    final path = directoryPath.join('/');
    /*  */
    final directoryId = createDirectory(
      collectionId: collectionId,
      directoryPath: directoryPath,
    );
    parentToChildMap[directoryId] ??= [];

    final videoId = JellyID.file(file);

    parentToChildMap[directoryId]!.add(videoId);

    // moviesMap

    final coverKey = file.file.thumbnail?.cid;
    if (coverKey != null) allCoverKeysMap[videoId] = coverKey;

    final format_name =
        file.ext?['video']['format_name'] ?? "mov,mp4,m4a,3gp,3g2,mj2";

    final bitRate = file.ext?['video']['bit_rate'] ?? 0;

    final int ticks =
        ((file.ext?['video']['duration'] ?? 1) * tickMultiplier).round();

    String name = file.ext?['video']?['episode_id'] ??
        file.ext?['video']?['title'] ??
        file.name;

    /*  if (file.ext?['video']?['artist'] != null) {
      name = file.ext?['video']?['artist'] + ': ' + name;
    } */
    final streams = file.ext?['video']?['streams'] ??
        [
          // {"width": 1920, "height": 1080}
          {"width": 1920, "height": 1080}
        ];

/*     if (genreId != null)
      logger.verbose({
        'Name': allItems[genreId]!['Name'],
        'Id': genreId,
      }); */

    int? indexNumber =
        int.tryParse((file.ext?['video']?['episode_sort']).toString());

    indexNumber ??= file.ext?['video']?['track'] == null
        ? null
        : file.ext?['video']?['track'] is int
            ? file.ext?['video']?['track']
            : int.tryParse(
                file.ext?['video']['track']); //  file.name.split(pattern);

    if (indexNumber == null) {
      final matches = numberMatcher.allMatches(file.name);

      for (final m in matches) {
        if (m.group(1) == 'S') {
          continue;
        }
        indexNumber = int.parse(m.group(2)!);
        break;
      }
    }
    indexNumber ??= 1;
    // logger.verbose('indexNumber $indexNumber ${file.name}');

    final item = {
      "Name": name,
      "ServerId": serverId,
      "Id": videoId,
      "Path": path,
      "Container": format_name,
      "ChannelId": null,
      "RunTimeTicks": ticks,
      "Overview":
          file.ext!['video']?['description'] ?? file.ext!['video']?['comment'],
      "IsFolder": false,
      "IndexNumber": indexNumber,
      "DateCreated":
          DateTime.fromMillisecondsSinceEpoch(file.created).toIso8601String(),
      "Type": "Video",
      'MediaSources': [
        {
          "Protocol": "File",
          "Id": videoId,
          "Path": file.name,
          "Type": "Default",
          "Container": format_name,
          "Size": file.file.cid.size,
          "Name": file.name,
          "IsRemote": false,
          "ETag": file.file.cid.hash.toBase64Url(),
          "RunTimeTicks": ticks,
          "ReadAtNativeFramerate": false,
          "IgnoreDts": false,
          "IgnoreIndex": false,
          "GenPtsInput": false,
          "SupportsTranscoding": false,
          "SupportsDirectStream": true,
          "SupportsDirectPlay": true,
          "IsInfiniteStream": false,
          "RequiresOpening": false,
          "RequiresClosing": false,
          "RequiresLooping": false,
          "SupportsProbing": true,
          "VideoType": "VideoFile",
          "MediaStreams": [
            for (final stream in streams)
              {
                "Codec": "h264",
                "CodecTag": "avc1",
                "Language": "und",
                "TimeBase": "1/90000",
                "CodecTimeBase": "1/100",
                "VideoRange": "SDR",
                "DisplayTitle": "1080p H264 SDR",
                "NalLengthSize": "0",
                "IsInterlaced": false,
                "IsAVC": false,
                "BitRate": bitRate,
                "BitDepth": 8,
                "RefFrames": 1,
                "IsDefault": true,
                "IsForced": false,
                "Height": stream['height'],
                "Width": stream['width'],
                "AverageFrameRate": 50,
                "RealFrameRate": 50,
                "Profile": "High",
                "Type": "Video",
                "AspectRatio": "16:9",
                "Index": 0,
                "IsExternal": false,
                "IsTextSubtitleStream": false,
                "SupportsExternalStream": false,
                "PixelFormat": "yuv420p",
                "Level": 42
              },
            ...() {
              int i = 0;
              final list = <Map>[];
              // TODO Build subtitles in same dir
              /* for (final subtitle in file.ext!['video']?['subtitles'] ?? []) {
                final map = _buildSubtitleStream(videoId, subtitle);
                i++;
                map['Index'] = i;
                list.add(map);
              } */
              return list;
            }()
          ],
          "MediaAttachments": [],
          "Formats": [],
          "Bitrate": bitRate,
          "RequiredHttpHeaders": {},
          "DefaultAudioStreamIndex": 1,
          "DefaultSubtitleStreamIndex": 2
        }
      ],
      "UserData": {},
      "PrimaryImageAspectRatio": file.file.thumbnail?.aspectRatio ?? 1.0,
      "VideoType": "VideoFile",
      "ImageTags": allCoverKeysMap[videoId] == null ? {} : {"Primary": videoId},
      "BackdropImageTags": [],
      /*   "ImageBlurHashes": allCoverKeysMap[videoId] == null
          ? {}
          : {
              "Primary": {
                videoId: file.ext?['thumbnail']?['blurHash'],
              }
            }, */
      "LocationType": "Remote",
      "MediaType": "Video"
    };
    if (file.ext?['video']['date'] != null) {
      item['PremiereDate'] = file.ext?['video']['date'];
    }
    item['PremiereDate'] ??=
        DateTime.fromMillisecondsSinceEpoch(file.created).toIso8601String();

    if (isMovie) {
      item["Type"] = 'Movie';
      item['SortName'] = convertToSortName(name);
    } else {
      item["Type"] = 'Episode';
    }

    return item;
  }

  Map<JellyID, Map> subtitleFilesMap = {};

  Map _buildSubtitleStream(JellyID videoId, Map subtitle) {
    final subtitleId = JellyID.hash('subtitle_${subtitle['file']['hash']}');

    subtitleFilesMap[subtitleId] = subtitle[
        'file']; /* DirectoryFile(
      name: 'stream.vtt',
      mimeType: 'text/vtt',
      created: 0,
      modified: 0,
      version: 0,
      file: FileData.fromJson(subtitle['file']),
    ); */
    final map = {
      "Codec": "mov_text",
      "CodecTag": "tx3g",
      "Language": subtitle['lang'],
      "TimeBase": "1/1000000",
      "CodecTimeBase": "0/1",
      "localizedUndefined": "Undefiniert",
      "localizedDefault": "Standard",
      "localizedForced": "Erzwungen",
      "DisplayTitle": subtitle['lang'].toUpperCase(),
      "IsInterlaced": false,
      "BitRate": 120,
      "IsDefault": true,
      "IsForced": false,
      "Type": "Subtitle",
      "Index": subtitle['index'],
      "Score": 112221,
      "IsExternal": false,
      "DeliveryMethod": "External",
      "DeliveryUrl":
          '/Videos/$videoId/${subtitleId}/Subtitles/2/0/Stream.vtt?api_key=1234abc',
      //"/Subtitles/$hash/stream.vtt?api_key=none", // TODO API Key
      "IsExternalUrl": false,
      "IsTextSubtitleStream": true,
      "SupportsExternalStream": true,
      "Level": 0
    };
    return map;
  }

  Map<String, dynamic> _buildAudioItemForFile(FileReference file,
      {required bool isAudiobook,
      required JellyID collectionId,
      required List<String> rootPath,
      JellyID? genreId}) {
    final directoryPath = getDirectoryPath(rootPath, file.uri!);
    final path = directoryPath.join('/');

    /*  */
    final directoryId = createDirectory(
      collectionId: collectionId,
      directoryPath: directoryPath,
    );
    parentToChildMap[directoryId] ??= [];

    final songId = JellyID.file(file);

    parentToChildMap[directoryId]!.add(songId);

    final codec =
        file.ext?['audio']['format_name'] ?? file.name.split('.').last;

    final bitRate = file.ext?['audio']['bit_rate'] ?? 0;

    final int ticks =
        ((file.ext?['audio']['duration'] ?? 1) * tickMultiplier).round();

/*     if (genreId != null)
      logger.verbose({
        'Name': allItems[genreId]!['Name'],
        'Id': genreId,
      }); */

    final item = {
      "Name": file.ext?['audio']?['title'] ?? file.name,
      "ServerId": serverId,
      "SortName": file.ext?['audio']['track']?.padLeft(6, '0') ??
          convertToSortName(file.ext?['audio']?['title'] ?? file.name),
      "Path": path,
      "Id": songId,
      "ChannelId": null,
      "DateCreated":
          DateTime.fromMillisecondsSinceEpoch(file.created).toIso8601String(),
      "Genres": [
        if (genreId != null) allItems[genreId]!['Name'],
      ],
      "RunTimeTicks": ticks,
      "ProductionYear": file.ext?['audio']['date'] == null
          ? null
          : int.tryParse(file.ext?['audio']['date'].substring(0, 4)),
      "IndexNumber": file.ext?['audio']['track'] == null
          ? 1
          : int.tryParse(file.ext?['audio']['track']),
      "IsFolder": false,
      "GenreItems": [
        if (genreId != null)
          {
            'Name': allItems[genreId]!['Name'],
            'Id': genreId,
          }
      ],
      "UserData": {
        "PlaybackPositionTicks": 0,
        "PlayCount": activityService.getPlayCount(songId),
        "IsFavorite": false,
        "Played": false,
        "Key": songId,
      },
      'MediaSources': [
        {
          "Protocol": "File",
          "Id": JellyID.file(file),
          "Path": directoryPath.join('/'),
          "Type": "Default",
          "Container": codec,
          "Size": file.file.cid.size,
          "Name": file.name,
          "IsRemote": false,
          "ETag": JellyID.file(file),
          "RunTimeTicks": ticks,
          "ReadAtNativeFramerate": false,
          "IgnoreDts": false,
          "IgnoreIndex": false,
          "GenPtsInput": false,
          "SupportsTranscoding": false,
          "SupportsDirectStream": true,
          "SupportsDirectPlay": true,
          "IsInfiniteStream": false,
          "RequiresOpening": false,
          "RequiresClosing": false,
          "RequiresLooping": false,
          "SupportsProbing": true,
          "MediaStreams": [
            {
              "Codec": codec,
              "TimeBase": "1/14112000",
              "CodecTimeBase": "1/44100",
              "DisplayTitle": codec,
              "IsInterlaced": false,
              "ChannelLayout": "stereo",
              "BitRate": bitRate,
              "Channels": 2,
              "SampleRate": 44100,
              "IsDefault": false,
              "IsForced": false,
              "Type": "Audio",
              "Index": 0,
              "IsExternal": false,
              "IsTextSubtitleStream": false,
              "SupportsExternalStream": false,
              "Level": 0
            }
          ],
          "MediaAttachments": [],
          "Formats": [],
          // "BitRate": bitRate,
          "Bitrate": bitRate,
          "RequiredHttpHeaders": {},
          "DefaultAudioStreamIndex": 0
        }
      ],
      "ImageTags": allCoverKeysMap[songId] == null ? {} : {"Primary": songId},
      "BackdropImageTags": [],
      /*   "ImageBlurHashes": allCoverKeysMap[songId] == null
          ? {}
          : {
              "Primary": {
                songId: file.ext?['thumbnail']?['blurHash'],
              }
            }, */
      "ParentId": directoryId,
      "LocationType": "Remote",
      "MediaType": "Audio"
    };

    if (file.ext?['audio']['date'] != null) {
      item['PremiereDate'] = file.ext?['audio']['date'];
    }

    if (isAudiobook) {
      item["Type"] = 'AudioBook';
    } else {
      item["Type"] = 'Audio';
    }

    return item;
  }

  void _updatePlaylists() {
    allItems.removeWhere((key, value) => value['Type'] == 'Playlist');
    return;

    for (final idStr in playlistService.playlists.keys) {
      if (idStr == 'favorites') continue; // TODO Fix
      final p = playlistService.playlists.get(idStr)!;
      final id = JellyID.fromHex(idStr);
      if (p['deleted'] == true) continue;
      parentToChildMap[id] = [];
      for (final item in p['items']) {
        //if (getItemById() ['Type'] != 'Audio') continue;
        parentToChildMap[id]!.add(item['id']);
      }
      allItems[id] = {
        "Name": p['name'],
        "Overview": p['overview'],
        "ServerId": serverId,
        "Id": id,
        "CanDelete": true,
        "SortName": p['name'].toLowerCase(),
        "ChannelId": null,
        "RunTimeTicks": 1, // TODO
        "IsFolder": true,
        "Type": "Playlist",
        "UserData": {
          "PlaybackPositionTicks": 0,
          "PlayCount": 0,
          "IsFavorite": false,
          "Played": false,
          "Key": "a8b472e7763145e28526af47adac43f0"
        },
        "PrimaryImageAspectRatio": 1,
        "ImageTags": {},
        "BackdropImageTags": [],
        "ImageBlurHashes": {},
        "LocationType": "Remote",
        "MediaType": p['mediaType'],
      };
    }
  }

  bool isStarting = false;

  Future<void> start(
    int port,
    String bindIp,
    String username,
    String password,
    // required int vuePort,
  ) async {
    if (isRunning) return;
    verbose('[timing] ${DateTime.now()} start');

    serverId = JellyID(
      deriveHashBlake3(
        mySky.identity.fsRootKey,
        utf8.encode('jellyfin-server'),
        crypto: mySky.api.crypto,
      ).sublist(0, 16),
    );

    isRunning = true;
    isStarting = true;

    playlistService.stream.listen((event) {
      _updatePlaylists();
    });
    _updatePlaylists();

    if (dataBox.get('jellyfin_server_token') == null) {
      dataBox.put('jellyfin_server_token', Uuid().v4().replaceAll('-', ''));
    }
    final serverToken = dataBox.get('jellyfin_server_token');

    final authEnabled = false;

    /* final collectionsConfig =
        List.from(dataBox.get('jellyfin_server_collections') ?? []); */

    late final List collectionsConfig;
    try {
      final res = await hiddenDB
          .getJSON(
            jellyfinCollectionsPath,
          )
          .timeout(Duration(seconds: 10));
      if (res.data == null) throw 'Error';

      collectionsConfig = List.from(
        res.data ?? [],
      );
      dataBox.put('jellyfin_server_collections', collectionsConfig);
    } catch (e) {
      collectionsConfig = dataBox.get('jellyfin_server_collections') ?? [];
    }
    info('collectionsConfig ${dataBox.get('jellyfin_server_collections')}');

    collectionsConfig.sort((a, b) => a['name'].compareTo(b['name']));

    for (final config in collectionsConfig) {
      try {
        await processCollectionConfig(config);
      } catch (e, st) {
        error('$e: $st');
      }
    }
    Map<String, dynamic>? getItemById(JellyID? itemId) {
      if (collectionsMap.containsKey(itemId)) {
        return collectionsMap[itemId];
      }
      final item = allItems[itemId]; /* ??
          collectionsMap[itemId] */

      if (item == null) return null;

      final playCount = activityService.getPlayCount(item['Id']);

      final int playbackPositionTicks =
          (activityService.getPlayPosition(item['Id']) * tickMultiplier / 1000)
              .round();

      final ticks = item['RunTimeTicks'];

      if (ticks == null || ticks == 0) {
        return item;
      }

      item['UserData'] = {
        "PlayedPercentage": playbackPositionTicks / ticks * 100,
        "PlaybackPositionTicks": playbackPositionTicks,
        "PlayCount": playCount,
        "IsFavorite": playlistService.isItemOnPlaylist('favorites', itemId),
        "LastPlayedDate":
            activityService.getLastPlayedDate(itemId).toIso8601String(),
        "Played": playCount > 0,
        "Key": itemId,
        /* "PlaybackPositionTicks": 0,
          "PlayCount": 0,
          "IsFavorite": false,
          "Played": false,
          "Key": "a8b472e7763145e28526af47adac43f0" */
        /* "PlayedPercentage": 27.0000,
          "PlaybackPositionTicks": 1000000000, */
        /* "PlayCount": 1, */
        /*    "IsFavorite": false,
          "LastPlayedDate": "2021-12-19T00:23:02.5358229Z",
          "Played": false,
          "Key": "a8b472e7763145e28526af47adac43f0" */
      };
      return item;
    }

    info('fetching activity data...');

    for (final itemId in allItems.keys) {
      getItemById(itemId);
    }

    final webAppsDir = join(storageService.dataDirectory, 'web');
    Future<Directory?> provideWebAppDir(
      String type,
      CID resolverCID,
    ) async {
      try {
        info('checking for $type updates...');

        final sre = await mySky.api.registryGet(resolverCID.hash.fullBytes);

        final staticCID = CID.fromBytes(sre!.data.sublist(1));

        final outDir = Directory(join(webAppsDir, type, staticCID.toBase32()));

        if (!outDir.existsSync()) {
          info('downloading new $type version...');

          final cacheFile = File(
            join(
              storageService.temporaryDirectory,
              'web-app',
              '${staticCID.toBase32()}.zip',
            ),
          );
          cacheFile.parent.createSync(recursive: true);

          await s5Node.downloadFileByHash(
            hash: staticCID.hash,
            outputFile: cacheFile,
          );

          outDir.createSync(recursive: true);

          extractFileToDisk(cacheFile.path, outDir.path);

          cacheFile.deleteSync();

          info('downloaded latest $type version.');
        }
        return outDir;

        // return;
      } catch (e, st) {
        logger.verbose(e);
        logger.verbose(st);
        final dir = Directory(join(webAppsDir, type));
        if (dir.existsSync()) {
          final List<Directory> dirs = dir
              .listSync()
              .where((e) => e is Directory)
              .cast<Directory>()
              .toList();

          if (dirs.isNotEmpty) {
            dirs.sort(
              (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
            );

            return dirs.last;
          } else {
            error('could not download $type');
          }
        } else {
          error('could not download $type');
        }
      }
    }

    Directory? jellyfinWebDir = await provideWebAppDir(
      'jellyfin-web',
      CID.decode('zrjQ9gpMzTRSFVLjqSBd9uKspHxtTYwQPR2QELW2gBDzn73'),
    );
    Directory? jellyfinVueDir = await provideWebAppDir(
      'jellyfin-vue',
      CID.decode('zrjF9GY7T8jKkAzwSrD9tVuFZYAHQHVu2W8y6QS7Cbizsyq'),
    );
    Directory? feishinWebDir = await provideWebAppDir(
      'feishin-web',
      CID.decode('zrjEcJBWMq8e8RQRcVEtWGaFRSUtsmsfhtAnzeu5d91UZTw'),
    );

    // final jellyfinVueDir = join(webAppsDir, 'jellyfin-vue');

    info('starting server...');

    final currentUserData = {
      "Name": username,
      "ServerId": serverId,
      "Id": "074a223ae7744d31856c862157b1e502",
      "HasPassword": true,
      "HasConfiguredPassword": true,
      "HasConfiguredEasyPassword": false,
      "EnableAutoLogin": false,
      "LastLoginDate": "2021-12-18T13:52:01.3195407Z",
      "LastActivityDate": "2021-12-18T13:52:01.3195407Z",
      "Configuration": dataBox.get('jellyfin_user_configuration') ??
          {
            "PlayDefaultAudioTrack": true,
            "SubtitleLanguagePreference": "",
            "DisplayMissingEpisodes": false,
            "GroupedFolders": [],
            "SubtitleMode": "Default",
            "DisplayCollectionsView": false,
            "EnableLocalPassword": false,
            "OrderedViews": [],
            "LatestItemsExcludes": [],
            "MyMediaExcludes": [],
            "HidePlayedInLatest": true,
            "RememberAudioSelections": true,
            "RememberSubtitleSelections": true,
            "EnableNextEpisodeAutoPlay": true
          },
      "Policy": {
        "IsAdministrator": false,
        "IsHidden": true,
        "IsDisabled": false,
        "BlockedTags": [],
        "EnableUserPreferenceAccess": true,
        "AccessSchedules": [],
        "BlockUnratedItems": [],
        "EnableRemoteControlOfOtherUsers": false,
        "EnableSharedDeviceControl": true,
        "EnableRemoteAccess": true,
        "EnableLiveTvManagement": false,
        "EnableLiveTvAccess": false,
        "EnableMediaPlayback": true,
        "EnableAudioPlaybackTranscoding": false,
        "EnableVideoPlaybackTranscoding": false,
        "EnablePlaybackRemuxing": true,
        "ForceRemoteSourceTranscoding": false,
        "EnableContentDeletion": false,
        "EnableContentDeletionFromFolders": [],
        "EnableContentDownloading": true,
        "EnableSyncTranscoding": true,
        "EnableMediaConversion": true,
        "EnabledDevices": [],
        "EnableAllDevices": true,
        "EnabledChannels": [],
        "EnableAllChannels": false,
        "EnabledFolders": ["fd92a19bf70941da9b3fd650f2fc1da0"],
        "EnableAllFolders": false,
        "InvalidLoginAttemptCount": 0,
        "LoginAttemptsBeforeLockout": -1,
        "MaxActiveSessions": 0,
        "EnablePublicSharing": true,
        "BlockedMediaFolders": [],
        "BlockedChannels": [],
        "RemoteClientBitrateLimit": 0,
        "AuthenticationProviderId":
            "Jellyfin.Server.Implementations.Users.DefaultAuthenticationProvider",
        "PasswordResetProviderId":
            "Jellyfin.Server.Implementations.Users.DefaultPasswordResetProvider",
        "SyncPlayAccess": "CreateAndJoinGroups"
      }
    };

    app = Alfred(
      logLevel: /* kDebugMode ? */ LogType.info /* : LogType.warn */,
    );
    final tokenRegExp = RegExp(r'token="(.+)"');

    if (authEnabled) {
      app.all(
        '*',
        (HttpRequest req, HttpResponse res) async {
          final path = req.requestedUri.path.toLowerCase();
          /* (req.requestedUri.path == '/api/me' && req.method == 'POST') || */
          /* req.requestedUri.path.startsWith('/img/covers') */
          if (path == '/socket' ||
              path.startsWith('/audio/') ||
              path.startsWith('/videos/') ||
              (path.startsWith('/items/') &&
                  path.endsWith('/images/primary'))) {
            return;
          }

          // TODO Always check auth here, DO NOT USE THE STUPID AUTH CHECKS EVERYWHERE
          try {
            final auth = (req.headers['x-emby-authorization'] ??
                    req.headers['authorization'])
                .toString()
                .toLowerCase();
            final tokenMatch = tokenRegExp.firstMatch(auth);
            // info('auth $auth');
            final token = tokenMatch!.group(1);
            verbose('token "$token"');
          } catch (e) {
            warning('NOTOKEN ${req.requestedUri} ${req.headers}');
          }
        },
      );
    }
    app.all('*', cors(origin: '*'));

    /* app.head(
      '*',
      (req, res) {
        return '';
      },
    ); */

    app.get('/users/public', (req, res) => []);
    app.get('/branding/configuration', (req, res) => <String, String>{});

    // TODO app.post update preferences
    app.get(
        '/displaypreferences/clientsettings',
        (req, res) => {
              "Id": "357e974436cc9dc1fc6476865e62e417",
              "SortBy": "SortName",
              "RememberIndexing": false,
              "PrimaryImageHeight": 250,
              "PrimaryImageWidth": 250,
              "CustomPrefs": {
                "chromecastVersion": "stable",
                "skipForwardLength": "30000",
                "skipBackLength": "10000",
                "enableNextVideoInfoOverlay": "False",
                "tvhome": "",
                "dashboardTheme": ""
              },
              "ScrollDirection": "Horizontal",
              "ShowBackdrop": true,
              "RememberSorting": false,
              "SortOrder": "Ascending",
              "ShowSidebar": false,
              "Client": "vue"
            });

    app.get('/playback/bitratetest', (req, res) async {
      String tmpString = (await getTempDir()).path;
      final file = File(join(tmpString, const Uuid().v4()));
      file.createSync(recursive: true);
      file.writeAsBytesSync(
          Uint8List(int.parse(req.requestedUri.queryParameters['size']!)));

      return file;
    });
/*     final m = {
      "LocalAddress": "http://172.17.0.14:8096",
      "ServerName": "ababababab",
      "Version": "10.7.7",
      "ProductName": "Jellyfin Server",
      "OperatingSystem": "Linux",
      "Id": "abababababababab",
      "StartupWizardCompleted": true
    }; */

/*     app.get('/opds/key/', (req, res) {
      final builder = XmlBuilder();
      builder.processing('xml', 'version="1.0"');
      builder.element('bookshelf', nest: () {
        builder.element('book', nest: () {
          builder.element('title', nest: () {
            builder.attribute('lang', 'en');
            builder.text('Growing a Language');
          });
          builder.element('price', nest: 29.99);
        });
        builder.element('book', nest: () {
          builder.element('title', nest: () {
            builder.attribute('lang', 'en');
            builder.text('Learning XML');
          });
          builder.element('price', nest: 39.95);
        });
        builder.element('price', nest: 132.00);
      });
      final bookshelfXml = builder.buildDocument();
      res.headers.contentType = ContentType('application', 'xml'); */

    /*      return ''''''; */
    /* }); */

    app.get('/system/info/public', (req, res) async {
/*       logger.verbose(req.headers);
      final r = await mySky.skynetClient.httpClient.get(
        req.requestedUri.replace(
          host: '1.1.1.1',
        ),
        // headers: Map.from(req.),
      );
      logger.verbose(r.headers);
      logger.verbose(r.body); */

      return {
        "LocalAddress": "http://127.0.0.1:8096",
        "ServerName": "Vup App",
        "Version": "10.8.9",
        "ProductName": "Jellyfin Server",
        "OperatingSystem": "Linux",
        "Id": serverId,
        "StartupWizardCompleted": true
      };
    });

    app.get('/sessions', (req, res) => []);

    app.get(
        '/system/info',
        (req, res) => {
              "OperatingSystemDisplayName": "Linux",
              "HasPendingRestart": false,
              "IsShuttingDown": false,
              "SupportsLibraryMonitor": true,
              "WebSocketPortNumber": 1234,
              "CompletedInstallations": [],
              "CanSelfRestart": false,
              "CanLaunchWebBrowser": false,
              "ProgramDataPath": "/config",
              "WebPath": "/jellyfin/jellyfin-web",
              "ItemsByNamePath": "/config/metadata",
              "CachePath": "/cache",
              "LogPath": "/config/log",
              "InternalMetadataPath": "/config/metadata",
              "TranscodingTempPath": "/config/transcodes",
              "HasUpdateAvailable": false,
              "EncoderLocation": "SetByArgument",
              "SystemArchitecture": "X64",
              "LocalAddress": "http://127.0.0.1:8096",
              "ServerName": "c1293c2ca6f4",
              "Version": "10.8.9",
              "OperatingSystem": "Linux",
              "Id": serverId,
            });

    dynamic _itemsRequestHandler(HttpRequest req, res,
        [Map<String, String?> m = const {}]) async {
      final queryParameters = <String, String>{};
      for (final key in req.requestedUri.queryParametersAll.keys) {
        queryParameters[key.toLowerCase()] =
            req.requestedUri.queryParametersAll[key]!.join(',');
      }
      for (final e in m.entries) {
        if (e.value != null) {
          queryParameters[e.key] = e.value!;
        }
      }

      // final fields = (queryParameters['fields'])?.split(',') ?? [];

      final searchTerms =
          queryParameters['searchterm']?.toLowerCase().split(' ');

      var includeItemTypesStr =
          queryParameters['includeitemtypes'] ?? queryParameters['mediatypes'];

      final excludeItemTypesStr = queryParameters['excludeitemtypes'];

      final startItemId =
          JellyID.fromHexNullable(queryParameters['startitemid']);

      final List<String> excludeItemTypes = excludeItemTypesStr
              ?.split(',')
              .map((e) => e.startsWith('+') ? e.substring(1) : e)
              .map((e) => e.trim())
              .toList() ??
          const <String>[];

      final List<String> includeItemTypes = includeItemTypesStr
              ?.split(',')
              .map((e) => e.startsWith('+') ? e.substring(1) : e)
              .map((e) => e.trim())
              .toList() ??
          const <String>[];

      verbose('includeItemTypes $includeItemTypes');

      if (includeItemTypes.contains('Video')) {
        includeItemTypes.addAll(['Movie', 'Episode']);
      }

      if (includeItemTypes.contains('CollectionFolder') ||
          queryParameters.isEmpty) {
        return {
          "Items": [
            ...collectionsMap.values,
          ],
          "TotalRecordCount": collectionsMap.length,
          "StartIndex": 0,
        };
      }

      final filter = queryParameters['filter'];

      final filters = queryParameters['filters'];

      List<JellyID> parseIDs(String? ids) {
        if (ids == null) return [];
        if (ids.isEmpty) return [];
        return ids.split(',').map((e) => JellyID.fromHex(e)).toList();
      }

      final ids = parseIDs(queryParameters['ids']);

      JellyID? parentId = JellyID.fromHexNullable(
        queryParameters['parentid'] ?? queryParameters['albumids'],
      );

      var sortBy = queryParameters['sortby']?.split(',').first;

      if (sortBy == 'Latest') {
        parentId = JellyID.hash('latest-$parentId');
        sortBy = 'DateCreated';
      }

      final resume = sortBy == 'Resume' || filters == 'IsResumable';

      if (includeItemTypes.contains('Audio')) {
        includeItemTypes.addAll(['AudioBook']);
      }

      final artistIds = parseIDs(queryParameters['artistids'] ??
          queryParameters['albumartistids'] ??
          queryParameters['contributingartistids']);

      bool isFavorite = queryParameters['isfavorite'] == 'true';
      var recursive = queryParameters['recursive']?.toLowerCase() == 'true';
      if (isFavorite) {
        parentId = JellyID.hash('favorites');
        recursive = false;
      } else if (filters == 'IsFavorite') {
        parentId = JellyID.hash('favorites');
        recursive = false;
      }

      final genreIds = parseIDs(queryParameters['genreids']);
      final genres = queryParameters['genres'];

      int limit = int.parse(queryParameters['limit'] ?? '999999999');
      int startIndex = int.parse(queryParameters['startindex'] ?? '0');

      final items = <Map>[];

      if (parentId != null) {
        if (parentId == serverId) {
          return {
            "Items": [
              ...collectionsMap.values,
            ],
            "TotalRecordCount": collectionsMap.length,
            "StartIndex": 0,
          };
        }
        //logger.verbose('recursive1 $recursive');
        if (recursive) {
          if (folderCollectionIds.contains(parentId)) {
            recursive = false;
          }
        }
        if (recursive) {
          if (recursiveParentToChildMap.containsKey(parentId)) {
            for (final itemId in recursiveParentToChildMap[parentId]!) {
              final item = getItemById(itemId);
              if (item != null) items.add(item);
            }
          } else {
            final stackOverflowProtection = <JellyID>{};
            void process(JellyID parentId) {
              if (stackOverflowProtection.contains(parentId)) {
                warning('stackOverflowProtection triggered');
                return;
              }
              stackOverflowProtection.add(parentId);
              for (final itemId in parentToChildMap[parentId] ?? []) {
                final item = getItemById(itemId);
                if (item != null) {
                  items.add(item);
                  process(itemId);
                }
              }
            }

            process(parentId);
          }
        } else {
          for (final itemId in parentToChildMap[parentId] ?? []) {
            final item = getItemById(itemId);
            if (item != null) items.add(item);
          }
        }

        items.sort(
            (a, b) => (a['IndexNumber'] ?? 0).compareTo(b['IndexNumber'] ?? 0));

        /*     if (sortBy == 'Random') {
          items.shuffle();
        }

        final totalCount = items.length;

        if (items.length > limit) {
          items.removeRange(limit, items.length);
        } */
      } else {
        items.addAll(allItems.values);
      }

      if (includeItemTypes.isNotEmpty) {
        items.removeWhere((element) {
          return !includeItemTypes.contains(element['Type']);
        });
      }

      if (excludeItemTypes.isNotEmpty) {
        items.removeWhere((element) {
          return excludeItemTypes.contains(element['Type']);
        });
      }

      if (filter == 'music' && !recursive) {
        items.clear();
        for (final mid in musicCollectionIds) {
          for (final itemId in parentToChildMap[mid]!) {
            final item = getItemById(itemId);
            if (item != null) items.add(item);
          }
        }

        /*    return {
          "Items": songsMap.values.toList(),
          "TotalRecordCount": songsMap.length,
          "StartIndex": startIndex,
        }; */
      }

      bool match(Iterable<JellyID> l1, Iterable<JellyID> l2) {
        for (final id in l1) {
          if (l2.contains(id)) return true;
        }
        return false;
      }

      if (artistIds.isNotEmpty) {
        items.removeWhere((m) => !match(
            [...(m['ArtistItems'] ?? []), ...(m['AlbumArtists'] ?? [])]
                .map((m) => m["Id"]),
            artistIds));
      }
      if (genreIds.isNotEmpty) {
        // TODO Parse
        items.removeWhere(
          (m) => !match(m['GenreItems'].map((m) => m["Id"]), genreIds),
        );
      }
      if (genres != null) {
        items.removeWhere(
          (m) => !m['GenreItems'].map((m) => m["Name"]).contains(genres),
        );
      }
      /*   if (includeItemTypes == 'MusicAlbum') {
      } else if (includeItemTypes == 'Audio') {
        if (artistIds != null) {
          items.removeWhere((m) => ![...m['ArtistItems'], ...m['AlbumArtists']]
              .map((m) => m["Id"])
              .contains(artistIds));
        }
      } else  */

      if (ids.isNotEmpty) {
        items.removeWhere((element) => !ids.contains(element['Id']));
        /*       return {
          "Items": [
            for (final id in allIds) getItemById(id),
          ],
          "TotalRecordCount": allIds.length,
          "StartIndex": 0,
        }; */
      }
      var sortOrder = queryParameters['sortorder'] ?? 'Ascending';
      if (resume) {
        items.removeWhere((i) => i['UserData']['PlaybackPositionTicks'] == 0);
        // if (!(includeItemTypes ?? []).contains('Video')) {
        final minTicks = tickMultiplier * 60 * 15;
        items.removeWhere((element) =>
            (element['Type'] == 'Audio') && element['RunTimeTicks'] < minTicks);
        // }
        sortBy = 'DatePlayed';
        sortOrder = 'Descending';
        // limit = 1000;
      }
      if (searchTerms != null) {
        items.removeWhere((element) {
          for (final term in searchTerms) {
            if (!element.toString().toLowerCase().contains(term)) {
              return true;
            }
          }
          return false;
        });
        if (includeItemTypes.length == 1 &&
            includeItemTypes.first == 'MusicAlbum') {
          sortBy = 'ChildCount';
          sortOrder = 'Descending';
        }
      }

      final sortModifier = sortOrder == 'Ascending' ? 1 : -1;

      if (sortBy == 'Random') {
        items.shuffle();
      } else if (sortBy == 'PlayCount') {
        // PlayCount&sortOrder=Descending
        items.sort((a, b) => (sortModifier *
            a['UserData']['PlayCount'].compareTo(
              b['UserData']['PlayCount'],
            )) as int);
      } else if (sortBy == 'DateCreated') {
        logger.verbose('latest: sorting by DateCreated');
        // PlayCount&sortOrder=Descending
        items.sort((a, b) => (sortModifier *
            (a['DateCreated'] ?? '0000').compareTo(
              b['DateCreated'] ?? '0000',
            )) as int);
      } else if (sortBy == 'DatePlayed') {
        // PlayCount&sortOrder=Descending
        items.sort((a, b) => (sortModifier *
            (a['UserData']['LastPlayedDate'] ?? '0000').compareTo(
              b['UserData']['LastPlayedDate'] ?? '0000',
            )) as int);
      } else if (sortBy == 'PremiereDate') {
        items.sort((a, b) => (sortModifier *
            (a['PremiereDate'] ?? '0000').compareTo(
              b['PremiereDate'] ?? '0000',
            )) as int);
      } else if (sortBy == 'Name') {
        items.sort((a, b) => (sortModifier *
            (a['Name']).compareTo(
              b['Name'],
            )) as int);
      } else if (sortBy == 'SortName') {
        items.sort((a, b) => (sortModifier *
            (a['SortName'] ?? a['Name']).compareTo(
              b['SortName'] ?? b['Name'],
            )) as int);
      } else if (sortBy == 'CommunityRating') {
        items.sort((a, b) => (sortModifier *
            (a['CommunityRating'] ?? 0.0).compareTo(
              b['CommunityRating'] ?? 0.0,
            )) as int);
      } else if (sortBy == 'ChildCount') {
        items.sort((a, b) => (sortModifier *
            (a['ChildCount'] ?? 0).compareTo(
              b['ChildCount'] ?? 0,
            )) as int);
      } else if (sortBy == 'Runtime') {
        items.sort((a, b) => (sortModifier *
            (a['RunTimeTicks'] ?? 0).compareTo(
              b['RunTimeTicks'] ?? 0,
            )) as int);
      } else if (sortBy == 'ProductionYear') {
        items.sort((a, b) => (sortModifier *
            (a['ProductionYear'] ?? 0).compareTo(
              b['ProductionYear'] ?? 0,
            )) as int);
      }

      if (startItemId != null) {
        int index = 0;
        for (final item in items) {
          if (item['Id'] == startItemId) {
            break;
          }
          index++;
        }
        items.removeRange(0, index);
      }

      // Name, Album, AlbumArtist, Artist
      final totalCount = items.length;
      if (startIndex > 0) {
        items.removeRange(0, startIndex);
      }
      if (items.length > limit) {
        items.removeRange(limit, items.length);
      }

      return {
        "Items": items,
        "TotalRecordCount": totalCount,
        "StartIndex": startIndex,
      };
    }

    // TODO Improve
    app.get('/artists/albumartists', (req, res) {
      return _itemsRequestHandler(
          req, res, {'includeitemtypes': 'MusicArtist'});
      /* return {
        "Items": artistMap.values.toList(),
        "TotalRecordCount": artistMap.length,
        "StartIndex": 0
      }; */
    });
    app.get('/artists', (req, res) {
      return _itemsRequestHandler(
          req, res, {'includeitemtypes': 'MusicArtist'});
    });

    app.get('/genres', (req, res) {
      return _itemsRequestHandler(req, res, {'includeitemtypes': 'MusicGenre'});
    });

    app.get('/plugins', (req, res) {
      return [];
    });

    app.post('/sessions/capabilities/full', (req, res) async {
      return '';
    });

    app.post('/playlists', (req, res) async {
      final data = await req.bodyAsJsonMap;

      final params = <String, String>{};
      for (final key in req.requestedUri.queryParameters.keys) {
        params[key.toLowerCase()] = req.requestedUri.queryParameters[key]!;
      }
      for (final key in data.keys) {
        params[key.toLowerCase()] = data[key]!;
      }

      final id = playlistService.createPlaylist(
        params['mediatype'] ?? 'Audio',
        params['name']!,
      );
      return {"Id": id};
    });

    app.post('/items/:itemId', (req, res) async {
      final item = getItemById(JellyID.fromHex(req.params['itemId']))!;
      final body = await req.bodyAsJsonMap;
      if (item['Type'] == 'Playlist') {
        logger.info('update playlist ${item['Id']} ${body}');

        final params = <String, dynamic>{};
        for (final key in body.keys) {
          params[key.toLowerCase()] = body[key];
        }

        playlistService.updatePlaylist(item['Id'], params);
      }

      return '';
    });

    app.delete('/items/:itemId', (req, res) async {
      final item = getItemById(JellyID.fromHex(req.params['itemId']))!;

      if (item['Type'] == 'Playlist') {
        playlistService.deletePlaylist(item['Id']);
      }

      return '';
    });

    app.post('/users/:userId/playeditems/:itemId', (req, res) async {
      final userId = req.params['userId'];
      final itemId = JellyID.fromHex(req.params['itemId']!);
      /* final datePlayed = req.requestedUri.queryParameters['datePlayed']; */

      activityService.logPlayEvent(
        itemId /* , ts: DateTime.parse(datePlayed!) */,
        meta: {},
      );
      getItemById(itemId);

      return '';
    });

    // TODO Delete endpoint
    /*    app.post('/users/:userId/playeditems/:itemId', (req, res) async {
      final userId = req.params['userId'];
      final itemId = req.params['itemId']!;
      /* final datePlayed = req.requestedUri.queryParameters['datePlayed']; */

      activityService
          .logPlayEvent(itemId /* , ts: DateTime.parse(datePlayed!) */);
      getItemById(itemId);

      return '';
    }); */

    app.post('/users/:userId/favoriteitems/:itemId', (req, res) async {
      final userId = req.params['userId'];
      final itemId = JellyID.fromHex(req.params['itemId']!);

      /* activityService
          .logPlayEvent(itemId /* , ts: DateTime.parse(datePlayed!) */); */

      playlistService.addItemsToPlaylist(JellyID.hash('favorites'), [itemId]);

      return '';
    });

    app.delete('/users/:userId/favoriteitems/:itemId', (req, res) async {
      final userId = req.params['userId'];
      final itemId = JellyID.fromHex(req.params['itemId']!);

      playlistService
          .removeItemsFromPlaylist(JellyID.hash('favorites'), [itemId]);

      /* activityService
          .logPlayEvent(itemId /* , ts: DateTime.parse(datePlayed!) */); */

      return '';
    });

    void processPlayingRequest({
      required JellyID itemId,
      required int positionMillis,
      required bool isPaused,
    }) {
      try {
        final item = getItemById(itemId);
        // logger.verbose(json.encode(item));
        final mediaType = item!['MediaType'];

        listenBrainzService.onProgress(
          itemId: itemId,
          item: item,
          positionMillis: positionMillis,
          isPaused: isPaused,
        );

        final thumbnailKey =
            allCoverKeysMap[itemId] ?? allCoverKeysMap['$itemId/Primary'];

        if (mediaType == 'Audio') {
          richStatusService.setStatus(
            title: item['Name']!,
            artists: item['Artists'] ?? [],
            album: item['Album'],
            date: item['ProductionYear'] == null
                ? null
                : item['ProductionYear'].toString(),
            duration: (item['RunTimeTicks']! / tickMultiplier * 1000).round(),
            progress: positionMillis,
            thumbnailKey: thumbnailKey,
            isPaused: isPaused,
            type: RichStatusType.music,
          );
        } else if (mediaType == 'Video') {
          richStatusService.setStatus(
            title: item['Name']!,
            indexNumber: item['IndexNumber'],
            // artists: item['Artists'] ?? [],
            // album: item['Album'],
            seasonName: item['SeasonName'],
            seriesName: item['SeriesName'],
            duration: (item['RunTimeTicks']! / tickMultiplier * 1000).round(),
            progress: positionMillis,
            thumbnailKey: thumbnailKey,
            isPaused: isPaused,
            type: RichStatusType.video,
          );
        }
      } catch (e, st) {
        logger.verbose(e);
        logger.verbose(st);
      }
    }

    app.post('/sessions/playing/progress', (req, res) async {
      final body = await req.bodyAsJsonMap;

      final itemId = JellyID.fromHex(body['ItemId']!);
      final positionTicks = body['PositionTicks'] ?? 0;
      final positionMillis = (positionTicks / tickMultiplier * 1000).round();

      if (!ignoreProgressEventsForIds.contains(itemId)) {
        activityService.setPlayPosition(
          itemId,
          positionMillis,
        );
        // getItemById(itemId);
      } else {
        verbose('ignoring progress event');
      }
      processPlayingRequest(
        itemId: itemId,
        positionMillis: positionMillis,
        isPaused: body['IsPaused'] ?? false,
      );

      res.statusCode = HttpStatus.noContent;
      return '';
    });

    app.post('/sessions/playing', (req, res) async {
      final body = await req.bodyAsJsonMap;

      final itemId = JellyID.fromHex(body['ItemId']!);

      final positionTicks = body['PositionTicks'] ?? 0;
      final positionMillis = (positionTicks / tickMultiplier * 1000).round();

      if (!ignoreProgressEventsForIds.contains(itemId)) {
        activityService.setPlayPosition(itemId, positionMillis);
        getItemById(itemId);
      } else {
        verbose('ignoring progress event');
      }
      processPlayingRequest(
        itemId: itemId,
        positionMillis: positionMillis,
        isPaused: body['IsPaused'] ?? false,
      );

      res.statusCode = HttpStatus.noContent;
      return '';
    });

    app.post('/sessions/playing/stopped', (req, res) async {
      // TODO Store position
      final body = await req.bodyAsJsonMap;
      final itemId = JellyID.fromHex(body['ItemId']!);

      final positionTicks = body['PositionTicks'] ?? 0;
      final item = getItemById(itemId);

      final ticks = item!['RunTimeTicks'];

      if (!ignoreProgressEventsForIds.contains(itemId)) {
        activityService.setPlayPosition(
            itemId, (positionTicks / tickMultiplier * 1000).round());
      } else {
        verbose('ignoring progress event');
      }

      if ((ticks - positionTicks) < 30 * tickMultiplier) {
        activityService.logPlayEvent(
          itemId,
          meta: item,
        );
      }
      getItemById(itemId);

      res.statusCode = HttpStatus.noContent;
      return '';
    });

    app.get('/socket', (req, res) {
      if (authEnabled) {
        if (req.requestedUri.queryParameters['api_key'] != serverToken) {
          res.statusCode = HttpStatus.unauthorized;
          return '';
        }
      }

      return WebSocketSession(
        onOpen: (ws) {},
        onClose: (ws) {},
        onMessage: (ws, dynamic data) async {},
      );
    });

    app.get(
      '/persons',
      (req, res) => {
        "Items": [],
        "TotalRecordCount": 0,
        "StartIndex": 0,
      },
    );

    app.get(
      '/shows/:showId/seasons',
      (req, res) => _itemsRequestHandler(
        req,
        res,
        {
          'parentid': req.params['showId']!,
          'includeitemtypes': 'Season',
        },
      ),
    );
    app.get(
      '/shows/:showId/episodes',
      (req, res) => _itemsRequestHandler(
        req,
        res,
        {
          'parentid': req.requestedUri.queryParameters['seasonId'] ??
              req.params['showId'],
          'startitemid': req.requestedUri.queryParameters['startItemId'],
          'includeitemtypes': 'Episode',
          'recursive': 'true',
          'sortby': 'SortName',
        },
      ),
    );

    app.get('/artists/:artistId/similar', (req, res) {
      return {"Items": [], "TotalRecordCount": 0, "StartIndex": 0};
    });

    app.get('/items/:itemId/similar', (req, res) {
      return {"Items": [], "TotalRecordCount": 0, "StartIndex": 0};
    });

    app.get('/items/:itemId/thememedia', (req, res) {
      return {
        "ThemeVideosResult": {
          "OwnerId": "00000000000000000000000000000000",
          "Items": [],
          "TotalRecordCount": 0,
          "StartIndex": 0
        },
        "ThemeSongsResult": {
          "OwnerId": "00000000000000000000000000000000",
          "Items": [],
          "TotalRecordCount": 0,
          "StartIndex": 0
        },
        "SoundtrackSongsResult": {
          "OwnerId": "00000000000000000000000000000000",
          "Items": [],
          "TotalRecordCount": 0,
          "StartIndex": 0
        }
      };
    });

    app.post('/users/authenticatebyname', (req, res) async {
      final data = await req.bodyAsJsonMap;

      if ((data['Username'] ?? data['username']) == username &&
          (data['Pw'] ?? data['PW'] ?? data['pw']) == password) {
        info('auth success');
        return {
          "User": currentUserData,
          "SessionInfo": {
            "PlayState": {
              "CanSeek": false,
              "IsPaused": false,
              "IsMuted": false,
              "RepeatMode": "RepeatNone"
            },
            "AdditionalUsers": [],
            "Capabilities": {
              "PlayableMediaTypes": ["Audio", "Video"],
              "SupportedCommands": [
                "MoveUp",
                "MoveDown",
                "MoveLeft",
                "MoveRight",
                "PageUp",
                "PageDown",
                "PreviousLetter",
                "NextLetter",
                "ToggleOsd",
                "ToggleContextMenu",
                "Select",
                "Back",
                "SendKey",
                "SendString",
                "GoHome",
                "GoToSettings",
                "VolumeUp",
                "VolumeDown",
                "Mute",
                "Unmute",
                "ToggleMute",
                "SetVolume",
                "SetAudioStreamIndex",
                "SetSubtitleStreamIndex",
                "DisplayContent",
                "GoToSearch",
                "DisplayMessage",
                "SetRepeatMode",
                "SetShuffleQueue",
                "ChannelUp",
                "ChannelDown",
                "PlayMediaSource",
                "PlayTrailers"
              ],
              "SupportsMediaControl": true,
              "SupportsContentUploading": false,
              "SupportsPersistentIdentifier": false,
              "SupportsSync": false
            },
            "RemoteEndPoint": req.requestedUri.host,
            "PlayableMediaTypes": ["Audio", "Video"],
            "Id": "todo_session_id",
            "UserId": "074a223ae7744d31856c862157b1e502",
            "UserName": username,
            "Client": "Jellyfin Web",
            "LastActivityDate": "2021-12-18T13:52:01.3996182Z",
            "LastPlaybackCheckIn": "0001-01-01T00:00:00.0000000Z",
            "DeviceName": "Chrome",
            "DeviceId": "todo_random_deviceid",
            "ApplicationVersion": "10.8.9",
            "IsActive": true,
            "SupportsMediaControl": false,
            "SupportsRemoteControl": false,
            "HasCustomDeviceName": false,
            "ServerId": serverId,
            "SupportedCommands": [
              "MoveUp",
              "MoveDown",
              "MoveLeft",
              "MoveRight",
              "PageUp",
              "PageDown",
              "PreviousLetter",
              "NextLetter",
              "ToggleOsd",
              "ToggleContextMenu",
              "Select",
              "Back",
              "SendKey",
              "SendString",
              "GoHome",
              "GoToSettings",
              "VolumeUp",
              "VolumeDown",
              "Mute",
              "Unmute",
              "ToggleMute",
              "SetVolume",
              "SetAudioStreamIndex",
              "SetSubtitleStreamIndex",
              "DisplayContent",
              "GoToSearch",
              "DisplayMessage",
              "SetRepeatMode",
              "SetShuffleQueue",
              "ChannelUp",
              "ChannelDown",
              "PlayMediaSource",
              "PlayTrailers"
            ]
          },
          "AccessToken": dataBox.get('jellyfin_server_token'),
          "ServerId": serverId,
        };
        /* return {
          'token': dataBox.get('koel_server_token'),
        }; */
      } else {
        info('auth failed');
        res.statusCode = 401;
        await res.close();
      }
    });

    app.get(
      '/system/endpoint',
      (req, res) => {
        "IsLocal": false,
        "IsInNetwork": true,
      },
    );

    app.get(
      '/livetv/programs/recommended',
      (req, res) => {"Items": [], "TotalRecordCount": 0, "StartIndex": 0},
    );
    app.get(
      '/livetv/programs',
      (req, res) => {"Items": [], "TotalRecordCount": 0, "StartIndex": 0},
    );

    app.get(
      '/musicgenres',
      (req, res) =>
          _itemsRequestHandler(req, res, {'includeitemtypes': 'MusicGenre'}),
    );

    app.post('/items/:itemId/playbackinfo', (req, res) async {
      final data = await req.bodyAsJsonMap;

      final itemId = JellyID.fromHex(req.params['itemId']);
      final mediaItem = getItemById(itemId);
      return {
        'MediaSources': mediaItem!['MediaSources'],
        'PlaySessionId': 'todo_playsessionid',
      };
    });

    /*    app.post('/playlists', (req, res) async {
      final data = await req.bodyAsJsonMap;
    }); */

    app.get('/audio/:hash/:filename', (req, res) async {
      if (authEnabled) {
        if (req.requestedUri.queryParameters['api_key'] != serverToken) {
          res.statusCode = HttpStatus.unauthorized;
          return '';
        }
      }
      final hash = JellyID.fromHex(req.params['hash']);

      final file = mediaFilesByHash[hash]!;

      res.headers.set(
        'Cache-Control',
        'public, max-age=31536000',
      );

      final localFile = storageService.getLocalFile(file);
      if (localFile != null) return localFile;

      if (file.file.encryptedCID?.encryptionAlgorithm ==
          encryptionAlgorithmXChaCha20Poly1305) {
        final duration = file.ext?['audio']['duration']; // in seconds
        info('duration $duration');

        await handleChunkedFile(
          req,
          res,
          file,
          file.file.cid.size!,
          // storeLocalFile: false && duration < 3600,
        );
        return null;
      } else if (file.file.encryptedCID == null) {
        return await handlePlaintextFile(req, res, file);
      } else {
        throw 'File can\'t be streamed';
      }
    });

    app.head('/audio/:hash/:filename', (req, res) async {
      if (authEnabled) {
        if (req.requestedUri.queryParameters['api_key'] != serverToken) {
          res.statusCode = HttpStatus.unauthorized;
          return '';
        }
      }
      final hash = JellyID.fromHex(req.params['hash']);

      final file = mediaFilesByHash[hash]!;

      res.headers.contentType =
          ContentType.parse(file.mimeType ?? 'application/octet-stream');
      res.headers.contentLength = file.file.cid.size ?? 0;
    });

    // DateTime lastAudioFetch = DateTime.now();"/Subtitles/$hash/Stream.vtt?api_key=none",
    app.get(
        '/videos/:videoId/:hash/subtitles/:id/:anotherid/:filename' /* '/subtitles/:hash/:filename' */,
        (req, res) async {
      if (authEnabled) {
        if (req.requestedUri.queryParameters['api_key'] != serverToken) {
          res.statusCode = HttpStatus.unauthorized;
          return '';
        }
      }
      final hash = JellyID.fromHex(req.params['hash']);
      final filename = req.params['filename'] ?? '';

      verbose('fetching subtitle ${subtitleFilesMap[hash]}');

      throw UnimplementedError();

      /*    final fileData = subtitleFilesMap[hash]!;
      final df = FileReference(
        name: 'stream.vtt',
        created: 0,
        modified: 0,
        version: 0,
        file: FileVersion.fromJson(fileData.cast<String, dynamic>()),
      );

      var localFile = storageService.getLocalFile(df);
      if (localFile == null) {
        final path = await storageService.downloadAndDecryptFile(
          fileData: df.file,
          name: 'stream.vtt',
        );
        localFile = File(path);
      }
      if (filename.endsWith('vtt')) {
        return localFile;
      }

      verbose(localFile.path);

      final subs = FileSubtitle(localFile);

      final subCtrl = SubtitleController(
        provider: subs,
      );

      await subCtrl.initial();

      return {
        "TrackEvents": [
          for (final s in subCtrl.subtitles)
            {
              "Id": s.index.toString(),
              "Text": s.data,
              "StartPositionTicks":
                  (s.start.inMilliseconds * tickMultiplier / 1000).round(),
              "EndPositionTicks":
                  (s.end.inMilliseconds * tickMultiplier / 1000).round()
            },
        ]
      }; */

      /*  if (file.file.encryptionType == 'libsodium_secretbox') {
        await handleChunkedFile(
          req,
          res,
          file,
          file.file.size,
          storeLocalFile: false,
        );
        return null;
      } */
    });

    app.get('/videos/:hash/:filename', (req, res) async {
      if (authEnabled) {
        if (req.requestedUri.queryParameters['api_key'] != serverToken) {
          res.statusCode = HttpStatus.unauthorized;
          return '';
        }
      }
      final hash = JellyID.fromHex(req.params['hash']);

      final file = mediaFilesByHash[hash];
      if (file == null) {
        /*  final stream = mediaStreamsByHash[hash]!;
        final p = await Process.start(
          ytDlPath,
          [
            '-o',
            '-',
            stream['url'],
          ],
        );
 */
        res.redirect(
          Uri.parse(
            '/chunked/index-dvr.m3u8',
          ),
          status: HttpStatus.temporaryRedirect,
        );
        return null;
        // return p.stdout;
      }

      res.headers.set(
        'Cache-Control',
        'public, max-age=31536000',
      );

      //
      /*      final uri = Uri.parse(
          '');
      res.redirect(
        uri,
        status: HttpStatus.temporaryRedirect,
      );
      return null; */

      final localFile = storageService.getLocalFile(file);
      if (localFile != null) return localFile;

      if (file.file.encryptedCID?.encryptionAlgorithm ==
          encryptionAlgorithmXChaCha20Poly1305) {
        await handleChunkedFile(
          req,
          res,
          file,
          file.file.cid.size!,
        );
        return null;
      } else if (file.file.encryptedCID == null) {
        return await handlePlaintextFile(req, res, file);
      } else {
        throw 'File can\'t be streamed';
      }
    });

    app.get(
      '/items/:itemId/images/:type',
      (req, res) async {
        final imgTag = req.requestedUri.queryParameters['tag'] ??
            req.requestedUri.queryParameters['imgTag'] ??
            '';
        if (imgTag.startsWith('external-')) {
          final url = utf8.decode(base64Url.decode(imgTag.substring(9)));
          res.redirect(
            Uri.parse(url),
            status: HttpStatus.temporaryRedirect,
          );
          return null;
        }
        final itemId = JellyID.fromHex(req.params['itemId']);
        final type = req.params['type'];
        res.setContentTypeFromExtension('webp');

        res.headers.set(
          'Cache-Control',
          'public, max-age=3600',
        );

        final coverKey =
            allCoverKeysMap[itemId] ?? allCoverKeysMap[itemId.subhash(type)];
        if (coverKey == null) {
          warning('thumbnail for $itemId/$type not found');
          throw '';
        }

        final r = await storageService.dac.loadThumbnail(
          coverKey,
        );
        // logger.verbose('thumbnail size ${filesize(r?.length)}');
        return r;
      },
    );
    app.get(
      '/items/:itemId/images/:type/:index',
      (req, res) async {
        final itemId = JellyID.fromHex(req.params['itemId']);
        final type = req.params['type'];
        res.setContentTypeFromExtension('webp');

        res.headers.set(
          'Cache-Control',
          'public, max-age=3600',
        );

        final coverKey =
            allCoverKeysMap[itemId] ?? allCoverKeysMap[itemId.subhash(type)];
        if (coverKey == null) {
          warning('thumbnail for $itemId/$type not found');
          throw '';
        }

        final r = await storageService.dac.loadThumbnail(
          coverKey,
        );
        return r;
      },
    );

    app.get('/branding/css', (req, res) => '');

    app.get('/users/:userId', (req, res) async {
      return currentUserData;
    });

    app.post('/users/:userId/configuration', (req, res) async {
      final body = await req.bodyAsJsonMap;
      currentUserData['Configuration'] = body;
      dataBox.put('jellyfin_user_configuration', body);
    });

    app.post('/displaypreferences/usersettings', (req, res) => '');

    app.get(
      '/displaypreferences/usersettings',
      (req, res) => {
        "Id": serverId,
        "SortBy": "SortName",
        "RememberIndexing": false,
        "PrimaryImageHeight": 250,
        "PrimaryImageWidth": 250,
        "CustomPrefs": {
          "chromecastVersion": "stable",
          "skipForwardLength": "30000",
          "skipBackLength": "10000",
          "enableNextVideoInfoOverlay": "False",
          "tvhome": "",
          "dashboardTheme": "",
        },
        "ScrollDirection": "Horizontal",
        "ShowBackdrop": true,
        "RememberSorting": false,
        "SortOrder": "Ascending",
        "ShowSidebar": false,
        "Client": "emby"
      },
    );

    app.get('/users/:userId/views', (req, res) async {
      return {
        "Items": collectionsMap.values.toList(),
        "TotalRecordCount": collectionsMap.length,
        "StartIndex": 0
      };
    });

    app.get(
      '/users/:userId/items',
      _itemsRequestHandler,
    );

    app.get(
      '/playlists/:playlistId/items',
      (req, res) => _itemsRequestHandler(
        req,
        res,
        {
          'parentid': req.params['playlistId']!,
          'includeitemtypes': 'Audio',
        },
      ),
    );
    app.post('/playlists/:playlistId/items', (req, res) {
      final queryParameters = <String, String>{};
      for (final key in req.requestedUri.queryParameters.keys) {
        queryParameters[key.toLowerCase()] =
            req.requestedUri.queryParameters[key]!;
      }
      final ids = queryParameters['ids']!
          .split(',')
          .map((e) => JellyID.fromHex(e))
          .toList();
      playlistService.addItemsToPlaylist(req.params['playlistId']!, ids);
      return '';
    });

    app.get(
      '/users/:userId/items/resume',
      (req, res) => _itemsRequestHandler(
        req,
        res,
        {
          'sortby': 'Resume',
          /*  'parentid': req.params['playlistId']!,
          'includeitemtypes': 'Audio', */
        },
      ),
      // _itemsRequestHandler,
    );

    app.get(
        '/shows/nextup',
        (req, res) => {
              "Items": [],
              "TotalRecordCount": 0,
              "StartIndex": 0
            } /*  _itemsRequestHandler(
        req,
        res,
        { */
        // 'sortby': 'Resume',
        /*  'parentid': req.params['playlistId']!,
          'includeitemtypes': 'Audio', */
        /* },
      ), */
        // _itemsRequestHandler,
        );

    app.get(
      '/users/:userId/items/latest',
      (req, res) => _itemsRequestHandler(
        req,
        res,
        {
          'sortby': 'Latest',
          'sortorder': 'Descending',
        },
      ),
    );

    app.get(
      '/items',
      _itemsRequestHandler,
    );

    app.get(
      '/users/:userId/items/:itemId',
      (req, res) async {
        final itemId = JellyID.fromHex(req.params['itemId']);
        // final queryParameters = req.requestedUri.queryParameters;
        // final fields = queryParameters['fields']?.split(',') ?? [];

        final item = getItemById(itemId);

        if (item == null) {
          error('item $itemId not found');
          res.statusCode = 404;
          return '';
        }

        return item;
      },
    );

    app.get(
      '/users/:userId/items/:itemId/intros',
      (req, res) async {
        return {"Items": [], "TotalRecordCount": 0, "StartIndex": 0};
      },
    );
    if (jellyfinWebDir != null) {
      app.get('*', (req, res) {
        final host = req.headers.value('host') ?? req.requestedUri.host;
        if (host.startsWith('vue.')) {
          return jellyfinVueDir;
        } else if (host.startsWith('feishin.')) {
          return feishinWebDir;
          /* const webAppFileExtensions = [
            'js',
            'ttf',
            'css',
            'svg',
            'txt',
            'png',
            'html'
          ];
          if (webAppFileExtensions.contains(
            req.requestedUri.path.split('.').last,
          )) {
            return feishinWebDir;
          } else {
            return File(join(feishinWebDir!.path, 'index.html'));
          } */
        } else {
          return jellyfinWebDir;
        }
        // return jellyfinVueDir;
      });
    }

    const vuePort = 8099;

    /* app.get('/vue', (req, res) {
      return res.redirect(
        req.requestedUri.replace(
          port: vuePort,
          path: '/',
        ),
        status: HttpStatus.temporaryRedirect,
      );
    }); */

    app.get('/statistics', (req, res) {
      res.setContentTypeFromExtension('html');
      return utf8.encode(generateStatisticsPage(allItems));
    });

    // app.printRoutes();
    // ! localhost:8096 (API and web client)

    // ! vue.localhost:8096 (vue-jellyfin client)
    // ! feishin.localhost:8096 (feishin client)

    app.listen(port, bindIp);

    verbose('[timing] ${DateTime.now()} done');

    info('Jellyfin server is running at $bindIp:$port');

    // vueWebApp!.listen(vuePort, '0.0.0.0');

    info('Jellyfin-Vue server is running at 0.0.0.0:$vuePort');
    isStarting = false;
  }

  String convertToSortName(String s) {
    return s.toLowerCase();
  }
}
