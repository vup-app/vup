import 'package:convert/convert.dart';
import 'package:filesize/filesize.dart';
import 'package:vup/app.dart';
import 'package:vup/utils/date_format.dart';
import 'package:vup/widget/skylink_health.dart';

class FileDetailsDialog extends StatefulWidget {
  final FileReference file;
  final bool hasWriteAccess;
  const FileDetailsDialog(this.file, {required this.hasWriteAccess, Key? key})
      : super(key: key);

  @override
  FileDetailsDialogState createState() => FileDetailsDialogState();
}

class FileDetailsDialogState extends State<FileDetailsDialog> {
  FileReference get file => widget.file;

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
    final fileVersion = file.file;
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              _buildRow('Name', file.name),
              _buildRow('MIME Type', file.mimeType.toString()),
              _buildRow(
                'Size',
                '${filesize(fileVersion.cid.size)} (${fileVersion.cid.size} bytes)',
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
              for (final hash in [
                fileVersion.cid.hash,
                ...(fileVersion.hashes ?? [])
              ])
                _buildHashRow(hash),
              _buildRow('Original CID', fileVersion.cid.toBase58()),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Encryption',
                    style: titleTextStyle,
                  ),
                ),
              ),
              _buildRow(
                'Type',
                {
                      null: 'None',
                      encryptionAlgorithmXChaCha20Poly1305: 'XChaCha20Poly1305',
                    }[fileVersion.encryptedCID?.encryptionAlgorithm] ??
                    'Unknown',
              ),
              _buildRow(
                'Padding',
                '${filesize(fileVersion.encryptedCID?.padding ?? 0)} (${fileVersion.encryptedCID?.padding} bytes)',
              ),
              _buildRow(
                  'Encrypted blob hash',
                  fileVersion.encryptedCID?.encryptedBlobHash.toBase64Url() ??
                      'None'),

              /*  if (fileVersion.url.startsWith('sia://'))
                Center(
                    child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: SkylinkHealthWidget(fileVersion.url.substring(6)),
                )), */
              _buildRow(
                'Chunk Size',
                '${filesize(fileVersion.encryptedCID?.chunkSize ?? 0)} (${fileVersion.encryptedCID?.chunkSize} bytes)',
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

  Widget _buildHashRow(Multihash hash) {
    /* if (!(hash.startsWith('1220') || hash.startsWith('1114'))) {
      hash = hex.encode(base64UrlNoPaddingDecode(hash));
    } */
    return _buildRow(
        {
              /* '1220': 'SHA256',
              '1114': 'SHA1', */
              mhashBlake3Default: 'BLAKE3',
            }[hash.functionType] ??
            '???',
        hex.encode(hash.hashBytes));
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
