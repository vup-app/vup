import 'package:path/path.dart';
import 'package:vup/app.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vup/utils/detect_icon.dart';
import 'package:vup/widget/user.dart';

class SidebarShortcutWidget extends StatelessWidget {
  final AppLayoutState appLayoutState;
  final String path;
  final String? title;
  final String? icon;
  const SidebarShortcutWidget({
    required this.path,
    required this.appLayoutState,
    this.title,
    Key? key,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final iconSize = 32.0;
    final name = basename(path);
    return InkWell(
      onTap: () {
        appLayoutState.navigateTo(path.split('/'));

        if (context.isMobile) {
          context.pop();
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            /* iconPackService.buildIcon(
              name: widget._entity.name,
              isDirectory: isDirectory,
              iconSize: iconSize,
            ), */
            SvgPicture.asset(
              'assets/vscode-material-icon-theme/${icon ?? detectIcon(
                    name,
                    isDirectory: true,
                  )}.svg',
              width: iconSize,
              height: iconSize,
            ),
            SizedBox(
              width: iconSize / 4,
            ),
            Expanded(
              child: Text(
                title ?? name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: iconSize / 2,
                ),
              ),
            ),
            if (storageService.dac.getPathHost(path) != 'local')
              UserWidget(
                storageService.dac.getPathHost(path),
                profilePictureOnly: true,
              ),
          ],
        ),
      ),
    );
  }
}
