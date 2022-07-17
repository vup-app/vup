import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:alfred/alfred.dart';
import 'package:vup/generic/state.dart';
import 'package:vup/utils/download/generate_download_config.dart';

Future handlePlaintextFile(
  HttpRequest req2,
  HttpResponse res,
  DirectoryFile df,
) async {
  final dc = await generateDownloadConfig(df.file);

  final httpClient = HttpClient();
  final serverReq = await httpClient.getUrl(Uri.parse(dc.url));

  req2.headers.forEach((name, values) {
    serverReq.headers.add(name, values.join(','));
  });
  dc.headers.forEach((key, value) {
    serverReq.headers.add(key, value);
  });

  final serverRes = await serverReq.close();

  serverRes.headers.forEach((name, values) {
    res.headers.add(name, values.join(','));
  });

  res.statusCode = serverRes.statusCode;

  int totalSize = 0;
  late StreamSubscription sub;

  var isCancelled = false;

  sub = serverRes.listen((event) {
    try {
      res.add(event);
      totalSize += event.length;
      if (totalSize > 1000 * 1000 * 100) {
        throw 'stop';
      }
    } catch (e) {
      print(e);
      sub.cancel();
      isCancelled = true;
    }
  });
  while (!isCancelled) {
    await Future.delayed(Duration(seconds: 1));
  }
}
