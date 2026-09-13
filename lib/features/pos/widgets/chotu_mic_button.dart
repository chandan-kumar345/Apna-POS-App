import 'package:flutter/material.dart';
import '../../../../core/database/database_service.dart';
import 'chotu_voice_sheet.dart';

class ChotuMicButton extends StatefulWidget {
  final String? tableNumber;
  final VoidCallback? onTranscriptionUpdated;
  final bool isCompact;

  const ChotuMicButton({
    super.key,
    this.tableNumber,
    this.onTranscriptionUpdated,
    this.isCompact = false,
  });

  @override
  State<ChotuMicButton> createState() => _ChotuMicButtonState();
}

class _ChotuMicButtonState extends State<ChotuMicButton> with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _db.addListener(_onDbChanged);
  }

  void _onDbChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _db.removeListener(_onDbChanged);
    _animController.dispose();
    super.dispose();
  }

  void _openChotuSheet() {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 250),
        pageBuilder: (ctx, anim1, anim2) => ChotuVoiceSheet(
          tableNumber: widget.tableNumber,
          onTranscriptionUpdated: widget.onTranscriptionUpdated,
        ),
        transitionsBuilder: (ctx, anim1, anim2, child) => FadeTransition(
          opacity: anim1,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_db.isChotuVoiceEnabled) {
      return const SizedBox.shrink();
    }

    final double size = widget.isCompact ? 36.0 : 42.0;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Tooltip(
        message: 'Chotu AI Voice Assistant',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _openChotuSheet,
            borderRadius: BorderRadius.circular(size / 2),
            splashColor: const Color(0xFF6366F1).withValues(alpha: 0.2),
            highlightColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
            child: SizedBox(
              width: size,
              height: size,
              child: Hero(
                tag: 'chotu_robot_hero',
                child: Image.asset(
                  'assets/images/chotu_robot.png',
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
