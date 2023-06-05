import 'package:convert/convert.dart';
import 'package:hive/hive.dart';
import 'package:pool/pool.dart';
import 'package:uuid/uuid.dart';
import 'package:vup/app.dart';
import 'package:vup/generic/state.dart';
import 'package:vup/library/state.dart';
import 'package:vup/service/base.dart';

import 'package:vup/service/jellyfin_server/id.dart';

const playlistsPath = 'vup.hns/playlists/all.json';

// TODO Do not use JSON?

class PlaylistService extends VupService with CustomState {
  late final Box<Map> playlists;

  final syncPool = Pool(1);

  Future<void> init() async {
    playlists = await Hive.openBox('playlists');
    if (!playlists.containsKey('favorites')) {
      createPlaylist('Audio', 'Favorites', customId: JellyID.hash('favorites'));
    }
    syncPool.withResource(() => syncPlaylists());

    Stream.periodic(Duration(minutes: 15)).listen((event) {
      syncPool.withResource(() => syncPlaylists());
    });
  }

  void savePlaylist(JellyID id, Map playlist) {
    playlist['modified'] = DateTime.now().millisecondsSinceEpoch;
    playlists.put(id.toString(), playlist);
    // final str = json.encode(id);
    syncPool.withResource(() => syncPlaylists());
  }

  Future<void> syncPlaylists() async {
    info('> syncPlaylists');
    final res = await hiddenDB.getJSON(
      playlistsPath,
    );
    bool hasLocalChanges = false;
    bool hasRemoteChanges = false;

    final Map<String, dynamic> remoteData = res.data ?? {'playlists': {}};

    final processedIds = <String>[];
    for (final id in remoteData['playlists'].keys) {
      processedIds.add(id);
      final remotePlaylist = remoteData['playlists'][id];
      if (playlists.containsKey(id)) {
        final localPlaylist = playlists.get(id)!;
        if (localPlaylist['modified'] > remotePlaylist['modified']) {
          info('sending update for playlist $id');
          remoteData['playlists'][id] = localPlaylist;
          hasRemoteChanges = true;
        } else if (localPlaylist['modified'] < remotePlaylist['modified']) {
          info('received remote update for playlist $id');
          playlists.put(id, remotePlaylist);
          hasLocalChanges = true;
        }
      } else {
        info('received remote update for playlist $id');
        playlists.put(id, remotePlaylist);
        hasLocalChanges = true;
      }
    }
    for (final id in playlists.keys) {
      if (processedIds.contains(id)) continue;
      info('creating remote playlist $id');
      remoteData['playlists'][id] = playlists.get(id)!;
      hasRemoteChanges = true;
    }
    if (hasLocalChanges) {
      $();
    }
    if (hasRemoteChanges) {
      info('updating remote playlists');
      remoteData['ts'] = DateTime.now().millisecondsSinceEpoch;
      remoteData['deviceId'] = dataBox.get('deviceId');

      await hiddenDB.setJSON(
        playlistsPath,
        remoteData,
        revision: res.revision + 1,
      );
    }

    info('< syncPlaylists');
  }

  JellyID createPlaylist(String mediaType, String name, {JellyID? customId}) {
    final id = customId ?? JellyID.fromHex(Uuid().v4().replaceAll('-', ''));

    final ts = DateTime.now().millisecondsSinceEpoch;

    savePlaylist(id, {
      'id': id.toString(),
      'name': name,
      'overview': '',
      'mediaType': mediaType,
      'created': ts,
      'modified': ts,
      'items': [],
    });
    $();
    return id;
  }

  void updatePlaylist(JellyID id, Map changes) {
    final p = playlists.get(id)!;
    for (final key in changes.keys) {
      p[key] = changes[key];
    }
    savePlaylist(id, p);
    $();
  }

  void deletePlaylist(JellyID id) {
    final p = {
      'id': id.toString(),
      'modified': 0,
      'deleted': true,
    };

    savePlaylist(id, p);

    $();
  }

  void addItemsToPlaylist(JellyID playlistId, List<Multihash> ids) {
    final p = playlists.get(playlistId.toString())!;
    for (final id in ids) {
      p['items'].add({'id': id});
    }
    savePlaylist(playlistId, p);
    $();
  }

  void removeItemsFromPlaylist(JellyID playlistId, List<Multihash> ids) {
    final b64Ids = ids.map((e) => e.toBase64Url());

    final p = playlists.get(playlistId.toString())!;
    p['items'].removeWhere((i) => b64Ids.contains(i['id']));

    savePlaylist(playlistId, p);
    $();
  }

  bool isItemOnPlaylist(String playlistId, Multihash? id) {
    return false;
    final p = playlists.get(playlistId)!;
    for (final item in p['items']) {
      if (item['id'] == id?.toBase64Url()) return true;
    }
    return false;
  }
}
