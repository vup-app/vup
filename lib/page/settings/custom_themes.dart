import 'package:uuid/uuid.dart';
import 'package:vup/app.dart';
import 'package:vup/theme.dart';

class CustomThemesSettingsPage extends StatefulWidget {
  const CustomThemesSettingsPage({Key? key}) : super(key: key);

  @override
  _CustomThemesSettingsPageState createState() =>
      _CustomThemesSettingsPageState();
}

class _CustomThemesSettingsPageState extends State<CustomThemesSettingsPage> {
  late final Map<String, Map> customThemes;

  int? revision;

  @override
  void initState() {
    _loadCustomThemes();
    super.initState();
  }

  void _loadCustomThemes() async {
    final res = await storageService.dac.hiddenDB.getJSON(
      customThemesPath,
    );

    customThemes = Map.from(res.data ?? {}).cast<String, Map>();

    // return dataBox.get('theme') ?? 'system';

    if (customThemes.isNotEmpty) {
      dataBox.put('custom_themes', customThemes);
    }

    revision = res.revision;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (revision != null) ...[
          Text(
            'Theme selection',
            style: titleTextStyle,
          ),
          SizedBox(
            height: 16,
          ),
          DropdownButtonFormField<String?>(
            decoration: InputDecoration(
              labelText: 'Custom light theme',
            ),
            value: dataBox.get('custom_theme_light'),
            items: [
              DropdownMenuItem(
                child: Text('Default'),
                value: null,
              ),
              for (final id in customThemes.keys)
                DropdownMenuItem(
                  child: Text(customThemes[id]!['name']),
                  value: id,
                ),
            ],
            onChanged: (value) {
              setState(() {
                dataBox.put('custom_theme_light', value);
              });
              AppTheme.of(context).updateTheme();
            },
          ),
          SizedBox(
            height: 16,
          ),
          DropdownButtonFormField<String?>(
            decoration: InputDecoration(
              labelText: 'Custom dark theme',
            ),
            value: dataBox.get('custom_theme_dark'),
            items: [
              DropdownMenuItem(
                child: Text('Default'),
                value: null,
              ),
              for (final id in customThemes.keys)
                DropdownMenuItem(
                  child: Text(customThemes[id]!['name']),
                  value: id,
                ),
            ],
            onChanged: (value) {
              setState(() {
                dataBox.put('custom_theme_dark', value);
              });
              AppTheme.of(context).updateTheme();
            },
          ),
          SizedBox(
            height: 16,
          ),
          TextField(
            decoration: InputDecoration(
              labelText: 'Custom Font',
            ),
            controller: TextEditingController(text: dataBox.get('custom_font')),
            onChanged: (val) {
              dataBox.put('custom_font', val);
              AppTheme.of(context).updateTheme();
            },
          ),
          SizedBox(
            height: 16,
          ),
        ],
        Text(
          'Custom themes',
          style: titleTextStyle,
        ),
        if (revision == null) ...[
          const ListTile(
            leading: CircularProgressIndicator(),
            title: Text('Loading custom themes...'),
          ),
        ],
        if (revision != null) ...[
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      customThemes[Uuid().v4()] = {
                        'name': 'My awesome theme',
                        'color_accent': '0xff1ed660',
                        'color_background': '0xcf000000',
                        'color_card': '0xcfff0000',
                        'background_image_url': '',
                      };
                    });
                  },
                  icon: Icon(UniconsLine.plus),
                  label: Text('Create custom theme'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    showLoadingDialog(context, 'Saving...');
                    try {
                      await storageService.dac.hiddenDB.setJSON(
                        customThemesPath,
                        customThemes,
                        revision: revision! + 1,
                      );
                      revision = revision! + 1;
                      dataBox.put('custom_themes', customThemes);

                      AppTheme.of(context).updateTheme();
                      context.pop();
                    } catch (e, st) {
                      context.pop();
                      showErrorDialog(context, e, st);
                    }
                  },
                  icon: Icon(UniconsLine.save),
                  label: Text('Save changes'),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 8,
          ),
          for (final id in customThemes.keys) _buildCustomThemeSettings(id),
        ]
      ],
    );
  }

  Card _buildCustomThemeSettings(String id) {
    final c = customThemes[id]!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Name',
              ),
              controller: TextEditingController(text: c['name']),
              onChanged: (val) {
                c['name'] = val;
              },
            ),
            SizedBox(
              height: 16,
            ),
            TextField(
              decoration: InputDecoration(
                labelText: 'color_accent',
              ),
              controller: TextEditingController(text: c['color_accent']),
              onChanged: (val) {
                c['color_accent'] = val;
              },
            ),
            SizedBox(
              height: 16,
            ),
            TextField(
              decoration: InputDecoration(
                labelText: 'color_background',
              ),
              controller: TextEditingController(text: c['color_background']),
              onChanged: (val) {
                c['color_background'] = val;
              },
            ),
            SizedBox(
              height: 16,
            ),
            TextField(
              decoration: InputDecoration(
                labelText: 'color_card',
              ),
              controller: TextEditingController(text: c['color_card']),
              onChanged: (val) {
                c['color_card'] = val;
              },
            ),
            const SizedBox(
              height: 16,
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'background_image_url',
              ),
              controller:
                  TextEditingController(text: c['background_image_url'] ?? ''),
              onChanged: (val) {
                c['background_image_url'] = val;
              },
            ),
          ],
        ),
      ),
    );
  }
}
