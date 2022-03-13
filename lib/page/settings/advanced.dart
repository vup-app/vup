import 'package:vup/app.dart';
import 'package:vup/utils/ffmpeg.dart';

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
