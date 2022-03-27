import 'dart:convert';

import 'package:uuid/uuid.dart';
import 'package:vup/scripts/actions/yt_dl.dart';
import 'package:vup/app.dart';

class ScriptsSettingsPage extends StatefulWidget {
  const ScriptsSettingsPage({Key? key}) : super(key: key);

  @override
  _ScriptsSettingsPageState createState() => _ScriptsSettingsPageState();
}

class _ScriptsSettingsPageState extends State<ScriptsSettingsPage> {
  late final List scripts;
  @override
  void initState() {
    scripts = json.decode(dataBox.get('scripts') ?? '[]');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          for (final script in scripts)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Name',
                      ),
                      controller: TextEditingController(text: script['name']),
                      onChanged: (val) {
                        script['name'] = val;
                      },
                    ),
                    SizedBox(
                      height: 16,
                    ),
                    StatefulBuilder(builder: (context, sState) {
                      final id = script['id'];
                      final isRunning = scriptsStatus.containsKey(id);
                      return Row(
                        children: [
                          if (isRunning) ...[
                            CircularProgressIndicator(),
                            SizedBox(
                              width: 16,
                            ),
                          ],
                          ElevatedButton(
                            onPressed: isRunning
                                ? null
                                : () async {
                                    scriptsStatus[id] = {};
                                    sState(() {});
                                    for (final a in script['actions']) {
                                      final action = YTDLAction();
                                      await action.run(a['config']);
                                    }
                                    scriptsStatus.remove(id);
                                    sState(() {});
                                  },
                            child: Text(
                              'Run script',
                            ),
                          ),
                        ],
                      );
                    }),
                    SizedBox(
                      height: 16,
                    ),
                    Text('Actions'),
                    for (final action in script['actions'])
                      Column(
                        children: [
                          SizedBox(
                            height: 16,
                          ),
                          TextField(
                            decoration: InputDecoration(
                              labelText: 'Type',
                            ),
                            controller:
                                TextEditingController(text: action['type']),
                            onChanged: (val) {
                              action['type'] = val;
                            },
                          ),
                          SizedBox(
                            height: 8,
                          ),
                          for (final key in [
                            'url',
                            'format',
                            'targetURI',
                          ])
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: TextField(
                                decoration: InputDecoration(
                                  labelText: key,
                                ),
                                controller: TextEditingController(
                                    text: action['config'][key]),
                                onChanged: (val) {
                                  action['config'][key] = val;
                                },
                              ),
                            ),
                        ],
                      )
                  ],
                ),
              ),
            ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  dataBox.put('scripts', json.encode(scripts));
                },
                child: Text(
                  'Save',
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            scripts.add({
              "name": "Download Skynet YT Videos :)",
              "id": Uuid().v4(),
              "devices": [dataBox.get('deviceId')],
              /*   "trigger": {
                "type": "cron",
                "config": {"schedule": "0 15 * * *"}
              }, */
              /*  "conditions": [
                {
                  "type": "platform",
                  "config": {
                    "allowed": ["linux", "windows", "macos"]
                  }
                }
              ], */
              "actions": [
                {
                  "type": "yt_dl",
                  "config": {
                    "url":
                        "https://www.youtube.com/playlist?list=PLPv00ttW4uXPFBidbogIAVe0HdOBDqZeB",
                    "format": "mp4",
                    "targetURI": "skyfs://local/fs-dac.hns/home/Videos/Skynet"
                  }
                }
              ]
            });
          });
        },
        child: Icon(Icons.add),
      ),
    );
  }
}
