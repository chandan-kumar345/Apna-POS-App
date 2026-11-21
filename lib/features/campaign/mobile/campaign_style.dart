import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const ink = Color(0xFF0B1C35);
const muted = Color(0xFF49617A);
const navy = Color(0xFF081F33);
const teal = Color(0xFF08435E);
const borderBlue = Color(0xFFC9DAE8);
const sheetBlue = Color(0xFFEBF4FA);
const rewardStyles = {
  'percentage': (
    'Percentage',
    Icons.percent_rounded,
    Color(0xFF1572C3),
    Color(0xFFDCF0FF),
  ),
  'flat_discount': (
    'Flat discount',
    Icons.currency_rupee_rounded,
    Color(0xFF08763C),
    Color(0xFFDBF8E8),
  ),
  'free_gift': (
    'Free gift',
    Icons.card_giftcard_rounded,
    Color(0xFF7043B6),
    Color(0xFFEDE6FC),
  ),
  'bogo': (
    'BOGO',
    Icons.loyalty_outlined,
    Color(0xFFBE4A30),
    Color(0xFFFFEBE2),
  ),
  'promotional': (
    'Promotional',
    Icons.campaign_outlined,
    Color(0xFF1466A9),
    Color(0xFFDAEDFF),
  ),
};
const studioShadow = BoxShadow(
  color: Color(0x1763829F),
  blurRadius: 8,
  offset: Offset(0, 3),
);
BoxDecoration campaignCard({
  Color color = Colors.white,
  double radius = 14,
  bool shadow = true,
}) => BoxDecoration(
  color: color,
  border: Border.all(color: borderBlue.withValues(alpha: 0.8)),
  borderRadius: BorderRadius.circular(radius),
  boxShadow: shadow ? const [studioShadow] : [],
);

TextStyle campaignText(
  double size, {
  Color color = ink,
  FontWeight weight = FontWeight.w600,
}) => TextStyle(
  fontFamily: 'Roboto',
  fontSize: size,
  height: 1.24,
  fontWeight: weight,
  color: color,
);

class CampaignShell extends StatelessWidget {
  final Widget? header;
  final Widget body;
  final Widget? footer;
  const CampaignShell({
    super.key,
    this.header,
    required this.body,
    this.footer,
  });
  @override
  Widget build(BuildContext context) {
    final theme = ThemeData.light(useMaterial3: true).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: teal,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: header != null ? navy : Colors.transparent,
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      inputDecorationTheme: const InputDecorationTheme(isDense: true),
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: sheetBlue,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Theme(
        data: theme,
        child: Scaffold(
          backgroundColor: header != null ? navy : Colors.transparent,
          body: SafeArea(
            bottom: false,
            top: header != null,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: Column(
                  children: [
                    if (header != null) header!,
                    Expanded(
                      child: ClipRRect(
                        borderRadius: header != null
                            ? const BorderRadius.vertical(
                                top: Radius.circular(28),
                              )
                            : BorderRadius.zero,
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFF9FCFF),
                                sheetBlue,
                                Color(0xFFE2EFF9),
                              ],
                            ),
                          ),
                          child: SafeArea(
                            top: false,
                            child: Column(
                              children: [
                                Expanded(child: body),
                                ?footer,
                              ],
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
        ),
      ),
    );
  }
}

class CampaignPrimary extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool trailing;
  final VoidCallback? onTap;
  const CampaignPrimary(
    this.label, {
    super.key,
    this.icon,
    this.trailing = false,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final glyph = Icon(icon, size: 20);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: onTap == null
              ? const [Color(0xFFD6E1EA), Color(0xFFCAD6E0)]
              : const [Color(0xFF11516C), Color(0xFF052C43)],
        ),
        boxShadow: onTap == null ? null : const [studioShadow],
      ),
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: const Color(0xFF607589),
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          minimumSize: const Size(0, 45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null && !trailing) ...[glyph, const SizedBox(width: 7)],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (icon != null && trailing) ...[const SizedBox(width: 7), glyph],
          ],
        ),
      ),
    );
  }
}

