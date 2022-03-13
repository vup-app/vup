import 'dart:async';

mixin CustomState {
  final _streamCtrl = StreamController<Null>.broadcast();

  Stream<Null> get stream => _streamCtrl.stream;

  void $() {
    _streamCtrl.add(null);
  }
}
