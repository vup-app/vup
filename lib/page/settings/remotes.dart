/* import 'dart:convert';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:vup/app.dart';

class RemotesSettingsPage extends StatefulWidget {
  const RemotesSettingsPage({Key? key}) : super(key: key);

  @override
  State<RemotesSettingsPage> createState() => _RemotesSettingsPageState();
}

class _RemotesSettingsPageState extends State<RemotesSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ElevatedButton(
          onPressed: () async {
            showLoadingDialog(context, 'Loading remotes.json');
            try {
              await storageService.dac.loadRemotes();
              context.pop();
            } catch (e, st) {
              context.pop();
              showErrorDialog(context, e, st);
            }
          },
          child: Text(
            'Reload',
          ),
        ),
        SizedBox(
          height: 16,
        ),
        ElevatedButton(
          onPressed: () async {
            /*  storageService.dac.customRemotes['rclone'] = {
              "type": "webdav",
              "browsable": true,
              "config": {
                "url": "http://localhost:53100",
                "user": "user",
                "pass": "password"
              }
            }; */
            await showInfoDialog(
              context,
              'Create remote manually',
              'Warning: You can break quite a lot of things with this tool. Please only use it if you know what you\'re doing',
            );
            final res = await showTextInputDialog(
              context: context,
              textFields: [
                DialogTextField(hintText: 'remote id'),
                DialogTextField(hintText: 'config'),
              ],
            );
            if (res != null) {
              try {
                showLoadingDialog(context, 'updating...');
                storageService.dac.customRemotes[res[0]] = json.decode(res[1]);

                await storageService.dac.saveRemotes();
                storageService.dac.loadRemotes();
                context.pop();
                setState(() {});
              } catch (e, st) {
                context.pop();
                setState(() {});
                showErrorDialog(context, e, st);
              }
            }
          },
          child: Text(
            'Create new remote',
          ),
        ),
        SizedBox(
          height: 16,
        ),
        if (storageService.dac.customRemotes.isEmpty)
          Text('You don\'t have any custom remotes in your SkyFS.'),
        for (final id in storageService.dac.customRemotes.keys)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    'id: ' + id,
                  ),
                  SelectableText(
                    '${json.encode(storageService.dac.customRemotes[id])}',
                  ),
                  SizedBox(
                    height: 8,
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final res = await showTextInputDialog(
                        context: context,
                        textFields: [
                          DialogTextField(hintText: 'uri'),
                        ],
                      );
                      try {
                        showLoadingDialog(context, 'updating...');
                        final String uri = res![0];
                        final map = storageService.dac.customRemotes[id]!;
                        map['used_for_uris'] ??= [];

                        map['used_for_uris'].add(uri);

                        storageService.dac.customRemotes[id] = map;

                        await storageService.dac.saveRemotes();
                        storageService.dac.loadRemotes();
                        context.pop();
                        setState(() {});
                      } catch (e, st) {
                        context.pop();
                        setState(() {});
                        showErrorDialog(context, e, st);
                      }
                    },
                    child: Text(
                      'Add SkyFS path',
                    ),
                  ),
                  for (final uri in storageService
                          .dac.customRemotes[id]!['used_for_uris'] ??
                      [])
                    Row(
                      children: [
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SelectableText(uri),
                          ),
                        ),
                        TextButton(
                          onPressed: () async {
                            try {
                              showLoadingDialog(context, 'removing uri...');

                              final map = storageService.dac.customRemotes[id]!;
                              map['used_for_uris'].remove(uri);
                              storageService.dac.customRemotes[id] = map;

                              await storageService.dac.saveRemotes();
                              storageService.dac.loadRemotes();
                              context.pop();
                              setState(() {});
                            } catch (e, st) {
                              context.pop();
                              setState(() {});
                              showErrorDialog(context, e, st);
                            }
                          },
                          child: Text(
                            'Remove',
                          ),
                        )
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
 */