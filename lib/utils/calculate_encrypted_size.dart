import 'package:vup/app.dart';

int calculateEncryptedFileSize(FileVersion fileVersion) {
  return (((fileVersion.cid.size! / fileVersion.encryptedCID!.chunkSize)
                  .floor() *
              (fileVersion.encryptedCID!.chunkSize + 16)) +
          (fileVersion.cid.size! % fileVersion.encryptedCID!.chunkSize) +
          16 +
          fileVersion.encryptedCID!.padding)
      .round();
}
