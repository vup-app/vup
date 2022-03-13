import 'app.dart';

typedef ThemedWidgetBuilder = Widget Function(
  BuildContext context,
  ThemeData theme,
  ThemeData darkTheme,
  ThemeMode themeMode,
);

class AppTheme extends StatefulWidget {
  const AppTheme({
    Key? key,
    required this.themedWidgetBuilder,
  }) : super(key: key);

  final ThemedWidgetBuilder themedWidgetBuilder;

  @override
  AppThemeState createState() => AppThemeState();

  static AppThemeState of(BuildContext context) {
    return context.findAncestorStateOfType<AppThemeState>()!;
  }
}

class AppThemeState extends State<AppTheme> {
  late ThemeMode _themeMode;
  late bool _isBlack;
  late ThemeData _darkThemeData;
  late ThemeData _lightThemeData;

  late String _theme;

  @override
  void initState() {
    super.initState();

    _loadState();
    _updateThemes();

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateThemes();
  }

  @override
  void didUpdateWidget(AppTheme oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateThemes();
  }

  void _loadState() {
    _theme = loadTheme();
    _isBlack = dataBox.get('theme_is_black') ?? false;
  }

  void updateTheme() {
    setState(() {
      _loadState();
      _updateThemes();
    });
  }

  _updateThemes() {
    logger.verbose('updateThemes');
    _themeMode = _theme == 'light'
        ? ThemeMode.light
        : _theme == 'dark'
            ? ThemeMode.dark
            : ThemeMode.system;

    final customThemes = dataBox.get('custom_themes') ?? {};

    final customDarkTheme = dataBox.get('custom_theme_dark');

    if (customDarkTheme == null) {
      _darkThemeData = _buildThemeData(_isBlack ? 'black' : 'dark');
    } else {
      _darkThemeData = _buildThemeDataWithJson(customThemes[customDarkTheme]);
    }

    final customLightTheme = dataBox.get('custom_theme_light');
    if (customLightTheme == null) {
      _lightThemeData = _buildThemeData('light');
    } else {
      _lightThemeData = _buildThemeDataWithJson(customThemes[customLightTheme]);
    }
  }

  String loadTheme() {
    return dataBox.get('theme') ?? 'system';
  }

  final errorColor = Colors.red.value;

  ThemeData _buildThemeDataWithJson(Map config) {
    final accentColor = Color(
      int.tryParse(config['color_accent'] ?? '') ?? errorColor,
    );
    final backgroundColor = Color(
      int.tryParse(config['color_background'] ?? '') ?? errorColor,
    );
    final cardColor = Color(
      int.tryParse(config['color_card'] ?? '') ?? errorColor,
    );
    return _buildCustomThemeData(
      accentColor: accentColor,
      backgroundColor: backgroundColor,
      cardColor: cardColor,
      brightness: backgroundColor.computeLuminance() < 0.5
          ? Brightness.dark
          : Brightness.light,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.themedWidgetBuilder(
      context,
      _lightThemeData,
      _darkThemeData,
      _themeMode,
    );
  }

  ThemeData _buildThemeData(String theme) {
    var _accentColor = Color(0xff1ed660);
    /* = RainbowColorTween([
      Colors.orange,
      Colors.red,
      Colors.blue,
    ]).transform(_controller.value);
 */

    //    Colors.lime;
    //Color(0xffEC1873);
    //Colors.cyan;

    if (theme == 'light') {
      return _buildCustomThemeData(
        accentColor: _accentColor,
        backgroundColor: Color(0xfffafafa),
        cardColor: Color(0xffffffff),
        brightness: Brightness.light,
      );
    } else if (theme == 'dark') {
      return _buildCustomThemeData(
        accentColor: _accentColor,
        backgroundColor: Color(0xff202323),
        cardColor: Color(0xff424242),
        brightness: Brightness.dark,
      );
    } else {
      return _buildCustomThemeData(
        accentColor: _accentColor,
        backgroundColor: Colors.black,
        cardColor: Color(0xff424242),
        brightness: Brightness.dark,
      );
    }
  }

  ThemeData _buildCustomThemeData({
    required Color accentColor,
    required Color backgroundColor,
    required Color cardColor,
    required Brightness brightness,
  }) {
    var themeData = ThemeData(
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: accentColor,
      ),
      brightness: brightness,
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: MaterialStateProperty.all(accentColor),
      ),
      colorScheme: ColorScheme.light(
        brightness: brightness,
        primary: accentColor,
        secondary: accentColor,
        /*      onBackground: Colors.red,
        onPrimary: Colors.red,
        onSecondary: Colors.red,
        onSurface: Colors.red, */
        /*     background: Colors.red,
        surface: Colors.red, */
      ),
      fontFamily: (dataBox.get('custom_font') ?? '').isEmpty
          ? null
          : dataBox.get('custom_font'),
      hintColor:
          brightness == Brightness.dark ? Colors.grey[500] : Colors.grey[500],

      primaryColor: accentColor,

      visualDensity: VisualDensity.adaptivePlatformDensity,
      toggleableActiveColor: accentColor,
      highlightColor: accentColor,

      // hintColor: _accentColor,
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
      ),
      buttonTheme: ButtonThemeData(
        textTheme: ButtonTextTheme.primary,
        buttonColor: accentColor,
      ),
      // TODO High-contrast mode dividerColor: Colors.white,

      textTheme: TextTheme(
        button: TextStyle(color: accentColor),
        subtitle1: TextStyle(
          // fontSize: 100,
          fontWeight: FontWeight.w500,
        ),
      ),
      /* .apply(
        bodyColor: Color(0xff0d0d0d),
        displayColor: Color(0xff0d0d0d),
      ), */
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(),
        focusColor: accentColor,
        fillColor: accentColor,
        enabledBorder: brightness == Brightness.light
            ? null
            : OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.white,
                ),
              ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: accentColor,
        secondaryLabelStyle: TextStyle(
          color: Colors.black,
        ),
      ),
      appBarTheme: AppBarTheme(
        color: Colors.white,
        titleTextStyle: TextStyle(
          color: Colors.black,
          fontSize: 20,
        ),
        foregroundColor: Colors.black,
      ),
    );

    themeData = themeData.copyWith(
      appBarTheme: brightness == Brightness.dark
          ? AppBarTheme(
              color: Colors.black,
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
              ),
              foregroundColor: Colors.white,
            )
          : null,
      backgroundColor: backgroundColor,
      scaffoldBackgroundColor: backgroundColor,
      dialogBackgroundColor: backgroundColor,
      canvasColor: backgroundColor,
      cardColor: cardColor,
    );

    return themeData;
  }
}
