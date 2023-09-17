import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vup/widget/move_window.dart';

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
    return MoveWindow(
      child: widget.child,
    );
  }
}
