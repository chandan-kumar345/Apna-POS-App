import 'package:flutter/material.dart';
import '../../../core/models/loyalty_program_model.dart';
import '../../../core/services/loyalty_service.dart';
import '../widgets/loyalty_program_card.dart';

class LoyaltyDetailsScreen extends StatefulWidget {
  final LoyaltyProgramModel program;
  final String companyName;
  final String companyLogo;
  final VoidCallback? onProgramUpdated;

  const LoyaltyDetailsScreen({
    super.key,
    required this.program,
    required this.companyName,
    required this.companyLogo,
    this.onProgramUpdated,
  });

  @override
  State<LoyaltyDetailsScreen> createState() => _LoyaltyDetailsScreenState();
}

class _LoyaltyDetailsScreenState extends State<LoyaltyDetailsScreen> {
  final LoyaltyService _loyaltyService = LoyaltyService();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _earningRuleCtrl;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.program.title);
    _descCtrl = TextEditingController(text: widget.program.description);
    _earningRuleCtrl = TextEditingController(text: widget.program.earningRule);
    _isActive = widget.program.isActive;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _earningRuleCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProgram() async {
    setState(() => _isSaving = true);
    final updated = LoyaltyProgramModel(
      id: widget.program.id,
      type: widget.program.type,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      earningRule: _earningRuleCtrl.text.trim(),
      rewardCurrency: widget.program.rewardCurrency,
      milestones: widget.program.milestones,
      cashbackDetails: widget.program.cashbackDetails,
      gradientColors: widget.program.gradientColors,
      isActive: _isActive,
      orderIndex: widget.program.orderIndex,
    );

    final success = await _loyaltyService.updateLoyaltyProgram(updated);
    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        widget.onProgramUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loyalty program updated successfully!'),
            backgroundColor: Color(0xFF0D9488),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.program.title,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Live Card Preview
            const Text(
              'Live Card Preview',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            LoyaltyProgramCard(
              program: widget.program,
              companyName: widget.companyName,
              companyLogo: widget.companyLogo,
            ),

            const SizedBox(height: 20),

            // Program Settings Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Program Active Status',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      Switch.adaptive(
                        value: _isActive,
                        activeColor: const Color(0xFF0D9488),
                        onChanged: (val) => setState(() => _isActive = val),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Color(0xFFF1F5F9)),

                  const Text('Program Title', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _titleCtrl,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 14),

                  const Text('Description', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _descCtrl,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),

                  const SizedBox(height: 14),

                  const Text('Earning Rule Rule Definition', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _earningRuleCtrl,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveProgram,
                icon: _isSaving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_rounded, size: 20),
                label: Text(_isSaving ? 'Saving Changes...' : 'Save Configuration'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF051C48),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
