import 'package:filesize/filesize.dart';
import 'package:vup/app.dart';
import 'package:vup/utils/date_format.dart';

class FileDetailsDialog extends StatefulWidget {
  final DirectoryFile file;
  final bool hasWriteAccess;
  const FileDetailsDialog(this.file, {required this.hasWriteAccess, Key? key})
      : super(key: key);

  @override
  FileDetailsDialogState createState() => FileDetailsDialogState();
}

class FileDetailsDialogState extends State<FileDetailsDialog> {
  DirectoryFile get file => widget.file;

  bool hasChanges = false;

  Map<String, dynamic>? ext;

  @override
  void initState() {
    ext = file.ext;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    /* const titleTextStyle = TextStyle(
      text
    ) */
    final extensionRows = [];

    for (final type in (ext?.keys ?? <String>[])) {
      if (ext![type] is! Map) {
        extensionRows.add(
          _buildRow('$type', ext![type].toString()),
        );
      } else {
        for (final key in (ext![type].keys ?? <String>[]))
          extensionRows.add(
            _buildRow(
              '$type.$key',
              ext![type][key].toString(),
              onEdit: ext![type][key] is String && widget.hasWriteAccess
                  ? (str) {
                      ext![type][key] = str;
                      if (!hasChanges) {
                        setState(() {
                          hasChanges = true;
                        });
                      }
                    }
                  : null,
            ),
          );
      }
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              _buildRow('Name', file.name),
              _buildRow('MIME Type', file.mimeType.toString()),
              _buildRow(
                'Size',
                '${filesize(file.file.size)} (${file.file.size} bytes)',
              ),
              _buildRow(
                  'Created',
                  formatDateTime(
                      DateTime.fromMillisecondsSinceEpoch(file.created))),
              _buildRow(
                  'Modified',
                  formatDateTime(
                      DateTime.fromMillisecondsSinceEpoch(file.modified))),
              _buildRow('Version', file.version.toString()),
              _buildRow('Location URI', file.uri.toString()),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Hashes',
                    style: titleTextStyle,
                  ),
                ),
              ),
              for (final hash in [file.file.hash, ...(file.file.hashes ?? [])])
                _buildRow(
                    {
                          '1220': 'SHA256',
                          '1114': 'SHA1',
                        }[hash.substring(0, 4)] ??
                        hash.substring(0, 4),
                    hash.substring(4)),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Encryption',
                    style: titleTextStyle,
                  ),
                ),
              ),
              _buildRow('Type', file.file.encryptionType),
              _buildRow(
                'Padding',
                '${filesize(file.file.padding)} (${file.file.padding} bytes)',
              ),
              _buildRow('Blob URI', file.file.url),
              _buildRow(
                'Chunk Size',
                '${filesize(file.file.chunkSize)} (${file.file.chunkSize} bytes)',
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Extension Data',
                    style: titleTextStyle,
                  ),
                ),
              ),
              ...extensionRows,
            ],
          ),
        ),
        if (hasChanges)
          ElevatedButton(
            onPressed: () async {
              showLoadingDialog(context, 'Updating metadata...');
              try {
                await storageService.dac
                    .updateFileExtensionData(file.uri!, ext);
                context.pop();
              } catch (e, st) {
                context.pop();
                showErrorDialog(context, e, st);
              }
            },
            child: Text(
              'Save metadata changes',
            ),
          ),
      ],
    );
  }

  Widget _buildRow(String label, String value, {Function? onEdit}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Align(
              child: Text(
                label,
                textAlign: TextAlign.end,
              ),
              alignment: Alignment.topRight,
            ),
          ),
          SizedBox(
            width: 8,
          ),
          Expanded(
            child: onEdit == null
                ? SelectableText(value)
                : TextField(
                    controller: TextEditingController(text: value),
                    onChanged: (str) {
                      onEdit(str);
                    },
                  ),
            flex: 3,
          ),
        ],
      ),
    );
  }
}
