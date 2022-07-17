// Inspired by this excellent piece of software: https://github.com/krateng/maloja

const delimiters_feat = {
  "ft.",
  "ft",
  "feat.",
  "feat",
  "featuring",
  "Ft.",
  "Ft",
  "Feat.",
  "Feat",
  "Featuring"
};

const delimiters = {"vs.", "vs", "Vs.", "Vs", "&"};

const delimiters_formal = {";", "/", "|", "␝", "␞", "␟", ','};

// TODO Use rules from https://github.com/krateng/maloja/tree/master/maloja/data_files/config/rules/predefined

class MetadataCleanup {
  static List<String> parseArtists(String a) {
    // TODO Invalid artists

    // TODO Ignore artists

    if (a.trim().isEmpty) {
      return [];
    }

    if (a.toLowerCase().contains(' performing ')) {
      return parseArtists(a.split(RegExp(r' [Pp]erforming'))[0]);
    }

    // TODO Rules: Belong together
    // TODO Rules: Replace artist

    for (final d in delimiters_feat) {
      final match = RegExp(r"(.*) [\(\[]" + d + r" (.*)[\)\]]").firstMatch(a);
      if (match != null) {
        return parseArtists(match.group(1)!) + parseArtists(match.group(2)!);
      }
    }

    for (final d in [...delimiters_feat, ...delimiters]) {
      if (a.contains(' $d ')) {
        final ls = <String>[];
        for (final i in a.split(" $d ")) {
          ls.addAll(parseArtists(i));
        }
        return ls;
      }
    }
    for (final d in delimiters_formal) {
      if (a.contains(d)) {
        final ls = <String>[];
        for (final i in a.split(d)) {
          ls.addAll(parseArtists(i));
        }
        return ls;
      }
    }

    return [a.trim()];
  }
}
