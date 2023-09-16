import 'package:hive/hive.dart';
import 'package:pool/pool.dart';
import 'package:s5_server/node.dart';
import 'package:s5_server/rust/bridge_definitions.dart';
import 'package:state_notifier/state_notifier.dart';
import 'package:vup/app.dart';
import 'package:vup/model/sync_task.dart';
import 'package:vup/queue/queue_service.dart';
import 'package:vup/rust/bridge_definitions_vup.dart';
import 'package:vup/service/activity_service.dart';
import 'package:vup/service/api_server.dart';
import 'package:vup/service/cache.dart';
import 'package:vup/service/directory_cache_sync.dart';
// import 'package:vup/service/identity_dac_server_service.dart';
import 'package:vup/service/jellyfin_server.dart';
import 'package:vup/service/logger.dart';
import 'package:vup/service/mysky.dart';
import 'package:vup/service/notification/provider/base.dart';
import 'package:vup/service/pinning_service.dart';
import 'package:vup/service/playlist_service.dart';
import 'package:vup/service/portal_proxy_server.dart';
import 'package:vup/service/quota_service.dart';
import 'package:vup/service/sidebar_service.dart';
// import 'package:vup/service/skynet_kernel/service.dart';
import 'package:vup/service/storage.dart';
import 'package:vup/service/temporary_streaming_server.dart';
import 'package:vup/service/web_server.dart';
import 'package:vup/service/webdav_server.dart';
import 'package:vup/utils/device_info/base.dart';
import 'package:vup/utils/external_ip/base.dart';
import 'package:vup/utils/ffmpeg/base.dart';

export 'package:vup/utils/expect_status_code.dart';

// Storage
late Box<SyncTask> syncTasks;
late Box<int> syncTasksTimestamps;
late Box<int> syncTasksLock;
late Box dataBox;
late KeyValueDB localFiles;

late String vupConfigDir;
late String vupTempDir;
late String vupDataDir;

// Global Services
final queue = QueueService();
late StorageService storageService;
late final S5Node s5Node;
late final HiddenDBProvider hiddenDB;

late FFmpegProvider ffMpegProvider;
late NotificationProvider notificationProvider;
late ExternalIpAddressProvider externalIpAddressProvider;
late DeviceInfoProvider deviceInfoProvider;
late Rust nativeRustApi;
late RustVup nativeRustVupApi;
final mySky = MySkyService();
final webServerService = WebServerService();
final temporaryStreamingServerService = TemporaryStreamingServerService();
final webDavServerService = WebDavServerService();
final apiServerService = APIServerService();
// final portalProxyServerService = PortalProxyServerService();
// TODO final identityDACServerService = IdentityDACServerService();
// TODO final skynetKernelServerService = SkynetKernelServerService();
final sidebarService = SidebarService();
var jellyfinServerService = JellyfinServerService();
// final koelServerService = KoelServerService();
final quotaService = QuotaService();
final pinningService = PinningService();
final activityService = ActivityService();
final playlistService = PlaylistService();
final directoryCacheSyncService = DirectoryCacheSyncService();
final cacheService = CacheService();

const vupUserAgent = 'vup';

bool isYTDlIntegrationEnabled = false;
String ytDlPath = 'yt-dlp';

final logger = Global();

// Preferences
bool get isWebServerEnabled => dataBox.get('web_server_enabled') ?? false;
int get webServerPort => dataBox.get('web_server_port') ?? 8080;
String get webServerBindIp => dataBox.get('web_server_bindip') ?? '127.0.0.1';

bool get isWebDavServerEnabled => dataBox.get('webdav_server_enabled') ?? false;
int get webDavServerPort => dataBox.get('webdav_server_port') ?? 4040;
String get webDavServerBindIp =>
    dataBox.get('webdav_server_bindip') ?? '127.0.0.1';
String get webDavServerUsername =>
    dataBox.get('webdav_server_username') ?? 'user';
String get webDavServerPassword =>
    dataBox.get('webdav_server_password') ?? 'password';

/* bool get isPortalProxyServerEnabled =>
    dataBox.get('portal_proxy_server_enabled') ?? false; */

/* bool get isKoelServerEnabled => dataBox.get('koel_server_enabled') ?? false;
int get koelServerPort => dataBox.get('koel_server_port') ?? 6060;
String get koelServerEmail =>
    dataBox.get('koel_server_email') ?? 'user@example.com';
String get koelServerPassword =>
    dataBox.get('koel_server_password') ?? 'password'; */

bool get isJellyfinServerEnabled =>
    dataBox.get('jellyfin_server_enabled') ?? false;
int get jellyfinServerPort => dataBox.get('jellyfin_server_port') ?? 8096;
String get jellyfinServerBindIp =>
    dataBox.get('jellyfin_server_bindip') ?? '127.0.0.1';
String get jellyfinServerUsername =>
    dataBox.get('jellyfin_server_username') ?? 'user';
String get jellyfinServerPassword =>
    dataBox.get('jellyfin_server_password') ?? 'password';

int get uploadPoolSize => dataBox.get('upload_pool_size') ?? 8;
int get downloadPoolSize => dataBox.get('download_pool_size') ?? 8;
int get ytDlPoolSize => dataBox.get('media_dl_pool_size') ?? 8;

const jellyfinCollectionsPath = 'vup.hns/config/jellyfin/collections.json';
const customThemesPath = 'vup.hns/config/custom_themes.json';

final scriptsStatus = <String, Map>{};

// Pools
late final Pool downloadPool;

// Error handling
final globalErrorsState = GlobalErrorStateNotifier();

class GlobalErrorStateNotifier
    extends StateNotifier<Map<String, List<String>>> {
  GlobalErrorStateNotifier() : super({});

  void addError(
    dynamic exception,
    dynamic ctx,
  ) {
    final e = exception.toString();
    final globalErrors = Map.of(state);

    if (!globalErrors.containsKey(e)) {
      globalErrors[e] = [];
    }
    globalErrors[e]!.add(ctx.toString());

    state = globalErrors;
  }

  void clear() {
    state = {};
  }
}
