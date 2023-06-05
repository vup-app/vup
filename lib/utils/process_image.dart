import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:s5_server/constants.dart';

import 'package:lib5/src/crypto/encryption/chunk.dart';
import 'package:vup/app.dart';
import 'package:lib5/util.dart';

import 'package:vup/rust/ffi.dart' as ffi;

Future<List> processImage2(List list) async {
  logger.verbose('upload-timestamp-process-image-1 ${DateTime.now()}');

  String type = list[0];
  String imagePath = list[1];

  // 32 bytes
  Uint8List rootThumbnailSeed = list[2];

  List more = [];

  FileVersionThumbnail? thumbnail;

  Map<String, dynamic>? ext;

  try {
    logger.verbose('upload-timestamp-process-image-9 ${DateTime.now()}');

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

    logger
        .verbose('upload-timestamp-process-image-exif-start ${DateTime.now()}');

    int? exifImageOrientation;

    try {
      if (type == 'image') {
        final imageFile = File(imagePath);
        Map<String, IfdTag> data = await readExifFromBytes(
          await imageFile
              .openRead(0, min(65536, imageFile.lengthSync()))
              .fold<List<int>>(
                  <int>[], (previous, element) => previous + element),
        );
        if (data.isNotEmpty) {
          ext ??= {};

          if (data.containsKey('Image DateTime')) {
            ext['exif'] ??= {};
            ext['exif']['DateTime'] = data['Image DateTime']!.printable;
          }

          if (data.containsKey('Image Orientation')) {
            exifImageOrientation =
                data['Image Orientation']!.values.firstAsInt();
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

    final result = await ffi.apiVup.generateThumbnailForImageFile(
      imageType: type,
      path: imagePath,
      exifImageOrientation: exifImageOrientation ?? 1,
    );

    final int width;
    final int height;

    if ([5, 6, 7, 8].contains(exifImageOrientation)) {
      width = result.height;
      height = result.width;
    } else {
      width = result.width;
      height = result.height;
    }

    logger.verbose('upload-timestamp-process-image-20 ${DateTime.now()}');

    ext ??= {};

    if (type == 'image') {
      ext['image'] = {
        'width': width,
        'height': height,
      };
    }

    final res = await deriveThumbnailKey(
      result.bytes,
      rootThumbnailSeed,
    );

    thumbnail = FileVersionThumbnail(
      cid: res[0] as EncryptedCID,
      aspectRatio: (width / height) + 0.0,
      thumbhash: result.thumbhashBytes,
    );

    more.add(result.bytes);

    more.add(res[1] as Uint8List);
  } catch (e, st) {
    logger.verbose(e);
    logger.verbose(st);
  }
  // }

  logger.verbose('upload-timestamp-process-image-2 ${DateTime.now()}');

  return <dynamic>[
        json.encode(ext),
        thumbnail,
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

  return [cid, cipherText];
}

// base64url,         u,    rfc4648 no padding,                                           default
