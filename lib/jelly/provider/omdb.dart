import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:vup/jelly/id_hash.dart';
import 'package:vup/service/jellyfin_server.dart';
import 'base.dart';

class OMDbMetadataProvider extends JellyMetadataProvider {
  final client = http.Client();

  final String providerId = 'OMDb';
  final int providerVersion = 0;

  final supportedTypes = ['Movie'];

  final bool supportsSearch = true;

  final apiKey = 'd484ef32';

  @override
  Future<List<SearchResult>> search(String type, String query) async {
    final res = await client.get(
      Uri.https('www.omdbapi.com', '/', {
        's': query.trim(),
        'apikey': apiKey,
        'type': 'movie',
      }),
    );

    final data = json.decode(res.body);

    final results = <SearchResult>[];

    for (final item in data['Search'] ?? []) {
      results.add(SearchResult(
        providerId: providerId,
        id: item['imdbID'].toString(),
        type: 'Movie',
        title: item['Title'],
        subtitle: '${item['Year']}',

        // item.toString(),
        imageUrl: item['Poster'] == 'N/A' ? null : item['Poster'],
      ));
    }
    return results;
  }

  Future<Map> fetchData(String id) async {
    final res = await client.get(
      Uri.https('www.omdbapi.com', '/', {
        'i': id,
        'apikey': apiKey,
        'plot': 'full',
      }),
    );
    final data = json.decode(res.body);
    final posterRes = await client.head(
      Uri.parse(
        'https://img.omdbapi.com/?i=${data['imdbID'].toString()}&&apikey=$apiKey',
      ),
    );
    if (posterRes.statusCode == 404) {
      data['NO_POSTER_AVAILABLE'] = true;
    }

    return data;
  }

  List<ImageFile> extractImageFiles(Map data) {
    if (data['NO_POSTER_AVAILABLE'] != null) {
      data.remove('NO_POSTER_AVAILABLE');

      return [
        ImageFile(
          url: data['Poster'] == 'N/A' ? null : data['Poster'],
          name: 'poster.jpg',
        ),
      ];
    }
    return [
      // if (data['Poster'] != 'N/A')
      ImageFile(
        url:
            'https://img.omdbapi.com/?i=${data['imdbID'].toString()}&h=3000&apikey=$apiKey',
        name: 'poster.jpg',
      ),
      /* ImageFile(
        url: data['Poster'],
        name: 'poster.${data['Poster'].split('.').last}',
      ), */
    ];
  }

  // Media field
  Map generateJellyMetadata(String type, String id, Map data) {
    final itemId = calculateIdHash(utf8.encode('${type}-Imdb-${id}'));

    final items = [];

    final providerIds = {
      providerId: id,
      'Imdb': id,
    };

    final item = {
      'Id': itemId,
      "Type": "Movie",
      'Name': data['Title'],
      "Overview": data['Plot'],
      "CommunityRating": double.tryParse(data['imdbRating'] ?? '') ?? 0.0,
      "ExternalUrls": [
        {
          "Name": 'IMDb',
          "Url": 'https://www.imdb.com/title/${id}/',
        },
        {
          "Name": 'Trakt',
          "Url": 'https://trakt.tv/movies/$id',
        },
      ],
      "ProviderIds": providerIds,
    };

    if (data['Released'] != null) {
      final dt = DateFormat('dd MMM yyyy').parse(data['Released']);

      item['PremiereDate'] = dt.toIso8601String();
      item['ProductionYear'] = dt.year;
    }

    item['People'] = [];
    for (final p in data['Actors']?.split(',') ?? []) {
      final name = p.trim();
      final person = {
        "Name": name,
        "Id": calculateIdHash(
          utf8.encode(
            'Actor-${providerId}-${name}',
          ),
        ),
        // "Role": p['character']['name'],
        "Type": "Actor",
        // "PrimaryImageTag":
        /*    "ProviderIds": {
          providerId: id,
        }, */
      };
      items.add(person);
      item['People'].add(person);
    }

    item['Genres'] = [];
    item['GenreItems'] = [];

    for (var genre in data['Genre']?.split(',') ?? []) {
      genre = genre.trim();

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

    return {
      'items': items,
      'item': item,
    };
  }
}
