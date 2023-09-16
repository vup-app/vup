import 'dart:io';

import 'package:vup/app.dart';
import 'package:vup/utils/ffmpeg/base.dart';
import 'package:vup/utils/ffmpeg_installer.dart';

class AdvancedSettingsPage extends StatefulWidget {
  const AdvancedSettingsPage({Key? key}) : super(key: key);

  @override
  _AdvancedSettingsPageState createState() => _AdvancedSettingsPageState();
}

class _AdvancedSettingsPageState extends State<AdvancedSettingsPage> {
  final ffmpegPathCtrl = TextEditingController(text: ffmpegPath);
  final ffprobePathCtrl = TextEditingController(text: ffprobePath);

  final uploadPoolSizeCtrl =
      TextEditingController(text: uploadPoolSize.toString());

  final downloadPoolSizeCtrl =
      TextEditingController(text: downloadPoolSize.toString());

  final ytDlPoolSizeCtrl = TextEditingController(text: ytDlPoolSize.toString());

  int? usedCacheSize;
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(0),
      children: [
        createSettingsTitle(
          'FFmpeg',
          context: context,
        ),
        SizedBox(
          height: 8,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'ffmpeg path',
                ),
                controller: ffmpegPathCtrl,
                onChanged: (str) {
                  dataBox.put('ffmpeg_path', str);
                },
              ),
              SizedBox(
                height: 16,
              ),
              TextField(
                decoration: InputDecoration(
                  labelText: 'ffprobe path',
                ),
                controller: ffprobePathCtrl,
                onChanged: (str) {
                  dataBox.put('ffprobe_path', str);
                },
              ),
              SizedBox(
                height: 16,
              ),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final res =
                            await ffMpegProvider.runFFMpeg(['-version']);
                        final res2 =
                            await ffMpegProvider.runFFProbe(['-version']);
                        showInfoDialog(context, 'ffmpeg version',
                            res.stdout + '\n' + res2.stdout);
                      } catch (e, st) {
                        showErrorDialog(context, e, st);
                      }
                    },
                    child: Text(
                      'Check version',
                    ),
                  ),
                  if (Platform.isWindows || Platform.isLinux) ...[
                    ElevatedButton(
                      onPressed: () async {
                        showLoadingDialog(
                          context,
                          'Downloading and installing latest FFmpeg...',
                        );
                        try {
                          await downloadAndInstallFFmpeg();
                          context.pop();
                          ffmpegPathCtrl.text = dataBox.get('ffmpeg_path');
                          ffprobePathCtrl.text = dataBox.get('ffprobe_path');
                        } catch (e, st) {
                          context.pop();
                          showErrorDialog(context, e, st);
                        }
                      },
                      child: Text(
                        'Run ffmpeg installer',
                      ),
                    ),
                  ],
                  ElevatedButton(
                    onPressed: () {
                      dataBox.put('ffmpeg_path', 'ffmpeg');
                      dataBox.put('ffprobe_path', 'ffprobe');
                      ffmpegPathCtrl.text = 'ffmpeg';
                      ffprobePathCtrl.text = 'ffprobe';
                    },
                    child: Text(
                      'Reset to defaults',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        createSettingsTitle(
          'Pools',
          context: context,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: TextField(
                  controller: uploadPoolSizeCtrl,
                  decoration: InputDecoration(
                    labelText: 'Upload Pool Size',
                  ),
                  onChanged: (s) {
                    final val = int.tryParse(s);
                    if (val == null) return;
                    if (val < 1) return;
                    dataBox.put('upload_pool_size', val);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: TextField(
                  controller: downloadPoolSizeCtrl,
                  decoration: InputDecoration(
                    labelText: 'Download Pool Size',
                  ),
                  onChanged: (s) {
                    final val = int.tryParse(s);
                    if (val == null) return;
                    if (val < 1) return;
                    dataBox.put('download_pool_size', val);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: TextField(
                  controller: ytDlPoolSizeCtrl,
                  decoration: InputDecoration(
                    labelText: 'Media DL Pool Size',
                  ),
                  onChanged: (s) {
                    final val = int.tryParse(s);
                    if (val == null) return;
                    if (val < 1) return;
                    dataBox.put('media_dl_pool_size', val);
                  },
                ),
              ),
            ],
          ),
        ),
        createSettingsTitle(
          'Developer Mode',
          context: context,
        ),
        CheckboxListTile(
          value: devModeEnabled,
          title: Text('Developer Mode enabled'),
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
