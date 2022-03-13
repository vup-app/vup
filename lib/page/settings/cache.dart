import 'package:filesize/filesize.dart';
import 'package:vup/app.dart';

class CacheSettingsPage extends StatefulWidget {
  const CacheSettingsPage({Key? key}) : super(key: key);

  @override
  _CacheSettingsPageState createState() => _CacheSettingsPageState();
}

class _CacheSettingsPageState extends State<CacheSettingsPage> {
  final maxCacheSizeCtrl = TextEditingController(
    text: cacheService.macCacheSizeInGB.toString(),
  );

  int? usedCacheSize;

  String? validator(String? str) => double.tryParse(str ?? '') == null
      ? 'Please enter a number'
      : double.parse(str ?? '') < 0.5
          ? 'Please enter a higher number'
          : null;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 256,
            child: TextFormField(
              autovalidateMode: AutovalidateMode.always,
              decoration: InputDecoration(
                labelText: 'Max cache size',
                suffixText: 'GB',
              ),
              validator: validator,
              onChanged: (str) {
                if (validator(str) == null) {
                  dataBox.put('cache_max_size', double.parse(str));
                }
              },
              controller: maxCacheSizeCtrl,
            ),
          ),
        ),
        SizedBox(
          height: 16,
        ),
        ElevatedButton(
          onPressed: () async {
            usedCacheSize = await cacheService.calculateUsedCacheSize();
            setState(() {});
          },
          child: Text(
            'Calculate used cache size',
          ),
        ),
        if (usedCacheSize != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Total used cache size: ${filesize(usedCacheSize)}'),
          ),
        SizedBox(
          height: 16,
        ),
        ElevatedButton(
          onPressed: () async {
            await cacheService.runGarbageCollector();
            usedCacheSize = await cacheService.calculateUsedCacheSize();
            setState(() {});
          },
          child: Text(
            'Run garbage collector',
          ),
        ),
      ],
    );
  }
}
