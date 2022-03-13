import 'dart:io';

import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:flutter/material.dart';

class AppBarWrapper extends StatefulWidget implements PreferredSizeWidget {
  final PreferredSizeWidget child;
  const AppBarWrapper({required this.child, Key? key}) : super(key: key);

  @override
  _AppBarWrapperState createState() => _AppBarWrapperState();

  @override
  Size get preferredSize => child.preferredSize;
}

class _AppBarWrapperState extends State<AppBarWrapper> {
  @override
  Widget build(BuildContext context) {
    if (!(Platform.isWindows || Platform.isLinux)) {
      return widget.child;
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (details) {
        appWindow.startDragging();
      },
      onDoubleTap: () => appWindow.maximizeOrRestore(),
      child: widget.child,
    );
  }
}
