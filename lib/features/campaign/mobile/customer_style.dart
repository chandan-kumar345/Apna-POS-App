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

class CustomerHeader extends StatelessWidget {
  final String title;
  final Widget leading;
  final Widget? trailing;
  final bool isPill;
  const CustomerHeader({
    super.key,
    required this.title,
    required this.leading,
    this.trailing,
    this.isPill = false,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
    child: Row(
      children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: isPill
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: const Color(0xFF477A90)),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF316E84), Color(0xFF0E4B63)],
                      ),
                    ),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: customerText(
                        15,
                        color: Colors.white,
                        weight: FontWeight.w700,
                      ),
                    ),
                  )
                : Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: customerText(
                      17,
                      color: Colors.white,
                      weight: FontWeight.w800,
                    ),
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
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1.1,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    ),
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
    this.size = 36,
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
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14),
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
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 7),
            ] else if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: customerText(
                13.5,
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
      hintStyle: customerText(13, color: customerBlue, weight: FontWeight.w400),
      filled: true,
      fillColor: Colors.white.withValues(alpha: .8),
      prefixIcon: prefix,
      suffixIcon: suffix,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(30),
      color: const Color(0xFFBAF9D4),
      border: Border.all(color: const Color(0xFFD8FFE8)),
    ),
    child: Text(
      text,
      style: customerText(
        11,
        color: const Color(0xFF052B1A),
        weight: FontWeight.w700,
      ),
    ),
  );
}
