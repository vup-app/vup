import 'dart:io';

import 'package:simple_observable/simple_observable.dart';
import 'package:uuid/uuid.dart';
import 'package:vup/app.dart';
import 'package:vup/service/jellyfin_server.dart';

class JellyfinServerSettingsPage extends StatefulWidget {
  const JellyfinServerSettingsPage({Key? key}) : super(key: key);

  @override
  _JellyfinServerSettingsPageState createState() =>
      _JellyfinServerSettingsPageState();
}

class _JellyfinServerSettingsPageState
    extends State<JellyfinServerSettingsPage> {
  final portCtrl = TextEditingController(text: jellyfinServerPort.toString());
  final bindIpCtrl = TextEditingController(text: jellyfinServerBindIp);
  final usernameCtrl = TextEditingController(text: jellyfinServerUsername);
  final passwordCtrl = TextEditingController(text: jellyfinServerPassword);
  var isPasswordHidden = true;

  late final List<Map> list;

  int? revision;

  @override
  void initState() {
    // list = List.from(dataBox.get('jellyfin_server_collections') ?? []);

    _loadCollections();

    super.initState();
  }

  final hasChanges = Observable(initialValue: false);

  void markChanges() {
    hasChanges.value = true;
  }

  void _loadCollections() async {
    // jellyfinCollectionsPath
    final res = await storageService.dac.mySkyProvider.getJSONEncrypted(
      jellyfinCollectionsPath,
    );

    list = List.from(res.data ?? []).cast<Map>();

    revision = res.revision;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        /*  SizedBox(
          height: 16,
        ), */
        /* SwitchListTile(
          value: isJellyfinServerEnabled,
          title: Text('Jellyfin Server enabled'),
          subtitle: Text(
            'When enabled, a local Jellyfin server is started which supports Music, Movies, TV Shows and Podcasts.',
          ),
          onChanged: jellyfinServerService.isStarting
              ? null
              : (val) async {
                  dataBox.put('jellyfin_server_enabled', val!);
                  if (val) {
                    if (Platform.isAndroid) {
                      await requestAndroidBackgroundPermissions();
                    }
                    setState(() {
                      jellyfinServerService.isStarting = true;
                    });
                    try {
                      await jellyfinServerService.start(
                        jellyfinServerPort,
                        jellyfinServerBindIp,
                        jellyfinServerUsername,
                        jellyfinServerPassword,
                      );
                    } catch (e, st) {
                      showErrorDialog(context, e, st);
                      setState(() {
                        jellyfinServerService.isStarting = false;
                        jellyfinServerService.isRunning = false;
                        dataBox.put('jellyfin_server_enabled', false);
                      });
                    }
                  } else {
                    jellyfinServerService.stop();
                    jellyfinServerService = JellyfinServerService();
                  }
                  if (mounted) setState(() {});
                },
        ), */
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Switch(
                      value: isJellyfinServerEnabled,
                      onChanged: jellyfinServerService.isStarting
                          ? null
                          : (val) async {
                              dataBox.put('jellyfin_server_enabled', val);
                              if (val) {
                                if (Platform.isAndroid) {
                                  await requestAndroidBackgroundPermissions();
                                }
                                setState(() {
                                  jellyfinServerService.isStarting = true;
                                });
                                try {
                                  await jellyfinServerService.start(
                                    jellyfinServerPort,
                                    jellyfinServerBindIp,
                                    jellyfinServerUsername,
                                    jellyfinServerPassword,
                                  );
                                } catch (e, st) {
                                  showErrorDialog(context, e, st);
                                  setState(() {
                                    jellyfinServerService.isStarting = false;
                                    jellyfinServerService.isRunning = false;
                                    dataBox.put(
                                        'jellyfin_server_enabled', false);
                                  });
                                }
                              } else {
                                jellyfinServerService.stop();
                                jellyfinServerService = JellyfinServerService();
                              }
                              if (mounted) setState(() {});
                            },
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      children: [
                        Text(
                          'Jellyfin Server Status: ',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            jellyfinServerService.isStarting
                                ? 'STARTING'
                                : jellyfinServerService.isRunning
                                    ? 'RUNNING'
                                    : 'STOPPED',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (jellyfinServerService.isStarting)
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 8,
                  ),
                ],
              ),
              if (isJellyfinServerEnabled)
                SelectableText(
                  '\nWarning: Authentication is not enforced because some players and API endpoints don\'t fully support it (yet). Please only run the server on localhost (this is the default) to prevent outside connections.\n\nJellyfin server running at http://${jellyfinServerBindIp}:${jellyfinServerPort}\nStop the Jellyfin server if you want to change any settings.',
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: bindIpCtrl,
                  decoration: InputDecoration(
                    labelText: 'Bind IP',
                  ),
                  enabled: !isJellyfinServerEnabled,
                  onChanged: (s) {
                    dataBox.put('jellyfin_server_bindip', s);
                  },
                ),
              ),
              SizedBox(
                width: 16,
              ),
              Expanded(
                child: TextField(
                  controller: portCtrl,
                  decoration: InputDecoration(
                    labelText: 'Port',
                  ),
                  enabled: !isJellyfinServerEnabled,
                  onChanged: (s) {
                    final val = int.tryParse(s);
                    if (val == null) return;
                    if (val < 1000) return;

                    dataBox.put('jellyfin_server_port', val);
                  },
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: usernameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Username',
                  ),
                  enabled: !isJellyfinServerEnabled,
                  onChanged: (s) {
                    dataBox.put('jellyfin_server_username', s);
                  },
                ),
              ),
              SizedBox(
                width: 16,
              ),
              Expanded(
                child: TextField(
                  controller: passwordCtrl,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          isPasswordHidden = !isPasswordHidden;
                        });
                      },
                      icon: Icon(
                        isPasswordHidden
                            ? UniconsLine.eye_slash
                            : UniconsLine.eye,
                      ),
                    ),
                  ),
                  enabled: !isJellyfinServerEnabled,
                  obscureText: isPasswordHidden,
                  onChanged: (s) {
                    dataBox.put('jellyfin_server_password', s);
                  },
                ),
              ),
            ],
          ),
        ),
        if (Platform.isLinux || Platform.isWindows)
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: SwitchListTile(
                  value: richStatusService.isDiscordRPCEnabled,
                  title: Text('Enable Discord RPC'),
                  subtitle: Text(
                    'Integrates with Discord\'s rich presence feature to display the currently playing song, movie or show as your status when using Jellyfin',
                  ),
                  onChanged: (val) {
                    if (richStatusService.isDiscordRPCEnabled) {
                      richStatusService.stop();
                      dataBox.put(
                          'rich_status_service_discord_rpc_enabled', false);
                    } else {
                      // richStatusService.init();
                      dataBox.put(
                          'rich_status_service_discord_rpc_enabled', true);
                    }

                    setState(() {});
                  },
                ),
              ),
              if (richStatusService.isDiscordRPCEnabled)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: CheckboxListTile(
                    value: richStatusService.isDiscordThumbnailsEnabled,
                    title: Text('Show media thumbnails'),
                    subtitle: Text(
                      'When enabled, thumbnails of the media files you are playing are uploaded to Skynet without encryption and shown in your status',
                    ),
                    onChanged: (val) {
                      dataBox.put(
                        'rich_status_service_discord_thumbnails_enabled',
                        val,
                      );
                      setState(() {});
                    },
                  ),
                ),
            ],
          ),
        if (revision == null) ...[
          ListTile(
            leading: CircularProgressIndicator(),
            title: Text('Loading collections...'),
          ),
        ],
        if (revision != null) ...[
          Padding(
            padding: const EdgeInsets.only(
              left: 16.0,
              top: 8,
            ),
            child: Text(
              'Media Collections',
              style: titleTextStyle,
            ),
          ),
          if (!jellyfinServerService.isRunning)
            Wrap(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 8,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton.icon(
                        onPressed: isJellyfinServerEnabled
                            ? null
                            : () {
                                setState(() {
                                  list.add({
                                    'id': Uuid().v4(),
                                  });
                                });
                                markChanges();
                              },
                        icon: Icon(UniconsLine.plus),
                        label: Text('Create collection'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ElevatedButton.icon(
                        onPressed: isJellyfinServerEnabled
                            ? null
                            : () async {
                                showLoadingDialog(context, 'Saving...');
                                try {
                                  await storageService.dac.mySkyProvider
                                      .setJSONEncrypted(
                                    jellyfinCollectionsPath,
                                    list,
                                    revision! + 1,
                                  );
                                  revision = revision! + 1;

                                  dataBox.put(
                                      'jellyfin_server_collections', list);

                                  hasChanges.value = false;

                                  context.pop();
                                } catch (e, st) {
                                  context.pop();
                                  showErrorDialog(context, e, st);
                                }
                                // dataBox.put('jellyfin_server_collections', list);
                              },
                        icon: Icon(UniconsLine.save),
                        label: Text('Save changes'),
                      ),
                    ),
                  ],
                ),
                StreamBuilder(
                  stream: hasChanges.values,
                  builder: (context, snapshot) {
                    if (snapshot.data == true)
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'You have unsaved changes. Remember to save before starting the server.',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      );
                    return SizedBox();
                  },
                ),
              ],
            ),
          SizedBox(
            height: 8,
          ),
          Wrap(
            children: [
              for (final c in list)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 340,
                      height:
                          Theme.of(context).visualDensity.vertical * 4 * 5.5 +
                              278,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            decoration: InputDecoration(
                              labelText: 'Name',
                            ),
                            enabled: !isJellyfinServerEnabled,
                            controller: TextEditingController(text: c['name']),
                            onChanged: (val) {
                              c['name'] = val;
                              markChanges();
                            },
                          ),
                          SizedBox(
                            height: 16,
                          ),
                          DropdownButtonFormField<String>(
                            decoration: InputDecoration(
                              labelText: 'Type',
                            ),
                            value: c['type'],
                            items: [
                              for (final type in [
                                'music',
                                'tvshows',
                                'movies',
                                'books',
                                'mixed',
                              ]) // playlists
                                DropdownMenuItem(
                                  child: Text({
                                        'music': 'Music (music)',
                                        'tvshows': 'TV Shows (tvshows)',
                                        'movies': 'Movies (movies)',
                                        'books': 'Podcasts, Audiobooks (books)',
                                        'mixed': 'Generic folder view (mixed)',
                                      }[type] ??
                                      ''),
                                  value: type,
                                ),
                            ],
                            onChanged: isJellyfinServerEnabled
                                ? null
                                : (value) {
                                    setState(() {
                                      c['type'] = value;
                                    });
                                    markChanges();
                                  },
                          ),
                          SizedBox(
                            height: 16,
                          ),
                          TextField(
                            decoration: InputDecoration(
                              labelText: 'Path',
                            ),
                            enabled: !isJellyfinServerEnabled,
                            controller: TextEditingController(text: c['uri']),
                            onChanged: (val) {
                              c['uri'] = val;
                              markChanges();
                            },
                          ),
                          if (!jellyfinServerService.isRunning) ...[
                            SizedBox(
                              height: 16,
                            ),
                            ElevatedButton.icon(
                              onPressed: isJellyfinServerEnabled
                                  ? null
                                  : () {
                                      setState(() {
                                        list.remove(c);
                                      });
                                      markChanges();
                                    },
                              icon: Icon(UniconsLine.times),
                              label: Text('Delete collection'),
                            ),
                          ]
                          /*   SizedBox(
                        height: 16,
                      ),
                      TextField(
                        decoration: InputDecoration(
                          labelText: 'UUID',
                        ),
                        enabled: !isJellyfinServerEnabled,
                        controller: TextEditingController(text: c['id']),
                        onChanged: (val) {
                          c['id'] = val;
                        },
                      ), */
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          )
        ]
      ],
    );
  }
}
