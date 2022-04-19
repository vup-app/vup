import 'dart:convert';

import 'package:alfred/alfred.dart';
import 'package:uuid/uuid.dart';
import 'package:vup/generic/state.dart';
import 'package:vup/service/base.dart';

class APIServerService extends VupService {
  bool isRunning = false;
  late Alfred app;

  void stop() {
    info('stopping server...');
    app.close(force: true);
    isRunning = false;
    info('stopped server.');
  }

  void start(int port, String bindIp, String apiKey) {
    if (isRunning) return;
    isRunning = true;

    info('starting server...');

    app = Alfred();

    app.all(
      '/*',
      (req, res) async {
        try {
          final authHeader = req.headers['authorization']!.first;
          final token = authHeader.substring(7);
          if (token != apiKey) throw 'Invalid API key / token';
        } catch (e) {
          warning('[auth] invalid ($e)');
          res.statusCode = 401;
          await res.close();
        }
      },
    );

    app.get(
      '/api/v0/scripts',
      (req, res) {
        return json.decode(dataBox.get('scripts') ?? '[]');
      },
    );
    app.post(
      '/api/v0/scripts',
      (req, res) async {
        final data = await req.bodyAsJsonMap;

        data.addAll({
          "id": Uuid().v4(),
          "devices": [dataBox.get('deviceId')],
        });

        final List scripts = json.decode(dataBox.get('scripts') ?? '[]');

        scripts.add(data);

        dataBox.put('scripts', json.encode(scripts));

        return '';
      },
    );

    info('server is running at $bindIp:$port');

    app.listen(port, bindIp);
  }
}
