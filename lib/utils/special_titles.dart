const _specialTitlesMap = {
  'skyfs://local/fs-dac.hns/vup.hns/.internal/shared-with-me': 'Shared with me',
  'skyfs://local/fs-dac.hns/home/.trash': 'Trash',
};

String? getSpecialTitle(String uri) {
  return _specialTitlesMap[uri];
}
