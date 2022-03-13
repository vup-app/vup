import 'package:filesize/filesize.dart';

String renderFileSystemEntityCount(
  int filesCount,
  int dirCount, [
  int? totalFileSize,
]) {
  var str = '';

  if (dirCount > 0) {
    if (dirCount == 1) {
      str += '1 directory';
    } else {
      str += '$dirCount directories';
    }
  }

  if (filesCount > 0) {
    if (str.isNotEmpty) str += ', ';

    if (filesCount == 1) {
      str += '1 file';
    } else {
      str += '$filesCount files';
    }
    if (totalFileSize != null) {
      str += ' (${filesize(
        totalFileSize,
      )})';
    }
  }
  return str;
}
