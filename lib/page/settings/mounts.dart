/* import 'dart:convert';

import 'package:vup/app.dart';
import 'package:vup/utils/date_format.dart';

class MountsSettingsPage extends StatefulWidget {
  const MountsSettingsPage({Key? key}) : super(key: key);

  @override
  State<MountsSettingsPage> createState() => _MountsSettingsPageState();
}

class _MountsSettingsPageState extends State<MountsSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ElevatedButton(
          onPressed: () async {
            showLoadingDialog(context, 'Loading mounts.json');
            try {
              await storageService.dac.loadMounts();
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
        // TODO Implement
        /* ElevatedButton(
          onPressed: () async {
            await showInfoDialog(
              context,
              'Create mount point manually',
              'Warning: You can break quite a lot of things with this tool. Please only use it when you know what you\'re doing',
            );
            final res = await showDialog(
              context: context,
              textFields: [
                DialogTextField(hintText: 'mount point uri'),
                DialogTextField(hintText: 'uri to mount'),
              ],
            );
            if (res != null) {
              try {
                showLoadingDialog(context, 'mounting...');
                await storageService.dac.mountUri(res[0], Uri.parse(res[1]));
                context.pop();
                setState(() {});
              } catch (e, st) {
                context.pop();
                showErrorDialog(context, e, st);
              }
            }
          },
          child: Text(
            'Create new mount point',
          ),
        ), */
        SizedBox(
          height: 16,
        ),
        if (storageService.dac.mounts.isEmpty)
          Text('You don\'t have any mount points in your SkyFS.'),
        for (final uri in storageService.dac.mounts.keys)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    'mount point: ' + uri,
                  ),
                  SelectableText(
                    'uri: ' + storageService.dac.mounts[uri]!['uri'],
                  ),
                  SelectableText(
                    'created: ' +
                        formatDateTime(DateTime.fromMillisecondsSinceEpoch(
                            storageService.dac.mounts[uri]!['created'])),
                  ),
                  SelectableText(
                    json.encode(storageService.dac.mounts[uri]!['ext']),
                  ),
                  TextButton(
                    onPressed: () async {
                      showLoadingDialog(context, 'Removing mount point...');
                      try {
                        await storageService.dac.unmountUri(uri);
                        context.pop();
                      } catch (e, st) {
                        context.pop();
                        showErrorDialog(context, e, st);
                      }
                      setState(() {});
                    },
                    child: Text(
                      'Remove/unmount',
                    ),
                  )
                ],
              ),
            ),
          ),
      ],
    );
  }
}
 */