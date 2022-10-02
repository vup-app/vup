import 'package:flutter_advanced_segment/flutter_advanced_segment.dart';
import 'package:vup/app.dart';
import 'package:vup/theme.dart';

class ThemeSwitch extends StatefulWidget {
  const ThemeSwitch({Key? key}) : super(key: key);

  @override
  _ThemeSwitchState createState() => _ThemeSwitchState();
}

class _ThemeSwitchState extends State<ThemeSwitch> {
  final valueNotifier = ValueNotifier<String>(dataBox.get('theme') ?? 'system');

  @override
  void initState() {
    valueNotifier.addListener(() {
      dataBox.put('theme', valueNotifier.value);
      AppTheme.of(context).updateTheme();
    });
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          child: AdvancedSegment(
            controller: valueNotifier,
            segments: {
              'light': 'Light',
              'system': 'System',
              'dark': 'Dark',
            },
            activeStyle: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
            ),
            backgroundColor:
                Theme.of(context).colorScheme.secondary.withOpacity(0.4),
            sliderColor: Theme.of(context).colorScheme.secondary,
          ),
        ),
        CheckboxListTile(
          value: dataBox.get('theme_is_black') ?? false,
          onChanged: (val) {
            dataBox.put('theme_is_black', val);
            AppTheme.of(context).updateTheme();
          },
          title: Text('Black/AMOLED theme'),
        ),
      ],
    );
  }
}
