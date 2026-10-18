import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../services/sound_service.dart';

/// App-wide widget wrapper that plays click sound strictly on genuine button taps,
/// and guarantees 100% SILENCE during scrolling, dragging, swiping, text editing,
/// or tapping on non-interactive background areas.
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
  final Map<int, Offset> _pointerDownPositions = {};
  final Set<int> _scrollingPointers = {};

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // When any scroll activity begins or updates, mark active pointers as scrolling
        if (notification is ScrollStartNotification || notification is ScrollUpdateNotification) {
          _scrollingPointers.addAll(_pointerDownPositions.keys);
        }
        return false;
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (PointerDownEvent event) {
          if (!SoundService.soundEnabled) return;
          _pointerDownPositions[event.pointer] = event.position;
        },
        onPointerMove: (PointerMoveEvent event) {
          if (!SoundService.soundEnabled) return;
          final downPos = _pointerDownPositions[event.pointer];
          if (downPos != null) {
            final distance = (event.position - downPos).distance;
            if (distance > kTouchSlop) {
              _scrollingPointers.add(event.pointer);
            }
          }
        },
        onPointerUp: (PointerUpEvent event) {
          if (!SoundService.soundEnabled) {
            _pointerDownPositions.remove(event.pointer);
            _scrollingPointers.remove(event.pointer);
            return;
          }
          final downPos = _pointerDownPositions.remove(event.pointer);
          final wasScrolling = _scrollingPointers.remove(event.pointer);

          // If the pointer was scrolling or dragging, NEVER play click sound
          if (wasScrolling == true) return;

          if (downPos != null) {
            final distance = (event.position - downPos).distance;
            if (distance > kTouchSlop) return;
          }

          final view = View.maybeOf(context);
          if (view == null) return;

          final hitTestResult = HitTestResult();
          WidgetsBinding.instance.hitTestInView(
            hitTestResult,
            event.position,
            view.viewId,
          );

          bool isInteractiveButton = false;
          bool isTextField = false;

          for (final entry in hitTestResult.path) {
            final target = entry.target;
            // 1. Text input / editable fields should not trigger button click sounds
            if (target is RenderEditable) {
              isTextField = true;
              break;
            }

            // 2. Standard buttons & InkWell semantics
            if (target is RenderSemanticsAnnotations) {
              final semantics = target.properties;
              // Ignore disabled buttons
              if (semantics.enabled == false) {
                continue;
              }
              if (semantics.button == true ||
                  semantics.onTap != null ||
                  semantics.onLongPress != null) {
                isInteractiveButton = true;
                break;
              }
            }

            // 3. Raw gesture handlers with tap or long press
            if (target is RenderSemanticsGestureHandler) {
              if (target.onTap != null || target.onLongPress != null) {
                isInteractiveButton = true;
                break;
              }
            }
          }

          if (!isTextField && isInteractiveButton) {
            SoundService.playButtonClick();
          }
        },
        onPointerCancel: (PointerCancelEvent event) {
          _pointerDownPositions.remove(event.pointer);
          _scrollingPointers.remove(event.pointer);
        },
        child: widget.child,
      ),
    );
  }
}
