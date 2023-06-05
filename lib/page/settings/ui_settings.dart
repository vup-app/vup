import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart';
import 'package:vup/app.dart';

class UISettingsPage extends StatefulWidget {
  const UISettingsPage({Key? key}) : super(key: key);

  @override
  _UISettingsPageState createState() => _UISettingsPageState();
}

class _UISettingsPageState extends State<UISettingsPage> {
  @override
  void initState() {
    if (Platform.isLinux) {
      final appDir = join(storageService.dataDirectory, 'app');
      final appImageGenericLink = Link(join(appDir, 'vup-latest.AppImage'));

      launchAtStartup.setup(
        appName: packageInfo.appName,
        appPath: appImageGenericLink.path,
      );
    } else {
      launchAtStartup.setup(
        appName: packageInfo.appName,
        appPath: Platform.resolvedExecutable,
      );
    }

    super.initState();
  }

  Widget _createTitle(String title, {required BuildContext context}) => Padding(
        padding: const EdgeInsets.only(
          left: 16,
          top: 16,
          bottom: 8,
        ),
        child: Text(
          title,
          style: subTitleTextStyle.copyWith(
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _createTitle(
          'Interface',
          context: context,
        ),
        CheckboxListTile(
          value: isRecursiveDirectorySizesEnabled,
          title: Text('Show directory sizes'),
          subtitle: Text(
            'When enabled, the total size of all files in a directory, including all subdirectories, is calculated and shown. This impacts performance.',
          ),
          onChanged: (val) {
            dataBox.put('recursive_directory_sizes_enabled', val!);

            setState(() {});
          },
        ),
        CheckboxListTile(
          value: isDoubleClickToOpenEnabled,
          title: Text('Double click'),
          subtitle: Text(
            'When enabled, you need to double-click to open files and directories',
          ),
          onChanged: (val) {
            dataBox.put('double_click_enabled', val!);

            setState(() {});
          },
        ),
        CheckboxListTile(
          value: Settings.tabsTitleShowFullPath,
          title: Text('Show full path in tab title'),
          onChanged: (val) {
            dataBox.put('tabs_title_show_full_path', val!);

            setState(() {});
          },
        ),
        CheckboxListTile(
          value: isColumnViewFeatureEnabled,
          title: Text('Enable Column View (Experimental)'),
          subtitle: Text(
            'Adds a new button in the top left to enable a view with 4 linked columns',
          ),
          onChanged: (val) {
            dataBox.put('column_view_enabled', val!);

            setState(() {});
          },
        ),
        if (Platform.isAndroid || Platform.isIOS || Platform.isWindows) ...[
          _createTitle(
            'Security',
            context: context,
          ),
          CheckboxListTile(
            value: Settings.securityIsBiometricAuthenticationEnabled,
            title: Text('Use biometric authentication'),
            subtitle: Text(
              'When enabled, biometric authentication will be required every time you open Vup',
            ),
            onChanged: (val) async {
              if (val == true) {
                if (!(await localAuth.canCheckBiometrics)) {
                  showErrorDialog(context,
                      'Biometrics are not available on this device.', '');
                  return;
                }
                final availableBiometrics =
                    await localAuth.getAvailableBiometrics();

                if (!(availableBiometrics.contains(BiometricType.strong) ||
                    availableBiometrics.contains(BiometricType.face) ||
                    availableBiometrics.contains(BiometricType.fingerprint) ||
                    availableBiometrics.contains(BiometricType.iris))) {
                  showErrorDialog(context,
                      'No auth methods enrolled. $availableBiometrics', '');
                  return;
                }
              }
              dataBox.put('security_biometric_authentication_enabled', val!);

              setState(() {});
            },
          ),
        ],
        _createTitle(
          'Behaviour',
          context: context,
        ),
        CheckboxListTile(
          value: isWatchOpenedFilesEnabled,
          title: Text('Watch opened files'),
          subtitle: Text(
            'When enabled, opened files will be watched for changes and new versions uploaded automatically',
          ),
          onChanged: (val) {
            dataBox.put('watch_opened_files_enabled', val!);

            setState(() {});
          },
        ),
        if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) ...[
          CheckboxListTile(
            value: isStartMinimizedEnabled,
            title: Text('Start minimized'),
            subtitle: Text(
              'When enabled, Vup is minimized to the system tray when launched',
            ),
            onChanged: (val) {
              dataBox.put('start_minimized_enabled', val!);

              setState(() {});
            },
          ),
          FutureBuilder<bool>(
            future: launchAtStartup.isEnabled(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return SizedBox();
              return CheckboxListTile(
                value: snapshot.data,
                title: Text('Launch at startup'),
                subtitle: Text(
                  'When enabled, Vup will be automatically launched with your system',
                ),
                onChanged: (val) async {
                  if (val == true) {
                    await launchAtStartup.enable();
                  } else {
                    await launchAtStartup.disable();
                  }
                  setState(() {});
                },
              );
            },
          ),
        ],
        CheckboxListTile(
          value: isIntegratedAudioPlayerEnabled,
          title: Text('Integrated audio player enabled'),
          subtitle: Text(
            'Not recommended, use the Jellyfin server instead.',
          ),
          onChanged: (val) {
            dataBox.put('integrated_audio_player_enabled', val!);

            setState(() {});
          },
        ),
        CheckboxListTile(
          value: devModeEnabled,
          title: Text('Dev Mode enabled'),
          subtitle: Text(
            'When enabled, more debug information and tools are visible',
          ),
          onChanged: (val) {
            dataBox.put('dev_mode_enabled', val!);

            setState(() {});
          },
        ),
      ],
    );
  }
}
