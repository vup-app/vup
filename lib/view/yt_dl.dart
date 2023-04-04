import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:filesystem_dac/dac.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/dracula.dart';
import 'package:flutter_state_notifier/flutter_state_notifier.dart';
import 'package:path/path.dart';
import 'package:pool/pool.dart';
import 'package:uuid/uuid.dart';
import 'package:vup/app.dart';
import 'package:vup/utils/yt_dl.dart';
import 'package:vup/widget/file_system_entity.dart';

class YTDLDialog extends StatefulWidget {
  final String path;
  const YTDLDialog(this.path, {Key? key}) : super(key: key);

  @override
  _YTDLDialogState createState() => _YTDLDialogState();
}

class _YTDLDialogState extends State<YTDLDialog> {
  bool get _isRunning => _isDownloading || _isFetchingMetadata;
  bool _isDownloading = false;
  bool _isFetchingMetadata = false;

  List<Map> videos = [];
  List<String> selectedVideos = [];

  String format = 'm4a';

  List<String> logOutput = [];

  bool advancedYtDlModeEnabled = false;

  final audioFormats = ['m4a', 'mp3'];

  final _urlCtrl = TextEditingController();

  final _userAgentCtrl = TextEditingController();
  final _browserProfileCtrl = TextEditingController();
  final _maxDownloadThreadsCtrl = TextEditingController(text: '4');
  bool splitByChapters = false;
  bool useParentInfoJsonData = false;
  // final _maxDLCountCtrl = TextEditingController(text: '8');

  final downloadProgress = <String, double?>{};
  final uploadFileIds = <String, Multihash>{};

  int downloadedCount = 0;