class CampaignLabel extends StatelessWidget {
  final String text;
  const CampaignLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text(text, style: campaignText(14, weight: FontWeight.w700)),
  );
}

InputDecoration campaignInput({String? hint, Widget? suffix}) {
  OutlineInputBorder line(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(11),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: campaignText(14, weight: FontWeight.w400, color: muted),
    counterText: '',
    filled: true,
    fillColor: const Color(0xFFF9FCFF),
    isDense: true,
    suffixIcon: suffix,
    suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    border: line(borderBlue),
    enabledBorder: line(borderBlue),
    focusedBorder: line(const Color(0xFF277DA5)),
  );
}

class CampaignField extends StatelessWidget {
  final String label, value;
  final ValueChanged<String> onChanged;
  final int lines, limit;
  final bool numeric, inline;
  final String? hint;
  final Widget? suffix;
  const CampaignField(
    this.label,
    this.value,
    this.onChanged, {
    super.key,
    this.numeric = false,
    this.inline = false,
    this.lines = 1,
    this.limit = 120,
    this.hint,
    this.suffix,
  });
  @override
  Widget build(BuildContext context) => _LabeledInput(
    label,
    inline,
    TextFormField(
      key: ValueKey(label),
      initialValue: value,
      onChanged: onChanged,
      minLines: lines,
      maxLines: lines,
      maxLength: limit,
      style: campaignText(15, weight: FontWeight.w500),
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : (lines > 1 ? TextInputType.multiline : TextInputType.text),
      inputFormatters: numeric
          ? [
              TextInputFormatter.withFunction(
                (old, next) =>
                    RegExp(r'^\d{0,8}(\.\d{0,2})?$').hasMatch(next.text)
                    ? next
                    : old,
              ),
            ]
          : null,
      decoration: campaignInput(hint: hint, suffix: suffix).copyWith(
        contentPadding: inline
            ? const EdgeInsets.symmetric(horizontal: 9, vertical: 7)
            : null,
      ),
    ),
  );
}

class _LabeledInput extends StatelessWidget {
  final String label;
  final bool inline;
  final Widget input;
  const _LabeledInput(this.label, this.inline, this.input);
  @override
  Widget build(BuildContext context) {
    if (inline && MediaQuery.textScalerOf(context).scale(14) < 20) {
      return Row(
        children: [
          Expanded(flex: 2, child: Text(label, style: campaignText(13))),
          const SizedBox(width: 6),
          Expanded(flex: 4, child: input),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [if (label.isNotEmpty) CampaignLabel(label), input],
    );
  }
}

class CampaignSelect extends StatelessWidget {
  final String label, value, hint;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;
  final bool inline;
  const CampaignSelect(
    this.label,
    this.value,
    this.items,
    this.onChanged, {
    super.key,
    this.hint = 'Select',
    this.inline = false,
  });
  @override
  Widget build(BuildContext context) => _LabeledInput(
    label,
    inline,
    DropdownButtonFormField<String>(
      key: ValueKey('$label/$value'),
      initialValue: items.containsKey(value) ? value : null,
      hint: Text(hint, overflow: TextOverflow.ellipsis),
      isExpanded: true,
      menuMaxHeight: 330,
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(14),
      style: campaignText(15, weight: FontWeight.w500),
      icon: const Icon(Icons.expand_more_rounded, color: ink),
      decoration: campaignInput().copyWith(
        contentPadding: inline
            ? const EdgeInsets.symmetric(horizontal: 9, vertical: 7)
            : null,
      ),
      items: items.entries
          .map(
            (e) => DropdownMenuItem(
              value: e.key,
              child: Text(
                e.value,
                style: campaignText(14, weight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    ),
  );
}

class CampaignIconTile extends StatelessWidget {
  final IconData icon;
  final Color tint, color;
  final double size;
  const CampaignIconTile(
    this.icon,
    this.tint,
    this.color, {
    super.key,
    this.size = 40,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * .27),
      color: tint,
    ),
    child: Icon(icon, color: color, size: size * .58),
  );
}
