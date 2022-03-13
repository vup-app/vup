import 'package:vup/jelly/provider/anilist.dart';
import 'package:vup/jelly/provider/omdb.dart';
import 'package:vup/jelly/provider/tvmaze.dart';

// TODO Handle HTTP 429
// TODO User agents

final providers = <JellyMetadataProvider>[
  TVmazeMetadataProvider(),
  OMDbMetadataProvider(),
  AnilistMetadataProvider(),
];

abstract class JellyMetadataProvider {
  abstract final bool supportsSearch;

  abstract final String providerId;
  abstract final int providerVersion;
  abstract final List<String> supportedTypes;

  Future<List<SearchResult>> search(String type, String query);

  Future<Map> fetchData(String id);

  List<ImageFile> extractImageFiles(Map data);

  Map generateJellyMetadata(String type, String id, Map data);
}

class ImageFile {
  ImageFile({
    required this.url,
    required this.name,
  });
  String url;
  String name;
}

class SearchResult {
  SearchResult({
    required this.providerId,
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
  });

  String providerId;
  String id;
  String type;
  String title;
  String subtitle;
  String? imageUrl;
}
