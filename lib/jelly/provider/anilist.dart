import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:vup/service/jellyfin_server.dart';

import 'base.dart';

// Inspired by https://github.com/jellyfin/jellyfin-plugin-anilist

class AnilistMetadataProvider extends JellyMetadataProvider {
  final client = http.Client();

  final supportedTypes = ['Series', 'Movie'];

  final bool supportsSearch = true;

  Future<List<SearchResult>> search(String type, String query) async {
    final res = await client.post(
      Uri.parse('https://graphql.anilist.co/'),
      body: json.encode(
        {
          'query': searchQuery,
          'variables': {
            "search": query,
          },
        },
      ),
      headers: {
        'content-type': 'application/json',
      },
    );
    final data = json.decode(res.body);

    final results = [
      for (final item in data['data']?['Page']?['media'] ?? [])
        SearchResult(
          providerId: providerId,
          id: item['id'].toString(),
          type: {
                'TV': 'Series',
                'OVA': 'Series',
                'ONA': 'Series',
                'SPECIAL': 'Series',
                'MOVIE': 'Movie',
                'TV_SHORT': 'Series', // TODO check
                'MUSIC': 'Audio' // TODO check
              }[item['format']] ??
              'Series',
          title: item['title']['english'] == null
              ? item['title']['romaji'].toString()
              : '${item['title']['english']} (${item['title']['romaji']})',
          subtitle:
              '${item['format']}, ${item['status']}\n${item['genres'].join(', ')}\n${formatDate(item['startDate'])} to ${formatDate(item['endDate'])}\n${item['episodes']} episodes\nScore: ${item['averageScore']}\nSource: ${item['source']}',

          // item.toString(),
          imageUrl: item['coverImage']?['medium'],
        )
    ];
    results.removeWhere((element) => element.type != type);

    return results;
  }

  String formatDate(Map date) {
    return '${date['year']}-${date['month']}-${date['day']}';
  }

  // This is stored in the JSON file
  Future<Map> fetchData(String id) async {
    final res = await client.post(
      Uri.parse('https://graphql.anilist.co/'),
      body: json.encode(
        {
          'query': detailsQuery,
          'variables': {
            "id": int.parse(id),
          },
        },
      ),
      headers: {
        'content-type': 'application/json',
      },
    );
    final data = json.decode(res.body);

    return data['data']['Media'];
  }

  List<ImageFile> extractImageFiles(Map data) {
    return [
      ImageFile(
        url: data['coverImage']['extraLarge'],
        name: 'poster.${data['coverImage']['extraLarge'].split('.').last}',
      ),
      ImageFile(
        url: data['bannerImage'],
        name: 'banner.${data['bannerImage'].split('.').last}',
      ),
    ];
  }

  // Media field
  Map generateJellyMetadata(String type, String id, Map data) {
    final itemId = createIdHash(utf8.encode('${type}-${providerId}-${id}'));
    final items = [];
    final item = {
      'Id': itemId,
      "Type": "Series",
      "Overview": data['description']?.replaceAll('<br>', '\n'),
      "CommunityRating": data['averageScore'] / 10,
      "ExternalUrls": [
        {
          "Name": "AniList",
          "Url": "https://anilist.co/anime/$id/",
        },
        {
          "Name": "MyAnimeList",
          "Url": "https://myanimelist.net/anime/${data['idMal']}/"
        },
        for (final item in data['externalLinks'] ?? [])
          {
            "Name": item['site'],
            "Url": item['url'],
          },
      ],
      // TODO Setting for this
      'Name': data['title']['english'] ?? data['title']['romaji'],
      'OriginalTitle': data['title']['romaji'] ?? data['title']['english'],

      "ProviderIds": {
        providerId: id,
        'MyAnimeList': data['idMal'].toString(),
        // ! "AniDB"
        // ! "AniSearch"
        // ! 'Tvdb'
        // ! 'Imdb'
        // ! 'TvRage'
        // ! 'TVmaze'
        // ! 'OMDb'
      },
    };

    final startDate = data['startDate'];
    if (startDate != null) {
      final dt =
          DateTime(startDate['year'], startDate['month'], startDate['day']);

      item['PremiereDate'] = dt.toIso8601String();
      item['ProductionYear'] = dt.year;
    }

    final endDate = data['endDate'];
    if (endDate != null &&
        endDate['year'] != null &&
        endDate['month'] != null &&
        endDate['day'] != null) {
      final dt = DateTime(endDate['year'], endDate['month'], endDate['day']);

      item['EndDate'] = dt.toIso8601String();
    }

    item['Studios'] = [
      for (final studio in data['studios']?['nodes'] ?? [])
        {
          "Name": studio['name'],
          "Id": createIdHash(
            utf8.encode(
              'Studio-${providerId}-${studio['id']}',
            ),
          ),
          'Type': 'Studio',
          // createIdHash(studio['id']),
        },
    ];
    item['People'] = [];

    for (final edge in data['characters']['edges']) {
      for (final va in edge['voiceActors']) {
        if (va['language'] != 'JAPANESE') continue;
        // TODO Setting for language preference
        final person = {
          "Name": va['name']['full'],
          "Id": createIdHash(
            utf8.encode(
              'Actor-${providerId}-${edge['node']['id']}',
            ),
          ),
          "Role": edge['node']['name']['full'],
          "Type": "Actor",
          // 'ImageUrl': ,
          "PrimaryImageTag": "external-${base64Url.encode(
            utf8.encode(
              edge['node']['image']['large'] ?? edge['node']['image']['medium'],
              // TODO Setting for image preference (character or voice actor)
              // va['image']['large'] ?? va['image']['medium'],
            ),
          )}",
          "ProviderIds": {
            providerId: id,
          },
        };
        items.add(person);
        item['People'].add(person);
      }
    }
    item['Tags'] = [
      /*  {
          "Name": studio['name'],
          "Id": createIdHash(
            utf8.encode(
              'Studio-${providerName}-${studio['id']}',
            ),
          ),
          'Type': 'Studio',
          // createIdHash(studio['id']),
        }, */
    ];
    for (final tag in data['tags'] ?? []) {
      if (tag['isGeneralSpoiler'] || tag['isMediaSpoiler']) continue;
      item['Tags'].add(tag['name']);
    }
    item['Genres'] = [];
    item['GenreItems'] = [];
    for (final genre in ['Anime', ...data['genres']]) {
      item['Genres'].add(genre);
      final genreId = createIdHash(utf8.encode('genre_' + genre)).toString();
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

    /* 
      "AirTime": "8:15 PM",
      "AirDays": ["Thursday"], */

    if (data['status'] == "FINISHED" || data['status'] == "CANCELLED") {
      item['Status'] = 'Ended';
    } else if (data['status'] == "RELEASING") {
      item['Status'] = 'Continuing';
      // TODO AirTime
    }

    item['RemoteTrailers'] = [];

    for (final trailer in data['trailers'] ?? [data['trailer']]) {
      if (trailer?['site'] != 'youtube') continue;

      item['RemoteTrailers'].add({
        'Name': 'YouTube',
        'Url': 'https://www.youtube.com/watch?v=${trailer['id']}',
      });
    }

    return {
      'items': items,
      'item': item,
    };
  }

  //Future<MetadataResult> fetchMetadata() async {}

  final String providerId = "AniList";
  final int providerVersion = 0;

  String generateUrl(String type, String id) {
    return "https://anilist.co/anime/$id/";
  }

  /* public ExternalIdMediaType? Type
            => ExternalIdMediaType.Series; */

}

