import 'dart:convert';

import 'package:filesystem_dac/dac.dart';
import 'package:vup/generic/state.dart';
/* 
Future<DownloadConfig> generateDownloadConfig(FileData fileData) async {
  final scheme = fileData.url.split(':').first;
  if (scheme == 'sia') {
    final url = storageService.mySky.skynetClient.resolveSkylink(
      fileData.url,
    )!;
    return DownloadConfig(url, storageService.mySky.skynetClient.headers ?? {});
  } else if (scheme == 'ipfs') {
    final url = 'https://ipfs.filebase.io/ipfs/${fileData.url.substring(7)}';
    return DownloadConfig(url, {});
  } else if (scheme == 'ar') {
    final url = 'https://arweave.net/${fileData.url.substring(5)}';
    return DownloadConfig(url, {});
  } else if (scheme.startsWith('remote-')) {
    final remoteId = scheme.substring(7);

    final remote = storageService.dac.customRemotes[remoteId]!;

    final Map remoteConfig = remote['config'] as Map;

    if (remote['type'] == 'webdav') {
      return DownloadConfig(
        '${remoteConfig['url']}/skyfs/${fileData.url.substring(scheme.length + 3)}',
        {
          'Authorization':
              'Basic ${base64.encode(utf8.encode('${remoteConfig['user']}:${remoteConfig['pass']}'))}'
        },
      );
    } else if (remote['type'] == 's3') {
      final client = storageService.dac.getS3Client(remoteId, remoteConfig);

      final url = await client.presignedGetObject(
        remoteConfig['bucket'],
        'skyfs/${fileData.url.substring(scheme.length + 3)}',
      );

      return DownloadConfig(
        url,
        {},
      );
    } else {
      throw 'Remote type ${remote['type']} not supported.';
    }
  } else {
    return DownloadConfig(fileData.url, {});
  }
}
 */