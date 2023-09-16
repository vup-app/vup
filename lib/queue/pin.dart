import 'dart:async';
import 'dart:io';

import 'package:lib5/lib5.dart';
import 'package:pool/pool.dart';
import 'package:vup/generic/state.dart';
import 'package:vup/model/sync_task.dart';

import 'task.dart';

class PinningQueueTask extends QueueTask {
  @override
  final String id;
  @override
  final List<String> dependencies;
  @override
  final threadPool = 'pin';

  final String remote;
  final List<CID> cids;

  @override
  double get progress => _progress / cids.length;

  int _progress = 0;

  PinningQueueTask({
    required this.id,
    required this.dependencies,
    required this.remote,
    required this.cids,
  });

  bool isCancelled = false;

  final pool = Pool(8);

  @override
  void cancel() {
    isCancelled = true;
  }

  @override
  Future<void> execute() async {
    logger.verbose('pinning ${cids.length} CIDs on $remote');
    final completer = Completer();

    for (final cid in cids) {
      final pins = pinningService.getPinsForHash(
        cid.hash,
      );
      if (!pins.contains(remote)) {
        try {
          if (remote == '_local') {
            pool.withResource(() async {
              if (isCancelled) return;
              await s5Node.pinCID(cid);

              _progress++;

              if (progress == cids.length) completer.complete();
            });
          } else {
            final sc = mySky.storageServiceConfigs
                .firstWhere((e) => e.authority == remote);

            pool.withResource(() async {
              if (isCancelled) return;
              final res = await mySky.httpClient.post(
                sc.getAccountsAPIUrl(
                  '/s5/pin/${cid.toBase64Url()}',
                ),
                headers: sc.headers,
              );
              res.expectStatusCode(200);

              _progress++;

              if (progress == cids.length) completer.complete();
            });
          }
        } catch (e, st) {
          logger.catched(e, st);
        }
      }
    }
    await completer.future;
  }
}