/* class MetadataResult {
  MetadataResult({
    required this.fields,
    required this.items,
  });

  final Map fields;
  final List<Map> items;
} */

final detailsQuery =
    r'''query ($id: Int) { # Define which variables will be used in the query (id)
  Media (id: $id, type: ANIME) { # Insert our variables into the query arguments (id) (type: ANIME is hard-coded in the query)
    id
		idMal
		description
		startDate {
			year
			month
			day
		}
		endDate {
			year
			month
			day
		}
		externalLinks {
			id
			url
			site
			
		}
		coverImage {
      medium
      large
      extraLarge
		}
		bannerImage
		season
		seasonYear
		type
		format
		status
		episodes
		duration
		chapters
		volumes
		isAdult
		genres
		averageScore
		meanScore
		popularity
		source
		countryOfOrigin
		isLicensed
		hashtag
		trailer {
			id
			site
			thumbnail
		}
		updatedAt
		siteUrl
		stats {
			scoreDistribution {
				score
				amount
			}
			statusDistribution {
				status
				amount
			}
		}
		synonyms
		#relations {
		#	edges {
		#		id
				# todo
		#	}
		#	nodes {
		#		id
				# todo
		#	}
		#	pageInfo {
		#		total
				# todo
		#	}
		#}
    characters(sort: [ROLE]) {
      edges {
        node {
          id
          name {
            first
            last
            full
          }
          image {
            medium
            large
          }
        }
        role
        voiceActors {
          id
          name {
            first
            last
            full
            native
          }
          image {
            medium
            large
          }
          language
        }
      }
    }
  
		
		tags {
			id
			name
			description
			category
			rank
			isGeneralSpoiler
			isMediaSpoiler
			isAdult
		}
    nextAiringEpisode {
      airingAt
      timeUntilAiring
      episode
    }
    studios {
      nodes {
        id
        name
        isAnimationStudio
      }
    }
		#staff
		#studios
		#nextAiringEpisode
		#airingSchedule
		#trends
		#externalLinks {
		#	id
		#	url
		#	site
		# }
		#streamingEpisodes
		#rankings
		#reviews
		#recommendations
    title {
      romaji
      english
      native
      userPreferred
    }
  }
}
''';

final searchQuery = r'''query ($search: String, $page: Int, $perPage: Int) {
	# Define which variables will be used in the query (id)
	Page(page: $page, perPage: $perPage) {
		pageInfo {
			total
			currentPage
			lastPage
			hasNextPage
			perPage
		}
		media(search: $search, type: ANIME) {
			id
			idMal
			startDate {
				year
				month
				day
			}
			endDate {
				year
				month
				day
			}
			season
			seasonYear
			type
			format
			status
			episodes
			duration
			chapters
			volumes
			isAdult
			genres
			averageScore
			popularity
			source
			countryOfOrigin
			hashtag
			synonyms
			title {
				romaji
				english
				native
			}
			coverImage {
				medium
			}
		}
	}
}

''';
