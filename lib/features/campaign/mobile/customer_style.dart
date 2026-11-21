import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'campaign_style.dart';

const customerInk = Color(0xFF080D2D);
const customerBlue = Color(0xFF153F60);
const customerGreen = Color(0xFF078A36);
const customerPurple = Color(0xFF8034DF);

TextStyle customerText(
  double size, {
  Color color = customerInk,
  FontWeight weight = FontWeight.w600,
}) => TextStyle(fontSize: size, color: color, fontWeight: weight, height: 1.2);

BoxDecoration customerCard({List<Color>? colors, double radius = 18}) =>
    BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colors ?? const [Color(0xFFFDFEFF), Color(0xFFECF6FF)],
      ),
      border: Border.all(color: Colors.white.withValues(alpha: .95)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x2682B7D4),
          blurRadius: 6,
          offset: Offset(0, 3),
        ),
      ],
    );

class CustomerShell extends StatelessWidget {
  final Widget header, body;
  final Widget? footer;
  const CustomerShell({
    super.key,
    required this.header,
    required this.body,
    this.footer,
  });
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: const Color(0xFFE1F3FF),
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
    child: Theme(
      data: ThemeData.light(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: teal),
        scaffoldBackgroundColor: navy,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF001D2D),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 840),
                  child: header,
                ),
              ),
              Expanded(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFE9F7FF),
                        Color(0xFFDFF1FD),
                        Color(0xFFEBF8FF),
                      ],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 840),
                        child: Column(
                          children: [
                            const SizedBox(height: 9),
                            Container(
                              width: 34,
                              height: 4,
                              decoration: BoxDecoration(
                                color: const Color(0xFFB2D2E6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            Expanded(child: body),
                            ?footer,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ApnaPosTopBar extends StatelessWidget {
  final String storeName;
  final VoidCallback? onStoreTap;
  final VoidCallback? onNotificationTap;

  const ApnaPosTopBar({
    super.key,
    this.storeName = 'Pizza 47',
    this.onStoreTap,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // APNA POS Logo Badge (Circular with amber border)
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF071422),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFF59E0B),
                width: 1.5,
              ),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'APNA',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFF59E0B),
                      height: 1.0,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'POS',
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.0,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Center: Store Selector Pill "Pizza 47 ▼"
          InkWell(
            onTap: onStoreTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F3E57),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF265D7D)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    storeName,
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_drop_down_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Right: Notification Bell Button with Red Dot Badge
          InkWell(
            onTap: onNotificationTap,
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F3E57),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF265D7D)),
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CustomerHeader extends StatelessWidget {
  final String title;
  final Widget leading;
  final Widget? trailing;
  const CustomerHeader({
    super.key,
    required this.title,
    required this.leading,
    this.trailing,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    child: Row(
      children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    ),
  );
}

class CustomerHeaderButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const CustomerHeaderButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onTap,
    tooltip: tooltip,
    icon: Icon(icon, color: Colors.white, size: 22),
  );
}

class CustomerIconTile extends StatelessWidget {
  final IconData icon;
  final Color color, background;
  final double size;
  const CustomerIconTile({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    this.size = 46,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * .23),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(background, Colors.white, .3)!, background],
      ),
    ),
    child: Icon(icon, color: color, size: size * .58),
  );
}

class CustomerPrimary extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  const CustomerPrimary(
    this.label, {
    super.key,
    this.icon,
    this.onPressed,
    this.busy = false,
  });
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(40),
      border: Border.all(color: Colors.white),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: onPressed == null
            ? const [Color(0xFF86A6B8), Color(0xFF63889E)]
            : const [Color(0xFF216B83), Color(0xFF004056), Color(0xFF002E43)],
      ),
      boxShadow: const [studioShadow],
    ),
    child: FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white70,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: const StadiumBorder(),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy) ...[
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 9),
            ] else if (icon != null) ...[
              Icon(icon, size: 26),
              const SizedBox(width: 10),
            ],
            Text(
              label,
              style: customerText(
                18,
                color: Colors.white,
                weight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}

InputDecoration customerInput(String hint, {Widget? prefix, Widget? suffix}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: customerText(15, color: customerBlue, weight: FontWeight.w400),
      filled: true,
      fillColor: Colors.white.withValues(alpha: .8),
      prefixIcon: prefix,
      suffixIcon: suffix,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF62AFD4)),
      ),
    );

class CustomerPill extends StatelessWidget {
  final String text;
  const CustomerPill(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(30),
      color: const Color(0xFFBAF9D4),
      border: Border.all(color: const Color(0xFFD8FFE8)),
    ),
    child: Text(
      text,
      style: customerText(
        12,
        color: const Color(0xFF052B1A),
        weight: FontWeight.w700,
      ),
    ),
  );
}
