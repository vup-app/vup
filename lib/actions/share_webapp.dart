import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:filesystem_dac/dac.dart';
import 'package:flutter/services.dart';
import 'package:vup/app.dart';
import 'package:skynet/src/crypto.dart';
import 'package:skynet/src/utils/convert.dart';
import 'package:vup/view/share_dialog.dart';

import 'base.dart';

class ShareWebAppVupAction extends VupFSAction {
  @override
  VupFSActionInstance? check(
      bool isFile,
      dynamic entity,
      PathNotifierState pathNotifier,
      BuildContext context,
      bool isDirectoryView,
      bool hasWriteAccess,
      FileState fileState,
      bool isSelected) {
    if (!isDirectoryView) return null;
    if (!devModeEnabled) return null;

    return VupFSActionInstance(
      label: 'Share as web app',
      icon: UniconsLine.html5,
    );
  }

  @override
  Future execute(
    BuildContext context,
    VupFSActionInstance instance,
  ) async {
    final availableDirectoryFiles = {};
    final baseUri = instance.pathNotifier.toCleanUri();
    final baseUriLength = baseUri.toString().length;

    final di = await storageService.dac.getDirectoryIndex(
      baseUri.replace(
        queryParameters: {'recursive': 'true'},
      ).toString(),
    );
    for (final file in di.files.entries) {
      availableDirectoryFiles[file.key.substring(baseUriLength)] = file.value;
    }

    final key = storageService.dac.sodium.secureRandom(
      storageService.dac.sodium.crypto.secretBox.keyBytes,
    );

    final ciphertext = storageService.dac.sodium.crypto.secretBox.easy(
      message:
          Uint8List.fromList(utf8.encode(json.encode(availableDirectoryFiles))),
      nonce: Uint8List(storageService.dac.sodium.crypto.secretBox.nonceBytes),
      key: key,
    );

    final encryptedBase64 = base64Url.encode(ciphertext);

    final indexHtml = '''
<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>E2EE web app</title>
</head>

<body>

<script>
    let ciphertext = '$encryptedBase64';
    const sw = navigator.serviceWorker

    async function main() {

      if (!sw) {
        alert('Service Worker API not supported')
        return
      }

      let key = window.location.hash.substring(1);

      if(key.length === 0){
        alert('No decryption key provided.');
        return;
      }     
      if (!sw.controller) {
        try {
          await sw.register('/__skyfs_internal_EWhqPkTLE2L3jv_sw.js').then(function (registration) {
            // registration worked
            console.log('Registration succeeded.');
          })
        } catch (e) {
          alert(e)
          return
        }
      }
      sw.onmessage = (e) => {
        console.log(e);
        window.location.hash = '';
        window.location.reload();
      }
      while (true) {         
        if (sw.controller != null) {          
          sw.controller.postMessage({
            ciphertext,
            key,
          })
          
          break;
        }
        await new Promise(r => setTimeout(r, 100));
      }
    }
    main()
</script>
</body>
</html>
''';

    final sodiumJSBytes =
        utf8.encode(await rootBundle.loadString('assets/web/sodium.js'));
    final swJSBytes =
        utf8.encode(await rootBundle.loadString('assets/web/sw.js'));

    final skylink = await mySky.skynetClient.upload.uploadDirectory(
      {
        '__skyfs_internal_EWhqPkTLE2L3jv_sodium.js':
            Stream.value(sodiumJSBytes),
        '__skyfs_internal_EWhqPkTLE2L3jv_sw.js': Stream.value(swJSBytes),
        'index.html': Stream.value(utf8.encode(indexHtml)),
      },
      {
        '__skyfs_internal_EWhqPkTLE2L3jv_sodium.js': sodiumJSBytes.length,
        '__skyfs_internal_EWhqPkTLE2L3jv_sw.js': swJSBytes.length,
        'index.html': utf8.encode(indexHtml).length,
      },
      'index.html',
    );

    if (skylink == null) {
      throw 'Upload failed';
    }
    final base32Skylink = encodeSkylinkToBase32(
      convertSkylinkToUint8List(
        skylink,
      ),
    );
    showShareResultDialog(
      context,
      'https://$base32Skylink.siasky.net/#${base64Url.encode(key.extractBytes())}',
    );
  }
}
