import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';
import '../../models/super_admin_subscription_model.dart';
import '../../services/super_admin_api_service.dart';

class SuperAdminPlansScreen extends StatefulWidget {
  const SuperAdminPlansScreen({super.key});

  @override
  State<SuperAdminPlansScreen> createState() => _SuperAdminPlansScreenState();
}

class _SuperAdminPlansScreenState extends State<SuperAdminPlansScreen> {
  @override
  Widget build(BuildContext context) {
    final api = SuperAdminApiService();

    return ListenableBuilder(
      listenable: api,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Create Plan Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('SaaS Subscription Plans', style: SuperAdminTheme.h1),
                      SizedBox(height: 4),
                      Text('Configure tiered pricing, feature limits, and enabled modules for client businesses.', style: SuperAdminTheme.body),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showPlanDialog(context, api, null),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Create New Plan'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SuperAdminTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Plans Grid (Section 12: Subscription Plans)
              LayoutBuilder(
                builder: (context, constraints) {
                  final crossAxisCount = constraints.maxWidth > 1100 ? 3 : (constraints.maxWidth > 700 ? 2 : 1);
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: 0.76,
                    ),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: api.plans.length,
                    itemBuilder: (context, idx) {
                      final plan = api.plans[idx];
                      return _buildPlanCard(context, api, plan);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlanCard(BuildContext context, SuperAdminApiService api, SubscriptionPlan plan) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: SuperAdminTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: plan.isPopular ? SuperAdminTheme.primary : SuperAdminTheme.border,
          width: plan.isPopular ? 2.0 : 1.2,
        ),
        boxShadow: SuperAdminTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(plan.name, style: SuperAdminTheme.h2),
              if (plan.isPopular)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: SuperAdminTheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('MOST POPULAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(plan.description, style: SuperAdminTheme.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 16),

          // Price Tag
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('₹${plan.monthlyPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: SuperAdminTheme.textPrimary)),
              const Text(' / month', style: TextStyle(fontSize: 12.5, color: SuperAdminTheme.textMuted)),
            ],
          ),
          Text('Annual billing: ₹${plan.yearlyPrice.toStringAsFixed(0)} / year', style: const TextStyle(fontSize: 11.5, color: SuperAdminTheme.textSecondary, fontWeight: FontWeight.w600)),
          const Divider(height: 24, color: SuperAdminTheme.border),

          // Limits & Features
          _buildFeatureRow(Icons.person_rounded, 'Max Users: ${plan.maxUsers} active accounts'),
          _buildFeatureRow(Icons.store_rounded, 'Max Outlets: ${plan.maxBranches} branches'),
          _buildFeatureRow(Icons.receipt_rounded, 'Order Volume: ${plan.maxOrdersPerMonth} orders/mo'),
          _buildFeatureRow(Icons.cloud_rounded, 'Cloud Storage: ${plan.storageLimitGb} GB'),
          _buildFeatureRow(Icons.verified_user_rounded, '${plan.enabledModules.length} Enterprise Modules enabled'),
          const Spacer(),

          // Bottom Subscriber Count & Action Buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: SuperAdminTheme.bg, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Active Subscribers:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SuperAdminTheme.textSecondary)),
                Text('${plan.subscribersCount} businesses', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: SuperAdminTheme.primary)),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showPlanDialog(context, api, plan),
                  icon: const Icon(Icons.edit_rounded, size: 15),
                  label: const Text('Edit Plan'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SuperAdminTheme.primary,
                    side: const BorderSide(color: SuperAdminTheme.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18, color: SuperAdminTheme.textSecondary),
                tooltip: 'Duplicate Plan',
                onPressed: () {
                  final copy = plan.copyWith(name: '${plan.name} (Copy)', monthlyPrice: plan.monthlyPrice + 100);
                  api.createPlan(copy);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan duplicated successfully')));
                },
              ),
              IconButton(
                icon: Icon(plan.isActive ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 18, color: plan.isActive ? SuperAdminTheme.success : SuperAdminTheme.danger),
                tooltip: plan.isActive ? 'Active on Pricing Page' : 'Hidden / Archived',
                onPressed: () => api.togglePlanStatus(plan.id),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        children: [
          Icon(icon, size: 15, color: SuperAdminTheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: SuperAdminTheme.textPrimary))),
        ],
      ),
    );
  }

  void _showPlanDialog(BuildContext context, SuperAdminApiService api, SubscriptionPlan? plan) {
    final nameCtrl = TextEditingController(text: plan?.name ?? '');
    final descCtrl = TextEditingController(text: plan?.description ?? '');
    final priceCtrl = TextEditingController(text: plan?.monthlyPrice.toStringAsFixed(0) ?? '1499');
    final yearPriceCtrl = TextEditingController(text: plan?.yearlyPrice.toStringAsFixed(0) ?? '14999');
    final usersCtrl = TextEditingController(text: '${plan?.maxUsers ?? 5}');
    final branchesCtrl = TextEditingController(text: '${plan?.maxBranches ?? 1}');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(plan == null ? 'Create SaaS Plan' : 'Edit Plan: ${plan.name}'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Plan Name')),
                const SizedBox(height: 10),
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Monthly Price (₹)'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: yearPriceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Yearly Price (₹)'))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: usersCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max Users'))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: branchesCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Max Branches'))),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (plan == null) {
                final newP = SubscriptionPlan(
                  id: 'plan_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  monthlyPrice: double.tryParse(priceCtrl.text) ?? 1499,
                  quarterlyPrice: (double.tryParse(priceCtrl.text) ?? 1499) * 2.8,
                  yearlyPrice: double.tryParse(yearPriceCtrl.text) ?? 14999,
                  maxUsers: int.tryParse(usersCtrl.text) ?? 5,
                  maxBranches: int.tryParse(branchesCtrl.text) ?? 1,
                  enabledModules: const ['posBilling', 'inventory', 'reports'],
                );
                api.createPlan(newP);
              } else {
                final upd = plan.copyWith(
                  name: nameCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  monthlyPrice: double.tryParse(priceCtrl.text),
                  yearlyPrice: double.tryParse(yearPriceCtrl.text),
                  maxUsers: int.tryParse(usersCtrl.text),
                  maxBranches: int.tryParse(branchesCtrl.text),
                );
                api.updatePlan(upd);
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan saved successfully'), backgroundColor: SuperAdminTheme.success));
            },
            style: ElevatedButton.styleFrom(backgroundColor: SuperAdminTheme.primary, foregroundColor: Colors.white),
            child: const Text('Save Plan'),
          ),
        ],
      ),
    );
  }
}
