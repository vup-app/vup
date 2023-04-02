import 'package:lib5/lib5.dart';
import 'package:vup/generic/state.dart';
import 'package:lib5/storage_service.dart';
import 'package:vup/service/base.dart';
import 'package:messagepack/messagepack.dart';

class PinningService extends VupService {
  void start() {
    run().then((_) {
      unpinDeletedHashes();
    });
    Stream.periodic(Duration(seconds: 50)).listen((event) {
      run();
    });
    Stream.periodic(Duration(minutes: 10)).listen((event) {
      unpinDeletedHashes();
    });
  }

  final portalPinsCursors = <String, int>{};
  final portalPins = <String, Set<Multihash>>{};

  List<String> getPinsForHash(Multihash hash) {
    final pins = <String>[];
    for (final authority in portalPins.keys) {
      if (portalPins[authority]!.contains(hash)) {
        pins.add(authority);
      }
    }
    return pins;
  }

  Future<void> run() async {
    verbose('run');
    for (final pc in mySky.storageServiceConfigs) {
      try {
        portalPins[pc.authority] ??= <Multihash>{};
        final res = await mySky.httpClient.get(
          pc.getAccountsAPIUrl(
            portalPinsCursors.containsKey(pc.authority)
                ? '/s5/account/pins.bin?cursor=${portalPinsCursors[pc.authority]}'
                : '/s5/account/pins.bin',
          ),
          headers: pc.headers,
        );
        if (res.statusCode != 200) {
          throw 'HTTP ${res.statusCode}: ${res.body}';
        }

        final unpacker = Unpacker(res.bodyBytes);

        if (unpacker.unpackInt() != 0) {
          throw 'Unsupported pin list version';
        }
        final cursor = unpacker.unpackInt()!;

        verbose('cursor $cursor');

        final length = unpacker.unpackListLength();

        verbose('length $length');

        for (int i = 0; i < length; i++) {
          portalPins[pc.authority]!.add(Multihash(unpacker.unpackBinary()));
        }

        portalPinsCursors[pc.authority] = cursor;

        // portalStats[pc.authority] = stats;
      } catch (e, st) {
        warning(e);
        verbose(st);
      }
    }
  }

  // TODO Use mass-delete endpoint
  Future<void> unpinDeletedHashes() async {
    verbose('unpinDeletedHashes');
    final box = mySky.deletedCIDs;
    for (final value in box.values) {
      final cid = CID.fromBytes(value);
      for (final pc in mySky.storageServiceConfigs) {
        if (!portalPins.containsKey(pc.authority)) continue;

        if (portalPins[pc.authority]!.contains(cid.hash)) {
          verbose('unpin ${pc.authority} $cid');
          try {
            final res = await mySky.httpClient.delete(
              pc.getAPIUrl('/s5/delete/$cid'),
              headers: pc.headers,
            );
            res.expectStatusCode(200);
            portalPins[pc.authority]!.remove(cid.hash);
            // TODO Delete from box if all portalPins are non-empty for configs and don't contain it
          } catch (e, st) {
            catched(e, st);
          }
        }
      }
    }
  }
}
