import 'package:flutter/material.dart';

class SkyButton extends StatelessWidget {
  final String? label;
  final VoidCallback? onPressed;
  final Color color;
  final String? tooltip;
  /* Color hoverColor; */
  final bool filled;

  final bool enabled;

  final Widget? child;

  final double extraHeight;

  SkyButton({
    this.filled = false,
    this.enabled = true,
    this.label,
    this.child,
    required this.color,
    this.onPressed,
    this.tooltip,
    this.extraHeight = 0.0,
  }) {}

  Widget build(BuildContext context) {
    if (filled) {
      final eb = OutlinedButton(
        style: ButtonStyle(
            /*  shape: MaterialStateProperty.all(
              // TODO Check
              RoundedRectangleBorder(borderRadius: borderRadius),
            ), */

            // foregroundColor: MaterialStateProperty.all(color),
            //backgroundColor: MaterialStateProperty.all(color),
            foregroundColor: MaterialStateProperty.all(Colors.white),
            overlayColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.pressed)) {
                return Colors.white.withOpacity(0.3);
              }
            }),
            backgroundColor: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.hovered) ||
                  states.contains(MaterialState.focused)) {
                return color.withOpacity(0.8);
              }
              return color;
            }),
            side: MaterialStateProperty.all(
              BorderSide(
                width: 1,
                color: color,
              ),
            )),
        child: Padding(
          padding: EdgeInsets.all(10.0 + extraHeight / 2),
          child: child ??
              Text(
                label ?? '',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
        ),
        onPressed: onPressed,
      );
      if (tooltip != null) {
        return Tooltip(
          message: tooltip!,
          child: eb,
        );
      }
      return eb;
    }
    final ob = OutlinedButton(
      style: ButtonStyle(
          /*     shape: MaterialStateProperty.all(
            // TODO Check
            RoundedRectangleBorder(borderRadius: borderRadius),
          ), */
          foregroundColor: MaterialStateProperty.all(color),
          overlayColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.pressed)) {
              return color.withOpacity(0.3);
            } else if (states.contains(MaterialState.hovered) ||
                states.contains(MaterialState.focused)) {
              return color.withOpacity(0.1);
            }
          }),
          side: MaterialStateProperty.all(
            BorderSide(
              width: 1,
              color: color,
            ),
          )),
      child: Padding(
        padding: EdgeInsets.all(10.0 + extraHeight / 2),
        child: child ??
            Text(
              label ?? '',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
      ),
      onPressed: onPressed,
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        child: ob,
      );
    }
    return ob;
  }
}
