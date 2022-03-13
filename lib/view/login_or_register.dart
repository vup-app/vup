import 'package:vup/app.dart';
import 'package:vup/view/login.dart';
import 'package:vup/view/register.dart';
import 'package:vup/widget/app_bar_wrapper.dart';
import 'package:vup/widget/vup_logo.dart';

class LoginOrRegisterPage extends StatefulWidget {
  @override
  _LoginOrRegisterPageState createState() => _LoginOrRegisterPageState();
}

class _LoginOrRegisterPageState extends State<LoginOrRegisterPage>
    with SingleTickerProviderStateMixin {
  late TabController tabCtrl;

  @override
  void initState() {
    tabCtrl = TabController(
      length: 2,
      vsync: this,
      initialIndex: 1,
    );

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final body = Scaffold(
      appBar: AppBarWrapper(
        child: AppBar(
          title: context.isMobile ? VupLogo() : null,
          toolbarHeight: context.isMobile ? null : 4,
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          bottom: TabBar(
            controller: tabCtrl,
            indicatorWeight: 4,
            labelStyle: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Theme.of(context).textTheme.bodyText1?.color,
            ),
            indicatorColor: Theme.of(context).textTheme.bodyText1?.color,
            labelColor: Theme.of(context).textTheme.bodyText1?.color,
            tabs: [
              Tab(
                text: 'Sign in with MySky',
              ),
              Tab(
                text: 'Register',
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: tabCtrl,
        children: [
          LoginView(tabCtrl),
          RegisterView(tabCtrl),
        ],
      ),
    );
    if (context.isMobile) {
      return body;
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: body,
      ),
    );
  }
}
