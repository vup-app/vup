const _specialTitlesMap = {
  'skyfs://root/vup.hns/shared-with-me': 'Shared with me',
  'skyfs://root/home/.trash': 'Trash',
};

String? getSpecialTitle(String uri) {
  return _specialTitlesMap[uri];
}
