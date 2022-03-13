import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:filesystem_dac/dac.dart';
import 'package:exif/exif.dart';
import 'package:image/image.dart' as img;
import 'package:blurhash_dart/blurhash_dart.dart';

Future<List> processImage(List list) async {
  /* for (final item in list) {
    print('processImage ${item.length}');
  } */
  // String extension = list[0].toLowerCase();
  // String extension = list[0].toLowerCase();

  String type = list[0];
  // print('processImage type ${type}');
  Uint8List bytes = list[1];
  String rootPathSeed = list[2];

  List more = [];

  bool hasThumbnail = false;

  Map<String, dynamic>? ext;

  if (type != 'image') {
    // final hash = sha256.convert(bytes);

    // final key = deriveThumbnailKey(hash, rootPathSeed);

    // ext ??= {};

    // ext[type] ??= {};
    // ext[type]['coverKey'] ??= key;

    // more.add(bytes);

    hasThumbnail = true;
  }

  // if (hasThumbnail || supportedImageExtensions.contains(extension)) {
  try {
    var image = img.decodeImage(bytes);
    if (image != null) {
      ext ??= {};

      if (!hasThumbnail) {
        ext['image'] = {
          'width': image.width,
          'height': image.height,
        };
      }

      final size = 384;

      // Resize the image to a 200x? thumbnail (maintaining the aspect ratio).
      final thumbnail = image.width > image.height
          ? img.copyResize(
              image,
              height: size,
            )
          : img.copyResize(
              image,
              width: size,
            ); // TODO Adjust, maybe use boxFit: cover

      final thumbnailBytes = img.encodeJpg(
        thumbnail,
        quality: 80,
      );

      final hash = sha1.convert(thumbnailBytes);

      final key = deriveThumbnailKey(hash, rootPathSeed);
      ext['thumbnail'] = {
        'key': key,
        'aspectRatio': (thumbnail.width / thumbnail.height) + 0.0,
        'blurHash': BlurHash.encode(
          thumbnail,
          numCompX: 5, // TODO Aspect-ratio
          numCompY: 5,
        ).hash,
      };
      more.add(Uint8List.fromList(thumbnailBytes));
      try {
        if (!hasThumbnail) {
          Map<String, IfdTag> data = await readExifFromBytes(bytes);
          if (data.isNotEmpty) {
            ext['exif'] =
                data.map((key, value) => MapEntry(key, value.printable));
          }
        }
      } catch (e) {}
    }
  } catch (e, st) {
    print(e);
    print(st);
  }
  // }

  return <dynamic>[
        json.encode(ext),
      ] +
      more;
}
