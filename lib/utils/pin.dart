import 'package:vup/app.dart';

Future<void> pinAll(BuildContext context, String uri) async {
  throw UnimplementedError();
/*   showLoadingDialog(context, 'Aggregating skylinks...');
  try {
    logger.info('aggregateAllSkylinks'); // TODO Ignore non-Skylinks
    final map = await storageService.dac.aggregateAllSkylinks(
      startDirectory: uri,
      registryFetchDelay: 1200,
    );
    logger.info(map.values.fold<Map>({}, (previousValue, element) {
      previousValue[element] = (previousValue[element] ?? 0) + 1;
      return previousValue;
    }));

    context.pop();
    showLoadingDialog(context, 'Found ${map.length} used skylinks..');
    final res = await storageService.dac.client.portalAccount
        .getUploadsList(pageSize: 1000000);

    final Set<String> pinned = Set<String>();
    for (final skylink in res['items']) {
      pinned.add(skylink['skylink']);
    }
    final Set<String> unpinnedSkylinks = {};
    for (final usedSkylink in map.keys) {
      if (!pinned.contains(usedSkylink)) {
        unpinnedSkylinks.add(usedSkylink);
      }
    }

    // await Future.delayed(Duration(seconds: 5));

    int i = 0;
    for (final skylink in unpinnedSkylinks) {
      context.pop();
      showLoadingDialog(
        context,
        'Pinning ${unpinnedSkylinks.length - i} unpinned skylinks... (${map.length} total)',
      );
      logger.info('pin $skylink');
      await storageService.dac.client.pinSkylink(skylink);
      i++;
    }

    context.pop();
    showInfoDialog(context, 'Pinning completed!',
        'Pinned a total of $i skylinks to your ${mySky.skynetClient.portalHost} account.');
  } catch (e, st) {
    context.pop();
    showErrorDialog(context, e, st);
  } */
}
