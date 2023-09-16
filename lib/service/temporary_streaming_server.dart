import 'dart:io';
import 'dart:math';

import 'package:alfred/alfred.dart';
import 'package:intl/intl.dart';
import 'package:random_string/random_string.dart';
import 'package:vup/app.dart';
import 'package:vup/generic/state.dart';
import 'package:vup/service/base.dart';
import 'package:vup/service/web_server/serve_chunked_file.dart';
import 'package:vup/service/web_server/serve_plaintext_file.dart';

class TemporaryStreamingServerService extends VupService {
  bool isRunning = false;
  late Alfred app;

  void stop() {
    info('stopping server...');
    app.close(force: true);
    isRunning = false;
    info('stopped server.');
  }

  final availableFiles = <String, FileReference>{};

  Future<String> makeFileAvailable(
    FileReference file,
  ) async {
    start(43913, '0.0.0.0');
    final streamingKey = randomAlphaNumeric(
      32,
      provider: CoreRandomProvider.from(
        Random.secure(),
      ),
    ).toLowerCase();
    availableFiles[streamingKey] = file;

    final ipAddress = await externalIpAddressProvider.getIpAddress();

    return 'http://$ipAddress:43913/stream/$streamingKey/${Uri.encodeComponent(file.name)}';
  }

  String makeFileAvailableLocalhost(
    FileReference file,
  ) {
    start(43913, '0.0.0.0');
    final streamingKey = randomAlphaNumeric(
      32,
      provider: CoreRandomProvider.from(
        Random.secure(),
      ),
    ).toLowerCase();
    availableFiles[streamingKey] = file;
    return 'http://localhost:43913/stream/$streamingKey/${Uri.encodeComponent(file.name)}';
  }

  void start(int port, String bindIp) {
    if (isRunning) return;
    isRunning = true;

    info('starting server...');

    app = Alfred();

    Map<String, String> getHeadersForFile(FileReference file) {
      final df = DateFormat('EEE, dd MMM yyyy HH:mm:ss');
      final dt = DateTime.fromMillisecondsSinceEpoch(file.modified).toUtc();
      return {
        'Accept-Ranges': 'bytes',
        'Content-Length': file.file.cid.size.toString(),
        'Content-Type': file.mimeType ?? 'application/octet-stream',
        'Etag': '"${file.file.cid.hash.toBase64Url()}"',
        'Last-Modified': df.format(dt) + ' GMT',
      };
    }

    app.get('/stream/:streamingKey/:filename', (req, res) async {
      final key = req.params['streamingKey'];

      final file = availableFiles[key];
      if (file == null) {
        res.statusCode = HttpStatus.notFound;
        return '';
      }

      for (final e in getHeadersForFile(file).entries) {
        res.headers.set(e.key, e.value);
      }

      final localFile = storageService.getLocalFile(file);
      if (localFile != null) return localFile;

      if (file.file.encryptedCID == null) {
        return await handlePlaintextFile(req, res, file);
      } else if (file.file.encryptedCID?.encryptionAlgorithm ==
          encryptionAlgorithmXChaCha20Poly1305) {
        await handleChunkedFile(req, res, file, file.file.cid.size!);
        return null;
      } else {
        throw 'Encryption type not supported';
      }
    });

    app.head('/stream/:streamingKey/:filename', (req, res) async {
      final key = req.params['streamingKey'];

      final file = availableFiles[key];
      if (file == null) {
        res.statusCode = HttpStatus.notFound;
        return null;
      }

      for (final e in getHeadersForFile(file).entries) {
        res.headers.set(e.key, e.value);
      }

      return '';
    });

    info('server is running at $bindIp:$port');

    app.listen(port, bindIp);
  }

  String getPathOrStreamingUrl(FileReference file) {
    final localFile = storageService.getLocalFile(file);
    if (localFile != null) return localFile.path;
    return makeFileAvailableLocalhost(file);
  }
}