  final _scrollCtrl = ScrollController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('YT-DL'),
          if (!_isRunning)
            IconButton(
              onPressed: () {
                context.pop();
              },
              icon: Icon(
                Icons.close,
              ),
            )
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 250,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text('Audio'),
                            SizedBox(
                              height: 4,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                for (final f in audioFormats)
                                  ChoiceChip(
                                    label: Text(f),
                                    selected: format == f,
                                    onSelected: _isRunning
                                        ? null
                                        : (_) {
                                            setState(() {
                                              format = f;
                                            });
                                          },
                                  )
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text('Video'),
                            SizedBox(
                              height: 4,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                for (final f in ['mp4' /* , 'mkv' */])
                                  ChoiceChip(
                                    label: Text(f),
                                    selected: format == f,
                                    onSelected: _isRunning
                                        ? null
                                        : (_) {
                                            setState(() {
                                              format = f;
                                            });
                                          },
                                  )
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Spacer(),
                if (devModeEnabled)
                  Switch(
                    value: advancedYtDlModeEnabled,
                    onChanged: _isRunning
                        ? null
                        : (val) {
                            setState(() {
                              advancedYtDlModeEnabled = val;
                            });
                          },
                  )
              ],
            ),
            SizedBox(
              height: 8,
            ),
            Text(
              '''m4a: usually best quality
mp3: better compatibility''', // mkv: more features
              style: TextStyle(
                fontSize: 14,
              ),
            ),
            SizedBox(
              height: 16,
            ),
            TextField(
              controller: _urlCtrl,
              decoration: InputDecoration(
                labelText: 'URL',
              ),
              autofocus: true,
              maxLines: advancedYtDlModeEnabled ? 3 : null,
              enabled: !_isRunning,
            ),
            if (advancedYtDlModeEnabled) ...[
              SizedBox(
                height: 16,
              ),
              TextField(
                controller: _userAgentCtrl,
                decoration: InputDecoration(
                  labelText: 'Custom user agent',
                ),
                enabled: !_isRunning,
              ),
              SizedBox(
                height: 16,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _maxDownloadThreadsCtrl,
                      decoration: InputDecoration(
                        labelText: 'Max download threads',
                      ),
                      enabled: !_isRunning,
                    ),
                  ),
                  SizedBox(
                    width: 16,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _browserProfileCtrl,
                      decoration: InputDecoration(
                        labelText: 'Extract cookies from browser profile',
                      ),
                      enabled: !_isRunning,
                    ),
                  )
                ],
              ),
              SizedBox(
                height: 16,
              ),
              Row(
                children: [
                  Expanded(
                    child: SwitchListTile(
                        title: Text('Split by chapters'),
                        subtitle: Text(
                          'Split videos in multiple files according to the chapter timestamps',
                        ),
                        value: splitByChapters,
                        onChanged: (val) {
                          setState(() {
                            splitByChapters = val;
                          });
                        }),
                  ),
                  Expanded(
                    child: SwitchListTile(
                        title: Text('Use playlist metadata'),
                        subtitle: Text('Very experimental!'),
                        value: useParentInfoJsonData,
                        onChanged: (val) {
                          setState(() {
                            useParentInfoJsonData = val;
                          });
                        }),
                  )
                ],
              ),
            ],
            /*   SizedBox(
              height: 16,
            ),
            TextField(
              controller: _maxDLCountCtrl,
              decoration: InputDecoration(
                labelText: 'Max download count',
              ),
              enabled: !_isRunning,
              keyboardType: TextInputType.number,
            ), */
            SizedBox(
              height: 16,
            ),
            if (_isFetchingMetadata)
              ListTile(
                leading: CircularProgressIndicator(),
                title: Text('Fetching metadata'),
              ),
            ElevatedButton(
              onPressed: _isRunning
                  ? null
                  : () async {
                      final text = _urlCtrl.text.trim();
                      if (advancedYtDlModeEnabled && text.contains('\n')) {
                        videos = [];
                        selectedVideos = [];

                        for (final url in text.split('\n')) {
                          videos.add({
                            'url': url,
                            'webpage_url': url,
                            'title': url,
                          });
                        }

                        setState(() {});
                        return;
                      }
                      setState(() {
                        _isFetchingMetadata = true;
                      });
                      final process = await Process.start(
                        ytDlPath,
                        [
                          '--dump-json',
                          '--flat-playlist',
                          text,
                        ],
                        // workingDirectory: outDirectory.path,
                      );
                      videos = [];
                      selectedVideos = [];
                      process.stdout
                          .transform(systemEncoding.decoder)
                          .transform(const LineSplitter())
                          .listen((event) {
                        if (event.isNotEmpty) {
                          // logger.verbose('$event');
                          videos.add(json.decode(event.toString()));
                        }
                      });

                      process.stderr
                          .transform(systemEncoding.decoder)
                          .transform(const LineSplitter())
                          .listen((event) {
                        if (event.isNotEmpty) {
                          logOutput.add('$event');
                          // setState(() {});
                        }
                      });

                      final exitCode = await process.exitCode;
                      // if (exitCode != 0) throw 'yt-dlp exit code $exitCode';

                      setState(() {});

                      logger.info('[yt-dlp] total videos: ${videos.length}');

                      setState(() {
                        _isFetchingMetadata = false;
                      });
                    },
              child: Text(
                videos.isEmpty ? 'Fetch metadata' : 'Re-fetch metadata',
              ),
            ),
            if (videos.isNotEmpty) ...[
              Expanded(
                /* height: min(500, MediaQuery.of(context).size.height - 420),
                width: 700, */
                child: ListView.builder(
                  controller: _scrollCtrl,
                  itemCount: videos.length,
                  itemBuilder: (context, index) {
                    final video = videos[index];

                    final url = video['webpage_url'] ?? video['original_url'];

                    final value = selectedVideos.contains(url);

                    void onTap() {
                      if (_isRunning) return;
                      if (value == true) {
                        selectedVideos.remove(url);
                      } else {
                        selectedVideos.add(url);
                      }
                      setState(() {});
                    }

                    var title = video['title'];
                    var subtitle = '';

                    String? thumbnail;

                    if (video['duration'] != null) {
                      subtitle +=
                          '[${renderDuration(video['duration'] + 0.0)}] ';
                    }
                    final uploader = video['uploader'] ?? video['channel'];

                    if (uploader != null) {
                      subtitle += uploader + ' ';
                    }
                    thumbnail ??= video['thumbnail'];

                    if (thumbnail == null) {
                      final list = video['thumbnails'] ?? [];
                      if (list.isNotEmpty) {
                        thumbnail = list.first['url'];
                      }
                    }

                    late Widget trailing;

                    if (downloadProgress.containsKey(url)) {
                      if (downloadProgress[url] == -2) {
                        trailing = Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: Icon(Icons.check_circle_outline),
                        );
                      } else if (downloadProgress[url] == -1) {
                        trailing = StateNotifierBuilder<FileState>(
                          stateNotifier:
                              storageService.dac.getFileStateChangeNotifier(
                            uploadFileIds[url]!,
                          ),
                          builder: (context, state, _) {
                            if (state.type == FileStateType.idle) {
                              return SizedBox();
                            }

                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  iconMap[state.type],
                                  size: 16,
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                                CircularProgressIndicator(
                                  value: state.progress,
                                ),
                              ],
                            );
                          },
                        );
                      } else {
                        trailing = Stack(
                          alignment: Alignment.center,
                          children: [
                            Icon(
                              UniconsLine.cloud_download,
                              size: 16,
                              color: Theme.of(context).primaryColor,
                            ),
                            CircularProgressIndicator(
                              value: downloadProgress[url] ?? 0,
                            ),
                          ],
                        );
                        ;
                      }
                    } else {
                      trailing = Checkbox(
                        value: value,
                        onChanged: _isRunning
                            ? null
                            : (value) {
                                onTap();
                              },
                      );
                    }

                    return ListTile(
                      leading:
                          thumbnail == null ? null : Image.network(thumbnail),
                      title: Text(video['title'] ??
                          video['filename'] ??
                          video['url'] ??
                          url),
                      subtitle: Text(subtitle.trimRight()),
                      onTap: _isRunning ? null : onTap,
                      trailing: trailing,
                    );
                  },
                ),
              ),
              Row(
                children: [
                  Text(
                    _isDownloading
                        ? 'Downloading selected items... (${selectedVideos.length} remaining)' //  (${(downloadedCount / selectedVideos.length * 100).toStringAsFixed(2)})
                        : 'Selected ${selectedVideos.length} / ${videos.length} items',
                  ),
                  Spacer(),
                  TextButton(
                    onPressed: _isRunning
                        ? null
                        : () {
                            setState(() {
                              selectedVideos = [];
                            });
                          },
                    child: Text(
                      'Unselect all',
                    ),
                  ),
                  TextButton(
                    onPressed: _isRunning
                        ? null
                        : () async {
                            final dirIndex = await storageService.dac
                                .getDirectoryMetadataCached(
                              widget.path,
                            )!;
                            final existingUrls = [];
                            for (final file in dirIndex.files.values) {
                              final fileUrl = file.ext?['audio']?['comment'] ??
                                  file.ext?['video']?['comment'];
                              if (fileUrl != null) {
                                existingUrls.add(fileUrl);
                              }
                            }
                            logger.verbose('existingUrls $existingUrls');

                            selectedVideos = [];
                            for (final video in videos) {
                              final url =
                                  video['webpage_url'] ?? video['original_url'];
                              if (!existingUrls.contains(url)) {
                                selectedVideos.add(url);
                              }
                            }
                            setState(() {});
                          },
                    child: Text(
                      'Smart Select (skip if in current dir)',
                    ),
                  ),
                  TextButton(
                    onPressed: _isRunning
                        ? null
                        : () {
                            selectedVideos = [];
                            for (final video in videos) {
                              final url =
                                  video['webpage_url'] ?? video['original_url'];
                              selectedVideos.add(url);
                            }
                            setState(() {});
                          },
                    child: Text(
                      'Select all',
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 16,
              ),
            ],
            if (logOutput.isNotEmpty) ...[
              SizedBox(
                width: 700,
                height: 50,
                child: SingleChildScrollView(
                  reverse: true,
                  child: HighlightView(
                    logOutput.join('\n'),
                    language: 'java',
                    theme: draculaTheme,
                    padding: EdgeInsets.all(12),
                    textStyle: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 16,
              ),
            ],
            if (selectedVideos.isNotEmpty)
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _isRunning
                        ? null
                        : () async {
                            setState(() {
                              downloadedCount = 0;
                              _isDownloading = true;
                            });
                            isCancelled = false;

                            final futures = <Future>[];

                            if (advancedYtDlModeEnabled) {
                              final customThreadCount =
                                  int.tryParse(_maxDownloadThreadsCtrl.text);

                              if (customThreadCount != null) {
                                pool = Pool(customThreadCount);
                              }
                            }

                            for (final url in selectedVideos) {
                              futures.add(
                                pool.withResource(
                                  () => processVideo(
                                    url,
                                    context,
                                  ),
                                ),
                              );
                            }

                            await Future.wait(futures);

                            setState(() {
                              _isDownloading = false;
                            });
                          },
                    child: Text(
                      'Download selected',
                    ),
                  ),
                  Spacer(),
                  if (_isDownloading)
                    ElevatedButton.icon(
                      onPressed: () {
                        isCancelled = true;
                        cancelStream.add(null);
                        context.pop();
                      },
                      icon: Icon(UniconsLine.times),
                      label: Text(
                        'Cancel downloads',
                      ),
                    )
                ],
              )
          ],
        ),
      ),
    );
  }

  var pool = Pool(4);

  final cancelStream = StreamController<Null>.broadcast();
  bool isCancelled = false;

  void processVideo(String url, BuildContext context) async {
    if (isCancelled) return;
    try {
      final additionalArgs = <String>[];
      if (advancedYtDlModeEnabled) {
        final customUserAgent = _userAgentCtrl.text.trim();
        if (customUserAgent.isNotEmpty) {
          additionalArgs.addAll([
            '--user-agent',
            customUserAgent,
          ]);
        }

        final cookieExtractBrowserProfile = _browserProfileCtrl.text.trim();

        if (cookieExtractBrowserProfile.isNotEmpty) {
          additionalArgs.addAll([
            '--cookies-from-browser',
            cookieExtractBrowserProfile,
          ]);
        }

        if (splitByChapters) {
          additionalArgs.addAll([
            '--split-chapters',
          ]);
        }
        if (useParentInfoJsonData) {
          final video = videos.firstWhere(
            (video) => (video['webpage_url'] ?? video['original_url']) == url,
          );
          final tempJsonFile = File(join(
            storageService.temporaryDirectory,
            'yt_dl_info_json_files',
            Uuid().v4() + '.json',
          ));
          tempJsonFile.createSync(recursive: true);
          tempJsonFile.writeAsStringSync(json.encode(video));
          additionalArgs.addAll([
            '--load-info-json',
            tempJsonFile.path,
          ]);
        }
      }
      await YTDLUtils.downloadAndUploadVideo(
        url,
        widget.path,
        format,
        onProgress: (progress) {
          setState(() {
            downloadProgress[url] = progress;
          });
        },
        onUploadIdAvailable: (uploadId) {
          setState(() {
            uploadFileIds[url] = uploadId;
            downloadProgress[url] = -1;
          });
        },
        cancelStream: cancelStream.stream,
        additionalArgs: additionalArgs,
      );
      if (advancedYtDlModeEnabled) {
        if (splitByChapters) {
          final dirIndex = storageService.dac.getDirectoryMetadataCached(
            widget.path,
          )!;
          final files = <FileReference>[];
          for (final file in dirIndex.files.values) {
            if ((file.ext?['audio']?['comment'] ??
                    file.ext?['video']?['comment']) ==
                url) {
              files.add(file);
            }
          }
          final firstFile = files.first;
          final String albumTitle = firstFile.ext?['audio']?['title'] ??
              firstFile.ext?['video']?['title'];

          files.sort((a, b) => -a.name.compareTo(b.name));

          double lastDuration = 0;

          for (final file in files) {
            final mediaExt = file.ext?['audio'] ?? file.ext?['video'];

            final afterTitle =
                file.name.substring(albumTitle.length + 2).trimLeft();
            final track = int.tryParse(afterTitle.split(' ').first);

            final index = afterTitle.indexOf(' ');
            if (index == -1) continue;
            final title = afterTitle
                .substring(index)
                .trimLeft()
                .split('[')
                .first
                .trimRight();
            mediaExt['title'] = title;

            mediaExt['album'] = albumTitle;
            mediaExt.remove('description');
            if (track != null) {
              mediaExt['track'] = '$track';
            }

            final duration = mediaExt['duration'];

            mediaExt['duration'] = duration - lastDuration;

            lastDuration = duration;
            if (file.ext?['audio'] != null) {
              file.ext?['audio'] = mediaExt;
            } else {
              file.ext?['video'] = mediaExt;
            }
            storageService.dac.updateFileExtensionDataAndThumbnail(
              file.uri!,
              file.ext,
              file.file.thumbnail,
            );
          }
        }
      }
      setState(() {
        downloadProgress[url] = -2;
        selectedVideos.remove(url);
        downloadedCount++;
      });
    } catch (e, st) {
      if (isCancelled) return;
      showErrorDialog(context, e, st);
    }
  }
}
