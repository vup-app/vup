import 'dart:io';

import 'package:flutter/material.dart';
import 'package:vup/app.dart';
import 'package:window_manager/window_manager.dart';

import 'bitsdojo_window/window_button.dart';

class WindowButtons extends StatelessWidget {
  const WindowButtons({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      return SizedBox();
    }
    final colors = WindowButtonColors(
      iconNormal: Theme.of(context).colorScheme.onSurface,
    );
    return Row(
      children: [
        MinimizeWindowButton(colors: colors),
        MaximizeWindowButton(colors: colors),
        CloseWindowButton(
          colors: colors,
          onPressed: () {
            isAppWindowVisible = false;
            windowManager.hide();
          },
        ),
      ],
    );
  }
}
