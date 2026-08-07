import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../services/sound_service.dart';

/// App-wide widget wrapper that detects clicks on buttons and text fields via hit-testing.
/// Guarantees click sound plays on all buttons, steppers (+/-), add to cart, and inputs,
/// while keeping empty background spaces 100% silent.
class SoundFeedbackWrapper extends StatefulWidget {
  final Widget child;

  const SoundFeedbackWrapper({
    super.key,
    required this.child,
  });

  @override
  State<SoundFeedbackWrapper> createState() => _SoundFeedbackWrapperState();
}

class _SoundFeedbackWrapperState extends State<SoundFeedbackWrapper> {
  FocusNode? _lastFocusedNode;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    final currentFocus = FocusManager.instance.primaryFocus;
    if (currentFocus != null && currentFocus != _lastFocusedNode) {
      if (currentFocus.context?.widget is EditableText) {
        SoundService.playKeyPress();
      }
      _lastFocusedNode = currentFocus;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (PointerDownEvent event) {
        final hitTestResult = HitTestResult();
        final viewId = View.of(context).viewId;
        WidgetsBinding.instance.hitTestInView(
          hitTestResult,
          event.position,
          viewId,
        );

        bool isInteractive = false;
        bool isTextField = false;

        for (final entry in hitTestResult.path) {
          final target = entry.target;
          if (target is RenderEditable) {
            isTextField = true;
            break;
          }
          if (target is RenderSemanticsAnnotations) {
            final semantics = target.properties;
            if (semantics.button == true ||
                semantics.onTap != null ||
                semantics.onLongPress != null) {
              isInteractive = true;
              break;
            }
          }
          if (target is RenderSemanticsGestureHandler) {
            if (target.onTap != null || target.onLongPress != null) {
              isInteractive = true;
              break;
            }
          }
        }

        if (isTextField) {
          SoundService.playKeyPress();
        } else if (isInteractive) {
          SoundService.playButtonClick();
        }
      },
      child: widget.child,
    );
  }
}
