import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vup/jelly/id_hash.dart';
import 'package:vup/service/jellyfin_server.dart';
import 'base.dart';

class TVmazeMetadataProvider extends JellyMetadataProvider {
  final client = http.Client();

  final String providerId = 'TVmaze';
  final int providerVersion = 0;

  final supportedTypes = ['Series'];

  final bool supportsSearch = true;

  @override
  Future<List<SearchResult>> search(String type, String query) async {
    final res = await client.get(
      Uri.https('api.tvmaze.com', '/search/shows', {
        'q': query,
      }),
    );

    final data = json.decode(res.body);

    final results = <SearchResult>[];

    for (final item in data) {
      final show = item['show'];
      results.add(SearchResult(
        providerId: providerId,
        id: show['id'].toString(),
        type: 'Series',
        title: show['name'],
        subtitle:
            '${show['type']}, ${show['status']}\n${show['genres'].join(', ')}\n${show['premiered']} to ${show['ended']}\n${show['language']}\nRating: ${show['rating']['average']}',

        // item.toString(),
        imageUrl: show?['image']?['medium'],
      ));
    }
    return results;
  }

  Future<Map> fetchData(String id) async {
    final res = await client.get(
      Uri.parse(
        'https://api.tvmaze.com/shows/$id?embed[]=episodes&embed[]=cast&embed[]=seasons&embed[]=crew&embed[]=akas&embed[]=images',
      ),
    );
    final data = json.decode(res.body);

    return data;
  }

  List<ImageFile> extractImageFiles(Map data) {
    final images = data['_embedded']['images'];
    final imageFiles = <String, ImageFile>{};
    for (final image in images) {
      final type = {
        'poster': 'poster',
        'banner': 'banner',
        'background': 'backdrop',
        'typography': 'logo',
      }[image['type']];
      if (type != null) {
        if (!imageFiles.containsKey(type)) {
          final url = image['resolutions']['original']['url'];
          imageFiles[type] = ImageFile(
            url: url,
            name: '$type.${url.split('.').last}',
          );
        }
      }
    }
    return imageFiles.values.toList();
  }

  // Media field
  Map generateJellyMetadata(String type, String id, Map data) {
    final itemId = calculateIdHash(utf8.encode('${type}-${providerId}-${id}'));

    final items = [];

    final providerIds = {
      providerId: id,
    };

    if (data['externals']['imdb'] != null) {
      providerIds['Imdb'] = data['externals']['imdb'].toString();
    }
    if (data['externals']['thetvdb'] != null) {
      providerIds['Tvdb'] = data['externals']['thetvdb'].toString();
    }

    final item = {
      'Id': itemId,
      "Type": "Series",
      "Overview": data['summary']
          ?.replaceAll('<br>', '\n')
          ?.replaceAll('<p>', '')
          ?.replaceAll('</p>', '')
          ?.trim(),
      "CommunityRating": data['rating']['average'],
      "ExternalUrls": [
        {
          "Name": "TVmaze",
          "Url": data['url'],
        },
        if (data['officialSite'] != null)
          {
            "Name": 'Official Site',
            "Url": data['officialSite'],
          },
        if (data['externals']['imdb'] != null)
          {
            "Name": 'IMDb',
            "Url": 'https://www.imdb.com/title/${data['externals']['imdb']}/',
          },
        if (data['externals']['thetvdb'] != null)
          {
            "Name": 'TheTVDB',
            "Url":
                'https://www.thetvdb.com/?id=${data['externals']['thetvdb']}&tab=series',
          },
      ],
      'Name': data['name'],
      "ProviderIds": providerIds,
    };

    if (data['premiered'] != null) {
      final dt = DateTime.parse(data['premiered']);

      item['PremiereDate'] = dt.toIso8601String();
      item['ProductionYear'] = dt.year;
    }

    if (data['ended'] != null) {
      final dt = DateTime.parse(data['ended']);

      item['EndDate'] = dt.toIso8601String();
    }

    item['Studios'] = [];

    item['People'] = [];
    for (final p in data['_embedded']['cast'] ?? []) {
      final person = {
        "Name": p['person']['name'],
        "Id": calculateIdHash(
          utf8.encode(
            'Actor-${providerId}-${p['person']['id']}',
          ),
        ),
        "Role": p['character']['name'],
        "Type": "Actor",
        "PrimaryImageTag": "external-${base64Url.encode(
          utf8.encode(
            p['person']['image']['medium'],
          ),
        )}",
        "ProviderIds": {
          providerId: id,
        },
      };
      items.add(person);
      item['People'].add(person);
    }

    item['Genres'] = [];
    item['GenreItems'] = [];

    for (final genre in data['genres'] ?? []) {
      item['Genres'].add(genre);

      final genreId = calculateIdHash(utf8.encode('genre_' + genre)).toString();

      final genreItem = {
        "Name": genre,
        "Id": genreId,
        "ChannelId": null,
        "Type": "Genre",
        "PrimaryImageAspectRatio": 1,
        "ImageTags": {},
        "BackdropImageTags": [],
        "ImageBlurHashes": {},
        "LocationType": "Remote"
      };
      items.add(genreItem);

      item['GenreItems'].add(genreItem);
    }

    if (data['schedule'] != null) {
      item['AirTime'] = data['schedule']['time'];
      item['AirDays'] = data['schedule']['days'];
    }

    if (data['status'] == "Running") {
      item['Status'] = 'Continuing';
    } else {
      item['Status'] = 'Ended';
    }

    return {
      'items': items,
      'item': item,
    };
  }
}
