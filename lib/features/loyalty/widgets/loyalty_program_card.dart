import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/models/loyalty_program_model.dart';

class LoyaltyProgramCard extends StatelessWidget {
  final LoyaltyProgramModel program;
  final String companyName;
  final String companyLogo;
  final VoidCallback? onTap;

  const LoyaltyProgramCard({
    super.key,
    required this.program,
    required this.companyName,
    required this.companyLogo,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = program.parsedGradientColors;

    return Container(
      margin: const EdgeInsets.only(top: 14, bottom: 18),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main Card Box
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                colors: colors.length >= 2 ? colors : [colors.first, colors.first],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(22),
                splashColor: Colors.white.withValues(alpha: 0.1),
                highlightColor: Colors.white.withValues(alpha: 0.05),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Header (Logo + Brand + Chevron)
                      _buildCardHeader(),

                const SizedBox(height: 12),

                // Dynamic Earning Rule Text (for visit & amount spent)
                if (program.type != LoyaltyType.cashback) ...[
                  Text(
                    program.earningRule,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Milestone Timeline
                  _buildMilestoneTimeline(),
                  const SizedBox(height: 8),
                ] else ...[
                  // Cashback Extended Section
                  _buildCashbackContent(),
                ],
              ],
            ),
          ),
        ),
      ),
    ),

    // Top Semi-Circular Label Badge Positioned directly on the top border line
    Positioned(
      top: -12,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: BoxDecoration(
            color: colors.first,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.65),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                program.type == LoyaltyType.visitMade
                    ? Icons.storefront_rounded
                    : program.type == LoyaltyType.amountSpent
                        ? Icons.account_balance_wallet_rounded
                        : Icons.currency_exchange_rounded,
                color: Colors.white,
                size: 13,
              ),
              const SizedBox(width: 6),
              Text(
                _badgeTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ],
),
);
}

  String get _badgeTitle {
    switch (program.type) {
      case LoyaltyType.visitMade:
        return 'VISIT MADE';
      case LoyaltyType.amountSpent:
        return 'AMOUNT SPENT';
      case LoyaltyType.cashback:
        return 'CASHBACK';
      case LoyaltyType.custom:
        if (program.title.isNotEmpty && program.title.toLowerCase() != companyName.toLowerCase()) {
          return program.title.toUpperCase();
        }
        return 'VISIT MADE';
    }
  }

  /// Top Branding & Chevron Header Row
  Widget _buildCardHeader() {
    return Row(
      children: [
        // Company Logo / Initial Avatar
        _buildCompanyLogoAvatar(),

        const SizedBox(width: 12),

        // Company Name & Description
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                companyName.isNotEmpty ? companyName.toUpperCase() : 'YOUR BRAND',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                program.description,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Circular Outlined Chevron
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 1.2,
            ),
          ),
          child: const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ],
    );
  }

  /// Dynamic Logo with Placeholder Fallback
  Widget _buildCompanyLogoAvatar() {
    Widget imageContent;

    if (companyLogo.isNotEmpty) {
      if (companyLogo.startsWith('http://') || companyLogo.startsWith('https://')) {
        imageContent = Image.network(
          companyLogo,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackLogo(),
        );
      } else if (File(companyLogo).existsSync()) {
        imageContent = Image.file(
          File(companyLogo),
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildFallbackLogo(),
        );
      } else {
        imageContent = _buildFallbackLogo();
      }
    } else {
      imageContent = _buildFallbackLogo();
    }

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF111827),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: ClipOval(child: imageContent),
    );
  }

  Widget _buildFallbackLogo() {
    final initials = companyName.isNotEmpty
        ? companyName.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join().toUpperCase()
        : 'AP';

    return Container(
      color: const Color(0xFF0F172A),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: Color(0xFFFACC15),
          fontWeight: FontWeight.w900,
          fontSize: 14,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Connected Milestone Progress Timeline
  Widget _buildMilestoneTimeline() {
    final milestones = program.milestones.isNotEmpty
        ? program.milestones
        : [
            RewardMilestoneModel(id: '1', label: '300 Cookie', value: 300),
            RewardMilestoneModel(id: '2', label: '500 Cookie', value: 500),
            RewardMilestoneModel(id: '3', label: '800 Cookie', value: 800),
          ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            // Connecting Horizontal Line
            Positioned(
              top: 15,
              left: 24,
              right: 24,
              child: Container(
                height: 2,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),

            // Milestone Nodes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: milestones.map((m) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cookie/Milestone Icon Node
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.95),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '🍪',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Milestone Label
                    Text(
                      m.label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  /// Extended Cashback Container & Slabs Content
  Widget _buildCashbackContent() {
    final cb = program.cashbackDetails ?? CashbackDetailsModel();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "YOU EARN" Glass Container Box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOU EARN',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                cb.headline,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                cb.subtext,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                cb.termsNote,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 10.5,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                cb.billRewardText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Reward Slabs Header
        const Text(
          'Reward Slabs',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 8),

        // Starter Reward Nested Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cb.slabTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Goal',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    cb.goal,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Reward',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    cb.reward,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Progress Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PROGRESS',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  Text(
                    '${cb.progressPercent.toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Vibrant Gradient Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  height: 6,
                  width: double.infinity,
                  color: Colors.black.withValues(alpha: 0.3),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final rawPct = cb.progressPercent;
                      final safePct = (!rawPct.isNaN && !rawPct.isInfinite && rawPct > 0)
                          ? (rawPct / 100).clamp(0.0, 1.0)
                          : 0.0;
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: constraints.maxWidth * safePct,
                          height: 6,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFFE11D48), // Pink/Rose
                                Color(0xFFF97316), // Orange
                                Color(0xFF06B6D4), // Cyan
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
