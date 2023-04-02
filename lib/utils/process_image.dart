import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:filesystem_dac/dac.dart';
import 'package:exif/exif.dart';
import 'package:image/image.dart' as img;
import 'package:s5_server/constants.dart';

import 'package:lib5/src/crypto/encryption/chunk.dart';
import 'package:vup/app.dart';
import 'package:lib5/util.dart';

import 'package:vup/rust/ffi.dart' as ffi;
import 'package:vup/generic/state.dart';

// TODO Move this to SkyFS

Future<List> processImage2(List list) async {
  logger.verbose('upload-timestamp-process-image-1 ${DateTime.now()}');
  /* for (final item in list) {
    logger.verbose('processImage ${item.length}');
  } */
  // String extension = list[0].toLowerCase();
  // String extension = list[0].toLowerCase();

  String type = list[0];
  // logger.verbose('processImage type ${type}');
  String imagePath = list[1];

  // 32 bytes
  Uint8List rootThumbnailSeed = list[2];

  List more = [];

  bool hasThumbnail = false;

  Map<String, dynamic>? ext;

  if (type != 'image') {
    // final hash = sha256.convert(bytes);

    // ext ??= {};

    // ext[type] ??= {};
    // ext[type]['coverKey'] ??= key;

    // more.add(bytes);

    hasThumbnail = true;
  }

  // if (hasThumbnail || supportedImageExtensions.contains(extension)) {
  try {
    logger.verbose('upload-timestamp-process-image-9 ${DateTime.now()}');
    final result = await ffi.api
        .generateThumbnailForImageFile(imageType: type, path: imagePath);
    // var image = img.decodeImage(bytes);

    logger.verbose('upload-timestamp-process-image-20 ${DateTime.now()}');

    ext ??= {};

    if (!hasThumbnail) {
      ext['image'] = {
        'width': result.width,
        'height': result.height,
      };
    }

/*     final size = 384;

    
    final thumbnail = type == 'audio'
        ? img.copyResizeCropSquare(image, size)
        : image.width > image.height
            ? img.copyResize(
                image,
                height: size,
              )
            : img.copyResize(
                image,
                width: size,
              );

    final thumbnailBytes = Uint8List.fromList(img.encodeJpg(
      thumbnail,
      quality: 80,
    )); */

    // final hash = sha1.convert(thumbnailBytes);

    // TODO Do EXIF stuff in Rust
    final res = await deriveThumbnailKey(
      result.bytes,
      rootThumbnailSeed,
    );

    ext['thumbnail'] = {
      'cid': res[0] as String,
      'aspectRatio': (result.width / result.height) + 0.0,
      // TODO Rust blurhash/thumbhash
      // 'blurHash':null
      /* BlurHash.encode(
        thumbnail,
        numCompX: 5, // TODO Aspect-ratio
        numCompY: 5,
      ).hash */
    };
    more.add(result.bytes);

    more.add(res[1] as Uint8List);

    try {
      if (!hasThumbnail) {
        Map<String, IfdTag> data =
            await readExifFromBytes(File(imagePath).readAsBytesSync());
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
  } catch (e, st) {
    logger.verbose(e);
    logger.verbose(st);
  }
  // }

  logger.verbose('upload-timestamp-process-image-2 ${DateTime.now()}');

  return <dynamic>[
        json.encode(ext),
      ] +
      more;
}

Future<List> deriveThumbnailKey(
  Uint8List imageBytes,
  Uint8List rootThumbnailSeed,
) async {
  final hash = mySky.crypto.hashBlake3Sync(imageBytes);

  final encryptionKey = mySky.crypto.hashBlake3Sync(
    Uint8List.fromList(
      hash + rootThumbnailSeed,
    ),
  );

  const totalOverhead = 16;

  final finalSize =
      padFileSizeDefault(imageBytes.length + totalOverhead) - totalOverhead;

  final padding = finalSize - imageBytes.length;

  final message = Uint8List(finalSize);

  message.setAll(0, imageBytes);

  final cipherText = await encryptChunk(
    index: 0,
    key: encryptionKey,
    plaintext: message,
    crypto: mySky.crypto,
  );

  final cipherTextHash = mySky.crypto.hashBlake3Sync(cipherText);

  final cid = EncryptedCID(
    encryptedBlobHash: Multihash(Uint8List.fromList(
      [mhashBlake3Default] + cipherTextHash,
    )),
    originalCID: CID(
      cidTypeRaw,
      Multihash(Uint8List.fromList([mhashBlake3Default] + hash)),
      size: imageBytes.length,
    ),
    encryptionKey: encryptionKey,
    padding: padding,
    chunkSizeAsPowerOf2: defaultChunkSizeAsPowerOf2,
    encryptionAlgorithm: encryptionAlgorithmXChaCha20Poly1305,
  );

  return ['${cid.toBase64Url()}.webp', cipherText];
}

// base64url,         u,    rfc4648 no padding,                                           default
