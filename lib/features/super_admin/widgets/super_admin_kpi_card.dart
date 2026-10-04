import 'package:flutter/material.dart';
import '../theme/super_admin_theme.dart';

class SuperAdminKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final double? changePercentage;
  final String comparisonPeriod;
  final IconData icon;
  final Color iconColor;
  final Color? iconBgColor;
  final VoidCallback? onTap;

  const SuperAdminKpiCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.changePercentage,
    this.comparisonPeriod = 'vs previous month',
    required this.icon,
    this.iconColor = SuperAdminTheme.primary,
    this.iconBgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPositive = (changePercentage ?? 0) >= 0;
    final Color trendColor = isPositive ? SuperAdminTheme.success : SuperAdminTheme.danger;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: SuperAdminTheme.neumorphicBox(
          radius: 14,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Title + Icon Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: SuperAdminTheme.textSecondary,
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBgColor ?? iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: iconColor.withValues(alpha: 0.2),
                      width: 1.0,
                    ),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Value
            Text(
              value,
              style: SuperAdminTheme.kpiValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 8),

            // Bottom Trend / Percentage
            if (changePercentage != null)
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: trendColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                          color: trendColor,
                          size: 13,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${isPositive ? "+" : ""}${changePercentage!.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: trendColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      comparisonPeriod,
                      style: const TextStyle(
                        fontSize: 11,
                        color: SuperAdminTheme.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            else if (subtitle != null)
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: SuperAdminTheme.textMuted,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}
