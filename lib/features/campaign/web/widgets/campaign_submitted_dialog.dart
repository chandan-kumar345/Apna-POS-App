import 'package:flutter/material.dart';
import '../../models/campaign_models.dart';

class CampaignSubmittedDialog extends StatelessWidget {
  final CampaignModel campaign;
  final VoidCallback onViewCampaign;
  final VoidCallback onCreateAnother;

  const CampaignSubmittedDialog({
    super.key,
    required this.campaign,
    required this.onViewCampaign,
    required this.onCreateAnother,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Big Green Checkmark Icon
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x3310B981),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.check_rounded, color: Colors.white, size: 48),
              ),
            ),
            const SizedBox(height: 20),

            // Headline
            const Text(
              'Campaign Submitted!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),

            // Subtitle
            const Text(
              'Your campaign has been scheduled successfully.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            // Campaign Meta Summary Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildMetaRow('Campaign ID', campaign.campaignId, isBold: true),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildMetaRow(
                    'Scheduled Time',
                    campaign.estimatedSendingTime.isNotEmpty
                        ? campaign.estimatedSendingTime
                        : '25 Oct 2026, 11:00 AM',
                  ),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildMetaRow('Total Recipients', '${campaign.audience.recipientCount}'),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildMetaRow(
                    'Estimated Cost',
                    '₹${campaign.cost.totalAmount.toStringAsFixed(2)}',
                    isHighlight: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton(
                      onPressed: onViewCampaign,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        foregroundColor: const Color(0xFF334155),
                      ),
                      child: const Text(
                        'View Campaign',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      onPressed: onCreateAnother,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF95B1C),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Create Another',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaRow(String label, String value, {bool isBold = false, bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold || isHighlight ? FontWeight.w800 : FontWeight.w600,
            color: isHighlight
                ? const Color(0xFFF95B1C)
                : (isBold ? const Color(0xFF0F172A) : const Color(0xFF1E293B)),
          ),
        ),
      ],
    );
  }
}
