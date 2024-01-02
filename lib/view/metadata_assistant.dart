import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:vup/app.dart';
import 'package:vup/jelly/provider/base.dart';

class MetadataAssistant extends StatefulWidget {
  final String uri;
  final String initialQuery;
  final String mediaType;
  const MetadataAssistant(
    this.uri,
    this.initialQuery, {
    required this.mediaType,
    Key? key,
  }) : super(key: key);

  @override
  _MetadataAssistantState createState() => _MetadataAssistantState();
}

class _MetadataAssistantState extends State<MetadataAssistant> {
  late TextEditingController ctrl;
  @override
  void initState() {
    ctrl = TextEditingController(
      text: widget.initialQuery
          .replaceAll('(OmU)', '')
          .replaceAll(' - ', ' ')
          .trim(),
    );
    availableProviders = providers
        .where((p) => p.supportedTypes.contains(widget.mediaType))
        .toList();

    selectedProvider = availableProviders.first;

    super.initState();

    searchInternal();
  }

  late JellyMetadataProvider selectedProvider;

  List<JellyMetadataProvider> availableProviders = [];

  List<SearchResult>? results;

  int counter = 0;
  void searchDelayed() async {
    counter++;
    final index = counter;
    await Future.delayed(Duration(milliseconds: 500));
    if (index == counter) {
      searchInternal();
    }
  }

  Future<void> searchInternal() async {
    setState(() {
      results = null;
    });
    results = await selectedProvider.search(widget.mediaType, ctrl.text);
    setState(() {});
  }

  Future<void> processId(String type, String providerId, String id) async {
    final provider = providers.firstWhere(
      (p) => p.providerId == providerId,
    );
    final data = await provider.fetchData(id);

    final imageFiles = provider.extractImageFiles(data);

    final index = storageService.dac.getDirectoryMetadataCached(widget.uri) ??
        await storageService.dac.getDirectoryMetadata(widget.uri);

    for (final file in imageFiles) {
      if (index.files.containsKey(file.name)) {
        continue;
      }
      final res = await mySky.httpClient.get(Uri.parse(file.url));
      if (res.statusCode != 200) {
        // TODO handle error
        continue;
      }
      final tempImageFile = File(join(
        storageService.temporaryDirectory,
        'metadata',
        'images',
        Uuid().v4(),
        file.name,
      ));
      tempImageFile.parent.createSync(recursive: true);

      tempImageFile.writeAsBytesSync(res.bodyBytes);

      await storageService.startFileUploadingTask(
        widget.uri,
        tempImageFile,
      );
    }

    final metaFileName = '.media-${type}-${providerId}-${id}.json';

    final tempJsonMetaFile = File(join(
      storageService.temporaryDirectory,
      'metadata',
      'json',
      Uuid().v4(),
      metaFileName,
    ));
    tempJsonMetaFile.parent.createSync(recursive: true);
    tempJsonMetaFile.writeAsStringSync(json.encode(data));

    await storageService.startFileUploadingTask(
      widget.uri,
      tempJsonMetaFile,
      create: !index.files.containsKey(metaFileName),
    );
    final mediaMap = provider.generateJellyMetadata(type, id, data);

    mediaMap['provider'] = {
      'id': provider.providerId,
      'version': provider.providerVersion,
    };
    mediaMap['id'] = id;

    await storageService.dac.updateFileExtensionDataAndThumbnail(
      widget.uri + '/' + metaFileName,
      {
        'media': mediaMap,
      },
      null,
    );
    // Series
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Metadata Assistant (Type: ${widget.mediaType})',
          style: titleTextStyle,
        ),
        SizedBox(
          height: 8,
        ),
        TextField(
          controller: ctrl,
          autofocus: true,
          onChanged: (str) {
            searchDelayed();
          },
        ),
        SizedBox(
          height: 8,
        ),
        Row(
          children: [
            for (final p in availableProviders)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  showCheckmark: false,
                  label: Text(p.providerId),
                  selected: p.providerId == selectedProvider.providerId,
                  onSelected: (val) {
                    if (p.providerId != selectedProvider.providerId) {
                      setState(() {
                        results = [];
                        selectedProvider = p;
                      });

                      searchInternal();
                    }
                  },
                ),
              ),
          ],
        ),
        results == null
            ? Padding(
                padding: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                  ),
                ),
              )
            : Expanded(
                child: ListView.builder(
                  itemCount: results!.length,
                  itemBuilder: (ctx, index) {
                    final sr = results![index];
                    return InkWell(
                      onTap: () async {
                        // context.pop();
                        showLoadingDialog(context, 'Processing metadata...');
                        try {
                          await processId(sr.type, sr.providerId, sr.id);
                          context.pop();
                          context.pop();
                        } catch (e, st) {
                          context.pop();

                          showErrorDialog(context, e, st);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            if (sr.imageUrl != null) ...[
                              Image.network(
                                sr.imageUrl!,
                                height: 100,
                              ),
                              SizedBox(
                                width: 8,
                              ),
                            ],
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(sr.title),
                                  Text(
                                    sr.subtitle,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .textTheme
                                          .caption!
                                          .color,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
      ],
    );
  }
}
