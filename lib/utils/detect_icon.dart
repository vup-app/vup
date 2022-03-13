import 'package:vup/material_icons/file_icons.dart' as def;
import 'package:vup/material_icons/folder_icons.dart' as def;

String detectIcon(String name, {required bool isDirectory}) {
  final lowercaseName = name.toLowerCase();

  late final folderIcons;
  late final fileIcons;

  folderIcons = def.folderIcons;
  fileIcons = def.fileIcons;

  if (isDirectory) {
    for (final folderIcon in folderIcons['icons']) {
      if (folderIcon['folderNames'].contains(lowercaseName)) {
        return folderIcon['name'];
      }
    }
    return 'folder';
  } else {
    final ext = lowercaseName.split('.').last;

    for (final fileIcon in (fileIcons['icons'] as List)) {
      if ((fileIcon['fileNames'] ?? []).contains(lowercaseName) ||
          (fileIcon['fileExtensions'] ?? []).contains(ext)) {
        return fileIcon['name'];
      }
    }
    return 'file';
  }
}
