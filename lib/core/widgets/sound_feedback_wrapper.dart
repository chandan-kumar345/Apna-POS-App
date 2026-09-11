import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../services/sound_service.dart';

/// App-wide widget wrapper that plays click sound strictly on genuine button taps & text inputs,
/// and guarantees 100% SILENCE during scrolling, dragging, swiping, or pan gestures.
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
  final Map<int, Offset> _pointerDownPositions = {};
  final Set<int> _scrollingPointers = {};

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
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // When any scroll activity begins or updates, mark active pointers as scrolling
        if (notification is ScrollStartNotification || notification is ScrollUpdateNotification) {
          _scrollingPointers.addAll(_pointerDownPositions.keys);
        }
        return false;
      },
      child: Listener(
        onPointerDown: (PointerDownEvent event) {
          _pointerDownPositions[event.pointer] = event.position;
        },
        onPointerMove: (PointerMoveEvent event) {
          final downPos = _pointerDownPositions[event.pointer];
          if (downPos != null) {
            final distance = (event.position - downPos).distance;
            if (distance > kTouchSlop) {
              _scrollingPointers.add(event.pointer);
            }
          }
        },
        onPointerUp: (PointerUpEvent event) {
          final downPos = _pointerDownPositions.remove(event.pointer);
          final wasScrolling = _scrollingPointers.remove(event.pointer);

          // If the pointer was scrolling or dragging, NEVER play click sound!
          if (wasScrolling == true) return;

          if (downPos != null) {
            final distance = (event.position - downPos).distance;
            if (distance > kTouchSlop) return;
          }

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
        onPointerCancel: (PointerCancelEvent event) {
          _pointerDownPositions.remove(event.pointer);
          _scrollingPointers.remove(event.pointer);
        },
        child: widget.child,
      ),
    );
  }
}
