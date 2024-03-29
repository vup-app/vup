// AUTO GENERATED FILE, DO NOT EDIT.
// Generated by `flutter_rust_bridge`@ 1.73.0.
// ignore_for_file: non_constant_identifier_names, unused_element, duplicate_ignore, directives_ordering, curly_braces_in_flow_control_structures, unnecessary_lambdas, slash_for_doc_comments, prefer_const_literals_to_create_immutables, implicit_dynamic_list_literal, duplicate_import, unused_import, unnecessary_import, prefer_single_quotes, prefer_const_constructors, use_super_parameters, always_use_package_imports, annotate_overrides, invalid_use_of_protected_member, constant_identifier_names, invalid_use_of_internal_member, prefer_is_empty, unnecessary_const

import 'dart:convert';
import 'dart:async';
import 'package:meta/meta.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:uuid/uuid.dart';

abstract class RustVup {
  Future<Uint8List> encryptFileXchacha20(
      {required String inputFilePath,
      required String outputFilePath,
      required int padding,
      dynamic hint});

  FlutterRustBridgeTaskConstMeta get kEncryptFileXchacha20ConstMeta;

  Future<int> decryptFileXchacha20(
      {required String inputFilePath,
      required String outputFilePath,
      required Uint8List key,
      required int padding,
      required int lastChunkIndex,
      dynamic hint});

  FlutterRustBridgeTaskConstMeta get kDecryptFileXchacha20ConstMeta;

  Future<ThumbnailResponse> generateThumbnailForImageFile(
      {required String imageType,
      required String path,
      required int exifImageOrientation,
      dynamic hint});

  FlutterRustBridgeTaskConstMeta get kGenerateThumbnailForImageFileConstMeta;
}

class ThumbnailResponse {
  final Uint8List bytes;
  final Uint8List thumbhashBytes;
  final int width;
  final int height;

  const ThumbnailResponse({
    required this.bytes,
    required this.thumbhashBytes,
    required this.width,
    required this.height,
  });
}
