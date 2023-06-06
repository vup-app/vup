import 'dart:convert';
import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:lib5/constants.dart';
import 'package:lib5/lib5.dart';
import 'package:s5_server/api.dart';
import 'package:s5_server/node.dart';
import 'package:vup/generic/state.dart';

class VupS5ApiProvider extends S5NodeAPIProviderWithRemoteUpload {
  VupS5ApiProvider(S5Node node, {required Box<Uint8List> deletedCIDs})
      : super(node, deletedCIDs: deletedCIDs);

  @override
  Future<CID> uploadRawFile(Uint8List data) async {
    final List<String> services;
    if (data[0] == 0x8d && data[1] == 0x01) {
      services = mySky.metadataUploadServiceOrder;
    } else {
      services = mySky.thumbnailUploadServiceOrder;
    }
    final expectedHash = await crypto.hashBlake3(data);
    final cid = CID(
      cidTypeRaw,
      Multihash(Uint8List.fromList(
        [mhashBlake3Default] + expectedHash,
      )),
      size: data.length,
    );

    final results = await Future.wait(
      [
        for (final service in services)
          _uploadRawFileInternal(cid, service, data)
      ],
    );
    for (final result in results) {
      if (result) return cid;
    }
    throw 'Could not upload raw file $services $results';
  }

  Future<bool> _uploadRawFileInternal(
    CID expectedCID,
    String service,
    Uint8List data,
  ) async {
    logger.verbose('_uploadRawFileInternal $service');
    try {
      if (service == '_local') {
        final cid = await node.uploadRawFile(data);
        if (cid != expectedCID) {
          throw 'Integrity check for uploaded file failed (local store)';
        }
        return true;
      }
      final sc =
          storageServiceConfigs.firstWhere((sc) => sc.authority == service);
      final res = await httpClient.post(
        sc.getAPIUrl(
          '/s5/upload',
        ),
        headers: sc.headers,
        body: data,
      );
      if (res.statusCode != 200) {
        throw 'HTTP ${res.statusCode}: ${res.body}';
      }
      final cid = CID.decode(jsonDecode(res.body)['cid']);
      if (cid != expectedCID) {
        throw 'Integrity check for file uploaded to $service failed ($cid != $expectedCID)';
      }
      return true;
    } catch (e, st) {
      logger.catched(e, st);
      return false;
    }
  }
}
