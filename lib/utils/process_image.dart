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
            if (data.containsKey('Image DateTime')) {
              ext['exif'] ??= {};
              ext['exif']['DateTime'] = data['Image DateTime']!.printable;
            }
            if (data.containsKey('GPS GPSLatitude')) {
              final latRef = data['GPS GPSLatitudeRef']!;
              final isNorth = latRef.printable == 'N';
              final lat = data['GPS GPSLatitude']!;
              final ratios = (lat.values as IfdRatios).ratios;

              var latValue = ratios[0].toDouble() +
                  ratios[1].toDouble() / 60 +
                  ratios[2].toDouble() / 3600;
              if (!isNorth) {
                latValue = -latValue;
              }

              final longRef = data['GPS GPSLongitudeRef']!;
              final isEast = longRef.printable == 'E';
              final long = data['GPS GPSLongitude']!;
              final longRatios = (long.values as IfdRatios).ratios;

              var longValue = longRatios[0].toDouble() +
                  longRatios[1].toDouble() / 60 +
                  longRatios[2].toDouble() / 3600;
              if (!isEast) {
                longValue = -longValue;
              }

              if (latValue > 0 || latValue < 0) {
                ext['exif']['GPSLatitude'] = latValue;
                ext['exif']['GPSLongitude'] = longValue;
              }

              final altitude = (data['GPS GPSAltitude']!.values as IfdRatios)
                  .ratios
                  .first
                  .toDouble();
              if (altitude > 0) {
                ext['exif']['GPSAltitude'] = altitude;
              }
            }
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
