import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:alfred/alfred.dart';
import 'package:path/path.dart';
import 'package:s5_server/download/uri_provider.dart';
import 'package:s5_server/http_api/serve_chunked_file.dart';
import 'package:vup/app.dart';
import 'package:vup/generic/state.dart';
import 'package:vup/utils/download/generate_download_config.dart';

Future handlePlaintextFile(
  HttpRequest req,
  HttpResponse res,
  FileReference df,
) {
  // TODO Set relevant headers like content-type

  final dlUriProvider = StorageLocationProvider(
    s5Node,
    df.file.cid.hash,
    // TODO small file support
  );

  dlUriProvider.start();

  return handleChunkedFile(
    req,
    res,
    df.file.cid.hash,
    df.file.cid.size!,
    cachePath: join(vupTempDir, 'stream_plaintext'),
    logger: s5Node.logger,
    node: s5Node,
  );
//   final dc = await generateDownloadConfig(df.file);

  // final httpClient = HttpClient();
  // final serverReq = await httpClient.getUrl(Uri.parse(dc.url));
}
