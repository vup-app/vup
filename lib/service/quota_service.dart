import 'package:filesize/filesize.dart';
import 'package:vup/app.dart';
import 'package:vup/library/state.dart';
import 'package:vup/service/base.dart';

class QuotaService extends VupService with CustomState {
  int usedBytes = 0;
  int totalBytes = 0;
  late Box<Map> historyBox;

  String tooltip = '';

  Future<void> init() async {
    historyBox = await Hive.openBox('stats_history');
  }

  int counter = 0;

  void update() async {
    verbose('update');
    try {
      final stats =
          await storageService.mySkyProvider.client.portalAccount.getStats();
      verbose('stats $stats');
      if (stats['totalUploadsSize'] == null) {
        totalBytes = -1;
        $();
        return;
      }
      final userInfo =
          await storageService.mySkyProvider.client.portalAccount.getUserInfo();

      final limits =
          await storageService.mySkyProvider.client.portalAccount.getLimits();

      final tier = limits['userLimits'][userInfo['tier']];

      tooltip = '$tier\n$stats\n$userInfo';

      tooltip = '';
      tooltip +=
          'Portal: ${mySky.skynetClient.portalHost}\nCurrent tier: ${tier['tierName']}\nSpeeds: ${filesize(tier['uploadBandwidth'])}/s upload, ${filesize(tier['downloadBandwidth'])}/s download\n';
      tooltip += 'Max upload size: ${filesize(tier['maxUploadSize'])}';

      usedBytes = stats['totalUploadsSize'];
      totalBytes = tier['storageLimit'] ?? 0;

      $();
      counter++;
      if (counter >= 10) {
        counter = 0;
        historyBox.put(
            (DateTime.now().millisecondsSinceEpoch / 1000).round(), stats);
      }
    } catch (e, st) {
      print('quota $e $st');
    }
  }
}
