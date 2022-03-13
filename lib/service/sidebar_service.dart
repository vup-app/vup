import 'package:vup/app.dart';
import 'package:vup/library/state.dart';
import 'package:vup/service/base.dart';

class SidebarService extends VupService with CustomState {
  final sidebarConfigPath = 'vup.hns/config/sidebar.json';

  Map sidebarConfig = {};

  int? revision;
  void init() {
    sidebarConfig = dataBox.get('sidebar_config') ?? {'locations': []};
    update();
  }

  Future<void> update() async {
    final res = await storageService.dac.mySkyProvider.getJSONEncrypted(
      sidebarConfigPath,
    );
    sidebarConfig =
        Map.from(res.data ?? {'locations': []}).cast<String, dynamic>();

    if (sidebarConfig.isNotEmpty) {
      dataBox.put('sidebar_config', sidebarConfig);
    }

    revision = res.revision;
    $();
  }

  bool isPinned(String path) {
    try {
      sidebarConfig['locations'].firstWhere((e) => e['path'] == path);
      return true;
    } catch (_) {}
    return false;
  }

  Future<void> pinDirectory(String path) async {
    sidebarConfig['locations'].add({'path': path});
    await storageService.dac.mySkyProvider.setJSONEncrypted(
      sidebarConfigPath,
      sidebarConfig,
      revision! + 1,
    );
    revision = revision! + 1;
    dataBox.put('sidebar_config', sidebarConfig);
    $();
  }

  Future<void> unpinDirectory(dynamic entry) async {
    sidebarConfig['locations'].remove(entry);
    await storageService.dac.mySkyProvider.setJSONEncrypted(
      sidebarConfigPath,
      sidebarConfig,
      revision! + 1,
    );
    revision = revision! + 1;
    dataBox.put('sidebar_config', sidebarConfig);
    $();
  }
}
