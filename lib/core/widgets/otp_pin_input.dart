import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Unified 4-Digit OTP Pin Input Widget
/// Provides seamless physical keyboard typing on Desktop/Web and soft keyboard on Mobile,
/// with automatic full-paste handling, backspace support, and glowing visual focus borders.
class OtpPinInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const OtpPinInput({
    super.key,
    required this.controller,
    required this.focusNode,
    this.length = 4,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<OtpPinInput> createState() => _OtpPinInputState();
}

class _OtpPinInputState extends State<OtpPinInput> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleUpdate);
    widget.focusNode.addListener(_handleUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleUpdate);
    widget.focusNode.removeListener(_handleUpdate);
    super.dispose();
  }

  void _handleUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final isFocused = widget.focusNode.hasFocus;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!widget.focusNode.hasFocus) {
          widget.focusNode.requestFocus();
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 4 Styled Semi-Circle Pill Boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(widget.length, (index) {
              final isFilled = index < text.length;
              final isCurrent = isFocused && (index == text.length || (index == widget.length - 1 && text.length == widget.length));
              final char = isFilled ? text[index] : '';

              return Container(
                width: 56,
                height: 56,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? const Color(0xFFF0F9FF)
                      : isFilled
                          ? const Color(0xFFF8FAFC)
                          : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isCurrent
                        ? const Color(0xFF0052FF)
                        : isFilled
                            ? const Color(0xFF00C2FF)
                            : const Color(0xFFE2E8F0),
                    width: isCurrent ? 2.0 : 1.5,
                  ),
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0052FF).withValues(alpha: 0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    char,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              );
            }),
          ),

          // Invisible Full-Width TextField capturing all keystrokes, paste events, and backspaces
          Positioned.fill(
            child: Opacity(
              opacity: 0.0,
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                showCursor: false,
                enableInteractiveSelection: true,
                onChanged: (val) {
                  widget.onChanged?.call(val);
                  if (val.length == widget.length) {
                    widget.onSubmitted?.call(val);
                  }
                },
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '',
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
