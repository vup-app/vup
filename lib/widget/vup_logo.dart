import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class VupLogo extends StatelessWidget {
  final Alignment alignment;
  const VupLogo({this.alignment = Alignment.center, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      Theme.of(context).brightness == Brightness.dark
          ? 'assets/images/vup-logo-dark.svg'
          : 'assets/images/vup-logo-light.svg',
      alignment: alignment,
      height: 38,
    );
  }
}
