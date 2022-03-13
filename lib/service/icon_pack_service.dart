import 'dart:convert';
import 'dart:io';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart';
import 'package:vup/app.dart';
import 'package:vup/material_icons/file_icons.dart' as def;
import 'package:vup/material_icons/folder_icons.dart' as def;

class IconPackService {
  String? customIconPack = null;

  late Map<String, dynamic> customFolderIcons;
  late Map<String, dynamic> customFileIcons;

  late String folderIconsBasePath;
  late String fileIconsBasePath;

  Future<void> initCustomIconPack(String name) async {
    final baseDir =
        Directory(join(storageService.dataDirectory, 'icons', name));

    if (!baseDir.existsSync()) {
      throw 'Theme does not exist (expected location: ${baseDir.path}';
    }
    folderIconsBasePath = join(baseDir.path, 'folder');
    fileIconsBasePath = join(baseDir.path, 'file');

    customFolderIcons = json
        .decode(
          File(join(folderIconsBasePath, 'index.json')).readAsStringSync(),
        )
        .cast<String, dynamic>();

    customFileIcons = json
        .decode(
          File(join(fileIconsBasePath, 'index.json')).readAsStringSync(),
        )
        .cast<String, dynamic>();

    customIconPack = name;
  }

  Widget buildIcon(
      {required String name,
      required bool isDirectory,
      required double iconSize}) {
    if (customIconPack == null) {
      return SvgPicture.asset(
        'assets/vscode-material-icon-theme/${detectDefaultIcon(
          name,
          isDirectory: isDirectory,
        )}.svg',
        width: iconSize, // widget.zoomLevel.gridSize * 0.4,
        height: iconSize, // widget.zoomLevel.gridSize * 0.4,
      );
    } else {
      return SvgPicture.file(
        File(join(
          isDirectory ? folderIconsBasePath : fileIconsBasePath,
          '${detectCustomIcon(
            name,
            isDirectory: isDirectory,
          )}.svg',
        )),
        width: iconSize, // widget.zoomLevel.gridSize * 0.4,
        height: iconSize, // widget.zoomLevel.gridSize * 0.4,
      );
    }
  }

  String detectCustomIcon(String name, {required bool isDirectory}) {
    final lowercaseName = name.toLowerCase();

    if (isDirectory) {
      for (final folderIcon in customFolderIcons['icons']) {
        if (folderIcon['folderNames'].contains(lowercaseName)) {
          return folderIcon['name'];
        }
      }
      return 'folder';
    } else {
      final ext = lowercaseName.split('.').last;

      for (final fileIcon in (customFileIcons['icons'] as List)) {
        if ((fileIcon['fileNames'] ?? []).contains(lowercaseName) ||
            (fileIcon['fileExtensions'] ?? []).contains(ext)) {
          return fileIcon['name'];
        }
      }
      return 'file';
    }
  }

  String detectDefaultIcon(String name, {required bool isDirectory}) {
    final lowercaseName = name.toLowerCase();

    if (isDirectory) {
      for (final folderIcon in def.folderIcons['icons']) {
        if (folderIcon['folderNames'].contains(lowercaseName)) {
          return folderIcon['name'];
        }
      }
      return 'folder';
    } else {
      final ext = lowercaseName.split('.').last;

      for (final fileIcon in (def.fileIcons['icons'] as List)) {
        if ((fileIcon['fileNames'] ?? []).contains(lowercaseName) ||
            (fileIcon['fileExtensions'] ?? []).contains(ext)) {
          return fileIcon['name'];
        }
      }
      return 'file';
    }
  }
}
