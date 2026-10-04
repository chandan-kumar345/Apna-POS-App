import 'package:flutter/material.dart';
import '../theme/super_admin_theme.dart';

class SuperAdminConfirmationDialog extends StatefulWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final bool requireReason;
  final String reasonHint;
  final Future<void> Function(String reason)? onConfirmWithReason;
  final Future<void> Function()? onConfirm;

  const SuperAdminConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm Action',
    this.confirmColor = SuperAdminTheme.danger,
    this.requireReason = true,
    this.reasonHint = 'Provide justification for this administrative action...',
    this.onConfirmWithReason,
    this.onConfirm,
  });

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm Action',
    Color confirmColor = SuperAdminTheme.danger,
    bool requireReason = true,
    String reasonHint = 'Enter reason...',
    Future<void> Function(String reason)? onConfirmWithReason,
    Future<void> Function()? onConfirm,
  }) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => SuperAdminConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        confirmColor: confirmColor,
        requireReason: requireReason,
        reasonHint: reasonHint,
        onConfirmWithReason: onConfirmWithReason,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<SuperAdminConfirmationDialog> createState() => _SuperAdminConfirmationDialogState();
}

class _SuperAdminConfirmationDialogState extends State<SuperAdminConfirmationDialog> {
  final _reasonController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: SuperAdminTheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: SuperAdminTheme.modalShadow,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title Header with Warning Icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.confirmColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: widget.confirmColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: SuperAdminTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Message Description
            Text(
              widget.message,
              style: const TextStyle(
                fontSize: 13.5,
                color: SuperAdminTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            // Mandatory / Optional Reason Field
            if (widget.requireReason) ...[
              const Text(
                'Action Reason (Logged in Immutable Audit Log)*',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SuperAdminTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _reasonController,
                maxLines: 2,
                style: const TextStyle(fontSize: 13, color: SuperAdminTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: widget.reasonHint,
                  hintStyle: const TextStyle(fontSize: 12.5, color: SuperAdminTheme.textMuted),
                  errorText: _errorText,
                  filled: true,
                  fillColor: SuperAdminTheme.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: SuperAdminTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: widget.confirmColor, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SuperAdminTheme.textSecondary,
                    side: const BorderSide(color: SuperAdminTheme.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.confirmColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          widget.confirmLabel,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleConfirm() async {
    final reason = _reasonController.text.trim();
    if (widget.requireReason && reason.isEmpty) {
      setState(() {
        _errorText = 'Please provide a valid justification reason.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      if (widget.onConfirmWithReason != null) {
        await widget.onConfirmWithReason!(reason);
      } else if (widget.onConfirm != null) {
        await widget.onConfirm!();
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Operation failed: $e';
          _isLoading = false;
        });
      }
    }
  }
}
