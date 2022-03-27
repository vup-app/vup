import 'dart:io';
import 'dart:math';

import 'package:alfred/alfred.dart';
import 'package:intl/intl.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:random_string/random_string.dart';
import 'package:vup/generic/state.dart';
import 'package:vup/service/base.dart';
import 'package:vup/service/web_server/serve_chunked_file.dart';

class TemporaryStreamingServerService extends VupService {
  bool isRunning = false;
  late Alfred app;

  void stop() {
    info('stopping server...');
    app.close(force: true);
    isRunning = false;
    info('stopped server.');
  }

  final availableFiles = <String, DirectoryFile>{};

  Future<String> makeFileAvailable(DirectoryFile file) async {
    start(43913, '0.0.0.0');
    final streamingKey = randomAlphaNumeric(
      32,
      provider: CoreRandomProvider.from(
        Random.secure(),
      ),
    ).toLowerCase();
    availableFiles[streamingKey] = file;

    final info = NetworkInfo();
    String? ipAddress;
    try {
      ipAddress = await info.getWifiIP();
    } catch (_) {}
    ipAddress ??= '127.0.0.1';

    return 'http://$ipAddress:43913/stream/$streamingKey/${file.name}';
  }

  void start(int port, String bindIp) {
    if (isRunning) return;
    isRunning = true;

    info('starting server...');

    app = Alfred();

    Map<String, String> getHeadersForFile(DirectoryFile file) {
      final df = DateFormat('EEE, dd MMM yyyy HH:mm:ss');
      final dt = DateTime.fromMillisecondsSinceEpoch(file.modified).toUtc();
      return {
        'Accept-Ranges': 'bytes',
        'Content-Length': file.file.size.toString(),
        'Content-Type': file.mimeType ?? 'application/octet-stream',
        'Etag': '"${file.file.hash}"',
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

      if (file.file.encryptionType == 'libsodium_secretbox') {
        await handleChunkedFile(req, res, file, file.file.size);
        return null;
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
}
