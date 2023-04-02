/* import 'dart:io';
import 'dart:convert';

import 'package:alfred/alfred.dart';
import 'package:skynet/skynet.dart';
import 'package:http/http.dart';

import 'package:vup/generic/state.dart';
import 'package:vup/service/base.dart';

class PortalProxyServerService extends VupService {
  bool isRunning = false;
  late Alfred app;

  void stop() {
    info('stopping server...');
    app.close(force: true);
    isRunning = false;
    info('stopped server.');
  }

  late SkynetClient skynetClient;
  late BaseClient httpClient;

  void start(int port, String bindIp) async {
    if (isRunning) return;
    isRunning = true;

    info('starting server...');

    skynetClient = mySky.skynetClient;
    httpClient = mySky.skynetClient.httpClient;

    var server = await HttpServer.bind(InternetAddress.anyIPv4, 4444);

    server.listen(_handler);
  }

  final hnsResCache = <String, String>{};

  final proxiedHeaders = {
    'content-type',
    'date',
    'etag',
    'skynet-proof',
    'skynet-skylink',
  };

  final additionalHeaders = {
    'access-control-allow-credentials': 'true',
    'access-control-allow-headers':
        'DNT,User-Agent,X-Requested-With,If-Modified-Since,If-None-Match,Cache-Control,Content-Type,Range,X-HTTP-Method-Override,upload-offset,upload-metadata,upload-length,tus-version,tus-resumable,tus-extension,tus-max-size,upload-concat,location',
    'access-control-allow-methods':
        'GET, POST, HEAD, OPTIONS, PUT, PATCH, DELETE',
    'access-control-expose-headers':
        'Content-Length,Content-Range,ETag,Skynet-File-Metadata,Skynet-Skylink,Skynet-Proof,Skynet-Portal-Api,Skynet-Server-Api,upload-offset,upload-metadata,upload-length,tus-version,tus-resumable,tus-extension,tus-max-size,upload-concat,location',
  };

  void _handler(HttpRequest request) async {
    final uri = request.requestedUri;

    verbose('${request.method} $uri');
    Response? res;

    final parts = uri.host.split('.');
    if (parts.length == 1) {
      if (uri.path == '/skynet/registry') {
        res = await skynetClient.httpClient.get(
          uri.replace(
            scheme: 'https',
            host: skynetClient.portalHost,
            port: 443,
          ),
          headers: skynetClient.headers,
        );
      } else {
        res = await skynetClient.httpClient.get(
          uri.replace(
            scheme: 'https',
            host: skynetClient.portalHost,
            port: 443,
          ),
          headers: skynetClient.headers,
        );
      }
    } else if (parts.length == 2) {
      
    } else if (parts.length == 3) {
      if (parts[1] == 'hns') {
        final hnsDomain = parts[0];
        if (!hnsResCache.containsKey(hnsDomain)) {
          final res = await skynetClient.httpClient.get(
            Uri.parse(
              'https://${skynetClient.portalHost}/hnsres/${hnsDomain}',
            ),
            headers: skynetClient.headers,
          );
          if (res.statusCode != 200)
            throw 'HTTP ${res.statusCode}: ${res.body}';
          hnsResCache[hnsDomain] =
              (json.decode(res.body)['skylink'] as String).substring(6);
        }
        final skylink = hnsResCache[hnsDomain]!;
        info('hns $hnsDomain ${skylink}');
        final headers = <String, String>{};
        request.headers.forEach((name, values) {
          headers[name] = values.join(',');
        });
        headers.addAll(skynetClient.headers ?? {});

        final newUri = uri.replace(
          scheme: 'https',
          host: skynetClient.portalHost,
          port: 443,
          pathSegments: <String>[skylink] + uri.pathSegments,
        );

        res = await skynetClient.httpClient.get(
          newUri,
          headers: headers,
        );
      }
    }
    if (res != null || request.method == 'HEAD') {
      if (res != null) {
        for (final h in res.headers.entries) {
          if (proxiedHeaders.contains(h.key))
            request.response.headers.add(h.key, h.value);
        }
      }

      request.response.headers.add(
        'skynet-portal-api',
        'http://localhost:4444',
      );
      request.response.headers.add(
        'skynet-server-api',
        'http://localhost:4444',
      );

      for (final h in additionalHeaders.entries) {
        request.response.headers.add(h.key, h.value);
      }

      request.response.headers.removeAll('x-frame-options');
      request.response.headers.removeAll('x-xss-protection');
      request.response.headers.removeAll('x-content-type-options');

      request.response.headers.add(
        'access-control-allow-origin',
        request.headers.value('origin') ?? 'http://localhost:4444',
      );

      if (res != null) {
        request.response.statusCode = res.statusCode;
        request.response.add(res.bodyBytes);
      }
      await request.response.close();
      return;
    }
    request.response.statusCode = 404;
    request.response.write('');
    request.response.close();
  }
}
 */