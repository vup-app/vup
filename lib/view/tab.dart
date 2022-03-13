import 'package:multi_split_view/multi_split_view.dart';
import 'package:vup/app.dart';
import 'package:vup/main.dart';
import 'package:vup/view/browse.dart';

class TabView extends StatelessWidget {
  final int tabIndex;
  TabView({
    required this.tabIndex,
  }) : super(key: ValueKey('tab-$tabIndex'));

  late MultiSplitViewController splitCtrl;

  void initSplitCtrl() {
    splitCtrl = MultiSplitViewController();
  }

  @override
  Widget build(BuildContext context) {
    return MultiSplitViewTheme(
      data: MultiSplitViewThemeData(
        dividerThickness: 4,
        dividerPainter: DividerPainters.background(
          color: Theme.of(context).dividerColor,
        ),
      ),
      child: StreamBuilder<Null>(
        stream: appLayoutState.stream,
        builder: (context, snapshot) {
          initSplitCtrl();
          return MultiSplitView(
            controller: splitCtrl,
            minimalSize: 300,
            children: [
              for (final view in appLayoutState.tabs[tabIndex])
                BrowseView(
                  pathNotifier: view.state,
                ),
            ],
          );
        },
      ),
    );
  }
}
