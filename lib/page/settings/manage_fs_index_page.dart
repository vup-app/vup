import 'package:vup/app.dart';

class ManageFSIndexPage extends StatefulWidget {
  const ManageFSIndexPage({Key? key}) : super(key: key);

  @override
  _ManageFSIndexPageState createState() => _ManageFSIndexPageState();
}

class _ManageFSIndexPageState extends State<ManageFSIndexPage> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final type in ['audio', 'image', 'video'])
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: () {
                    updateTypeIndex(type);
                  },
                  child: Text(
                    'Update $type index',
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  final _indexedExtKeysWithThumbnail = ['video', 'audio', 'image', 'thumbnail'];

  Future<void> updateTypeIndex(String type) async {
    showLoadingDialog(context, 'Updating $type index...');
    final allFiles = await storageService.dac.getDirectoryIndex(
      'fs-dac.hns/index/all-files',
    );
    context.pop();
    showLoadingDialog(context, 'Processing ${allFiles.files.length} files...');

    final directoryIndex = DirectoryIndex(directories: {}, files: {});

    for (final uri in allFiles.files.keys) {
      final df = allFiles.files[uri]!;

      if (!(df.ext ?? {}).containsKey(type)) {
        continue;
      }

      final extMap = Map.of(df.ext ?? <String, dynamic>{});

      extMap.removeWhere(
          (key, value) => !_indexedExtKeysWithThumbnail.contains(key));

      directoryIndex.files[uri.toString()] = DirectoryFile(
        created: df.created,
        modified: df.modified,
        file: df.file,
        name: df.name,
        version: df.version,
        mimeType: df.mimeType,
        ext: extMap,
      );
    }

    context.pop();
    showLoadingDialog(
      context,
      'Found ${directoryIndex.files.length} $type files...',
    );
    final path = 'fs-dac.hns/index/by-type/$type';

    await storageService.dac.doOperationOnDirectory(
      storageService.dac.parsePath(path),
      (dirIndex) async {
        dirIndex.files = directoryIndex.files;
      },
    );

    context.pop();
  }
}
