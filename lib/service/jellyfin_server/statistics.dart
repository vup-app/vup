import 'package:vup/generic/state.dart';

String generateStatisticsPage(Map<String, Map> allItems) {
  final artists = <String, int>{};

  for (final key in activityService.playCounts.keys) {
    final item = allItems[key];
    if (item != null) {
      if (item['MediaType'] == 'Audio') {
        for (final artist in item['Artists'] ?? []) {
          artists[artist] = (artists[artist] ?? 0) +
              (activityService.playCounts.get(key)! * item['RunTimeTicks']
                  as int);
        }
      }
    }
  }
  final list = artists.entries.toList();
  list.sort((a, b) => -a.value.compareTo(b.value));
  var html = '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Listening statistics</title>
</head>

<body>
<h1>Listening statistics</h1>
''';

  for (final artist in list) {
    html +=
        '<p>${artist.key}: ${(artist.value / (1000 * 1000 * 10 * 60)).round()} minutes</p>';
  }

  return html +
      '''
</body>
</html>
''';
}
