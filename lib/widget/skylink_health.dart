/* import 'dart:convert';

import 'package:vup/app.dart';
import 'package:vup/utils/skynet/health_status.dart';

class SkylinkHealthWidget extends StatefulWidget {
  final String skylink;

  const SkylinkHealthWidget(this.skylink, {Key? key}) : super(key: key);

  @override
  State<SkylinkHealthWidget> createState() => _SkylinkHealthWidgetState();
}

class _SkylinkHealthWidgetState extends State<SkylinkHealthWidget> {
  @override
  void initState() {
    _loadData();
    super.initState();
  }

  void _loadData() async {
    _fetch(1);
    _fetch(5);
    _fetch(10);
    _fetch();
  }

  bool isPending = true;

  void _fetch([int? timeout]) async {
    final res = await mySky.skynetClient.httpClient.get(
      Uri.parse(
        // ignore: prefer_interpolation_to_compose_strings
        'https://${mySky.skynetClient.portalHost}/skynet/health/skylink/${widget.skylink}' +
            (timeout == null ? '' : '?timeout=$timeout'),
      ),
    );
    if (timeout == null) isPending = false;
    status = getHealthStatus(
      redundancy: json.decode(res.body)['basesectorredundancy'],
      isPending: isPending,
    );
    setState(() {});
  }

  HealthStatus? status;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'File health on Skynet',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(
              height: 4,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                status?.isPending ?? true
                    ? Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: status?.color,
                          ),
                        ),
                      )
                    : Icon(
                        UniconsLine.check_circle,
                        color: status?.color,
                      ),
                SizedBox(
                  width: 8,
                ),
                if (status != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(status!.label),
                      // Text('redundancy: ${status!.redundancy}'),
                    ],
                  )
              ],
            ),
            SizedBox(
              height: 4,
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  showLoadingDialog(context, 'Pinning skylink...');
                  await storageService.dac.client.pinSkylink(widget.skylink);
                  context.pop();
                  setState(() {
                    isPending = true;
                    status = null;
                  });
                  _loadData();
                } catch (e, st) {
                  context.pop();
                  showErrorDialog(context, e, st);
                }
              },
              child: Text(
                'Pin now',
              ),
            )
          ],
        ),
      ),
    );
  }
}
 */