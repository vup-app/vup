import 'package:vup/app.dart';

class HintCard extends StatelessWidget {
  final GestureTapCallback? onTap;
  final String? title;
  final Widget content;
  final Widget? leading;

  final Color? color;

  final IconData? icon;

  const HintCard({
    // Key key,
    this.onTap,
    this.title,
    required this.content,
    this.icon,
    this.color,
    this.leading,
  }); //: super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: color ?? Theme.of(context).colorScheme.secondary,
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(4),
        color: color?.withOpacity(SkyColors.cardBackgroundColorOpacity),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: color,
                ),
                SizedBox(
                  width: 8,
                ),
              ],
              if (leading != null) ...[
                leading!,
                SizedBox(
                  width: 8,
                ),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null) ...[
                      SizedBox(
                        height: 2,
                      ),
                      Text(
                        title!,
                        style: subTitleTextStyle,
                      ),
                    ],
                    SizedBox(
                      height: 2,
                    ),
                    content,
                    SizedBox(
                      height: 2,
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
