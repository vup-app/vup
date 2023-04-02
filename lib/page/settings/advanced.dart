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

  int? usedCacheSize;
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'ffmpeg paths',
          style: titleTextStyle,
        ),
        SizedBox(
          height: 16,
        ),
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
        ElevatedButton(
          onPressed: () async {
            try {
              final res = await ffMpegProvider.runFFMpeg(['-version']);
              final res2 = await ffMpegProvider.runFFProbe(['-version']);
              showInfoDialog(
                  context, 'ffmpeg version', res.stdout + '\n' + res2.stdout);
            } catch (e, st) {
              showErrorDialog(context, e, st);
            }
          },
          child: Text(
            'Check version',
          ),
        ),
        SizedBox(
          height: 16,
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
          SizedBox(
            height: 16,
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
    );
  }
}
