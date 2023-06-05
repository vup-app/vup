import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:lib5/lib5.dart';
import 'package:vup/generic/state.dart';

class JellyID extends Multihash {
  JellyID(Uint8List fullBytes) : super(fullBytes) {
    if (fullBytes.length != 16) {
      throw 'JellyID too long';
    }
  }

  @override
  toString() => hex.encode(fullBytes);

  @override
  toJson() => toString();

  factory JellyID.fromHex(String str) {
    return JellyID(Uint8List.fromList(hex.decode(str)));
  }

  static JellyID? fromHexNullable(String? str) {
    if (str == null) return null;
    return JellyID(Uint8List.fromList(hex.decode(str)));
  }

  factory JellyID.hash(String s) {
    return JellyID(
      mySky.crypto
          .hashBlake3Sync(
            Uint8List.fromList(utf8.encode(s)),
          )
          .sublist(0, 16),
    );
  }

  // TODO Playlists and play history should use full hash (33 bytes) [hmm or maybe cids]
  factory JellyID.file(FileReference file) {
    return JellyID(file.file.cid.hash.hashBytes.sublist(0, 16));
  }

  JellyID subhash(String tweak) {
    return JellyID(mySky.crypto
        .hashBlake3Sync(
          Uint8List.fromList(fullBytes + utf8.encode(tweak)),
        )
        .sublist(0, 16));
  }
}