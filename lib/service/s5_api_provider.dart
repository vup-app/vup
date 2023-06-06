import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:lib5/lib5.dart';
import 'package:s5_server/api.dart';
import 'package:s5_server/node.dart';

class VupS5ApiProvider extends S5NodeAPIProviderWithRemoteUpload {
  VupS5ApiProvider(S5Node node, {required Box<Uint8List> deletedCIDs})
      : super(node, deletedCIDs: deletedCIDs);

  @override
  Future<CID> uploadRawFile(Uint8List data) async {
    if (node.store != null) {
      return node.uploadRawFile(data);
    } else {
      return super.uploadRawFile(data);
    }
  }
}
