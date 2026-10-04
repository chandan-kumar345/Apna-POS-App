import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';
import '../../services/super_admin_api_service.dart';
import '../../models/super_admin_module_model.dart';
import '../../widgets/super_admin_confirmation_dialog.dart';

class SuperAdminModulesScreen extends StatefulWidget {
  const SuperAdminModulesScreen({super.key});

  @override
  State<SuperAdminModulesScreen> createState() => _SuperAdminModulesScreenState();
}

class _SuperAdminModulesScreenState extends State<SuperAdminModulesScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final api = SuperAdminApiService();

    return ListenableBuilder(
      listenable: api,
      builder: (context, _) {
        final allModules = api.modules;
        final categories = ['All', ...allModules.map((m) => m.category).toSet()];

        final filtered = allModules.where((m) {
          final query = _searchQuery.toLowerCase();
          final matchesSearch = query.isEmpty ||
              m.name.toLowerCase().contains(query) ||
              m.description.toLowerCase().contains(query) ||
              m.key.toLowerCase().contains(query);
          final matchesCategory = _selectedCategory == 'All' || m.category == _selectedCategory;
          return matchesSearch && matchesCategory;
        }).toList();

        final globallyActiveCount = allModules.where((m) => m.isGloballyEnabled).length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Banner
              _buildHeader(context, globallyActiveCount, allModules.length),
              const SizedBox(height: 24),

              // Filter & Search Controls
              _buildFilterBar(context, categories),
              const SizedBox(height: 20),

              // Modules Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth > 900;
                  final crossAxisCount = isDesktop ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
                  final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount;

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: filtered.map((mod) {
                      return SizedBox(
                        width: itemWidth,
                        child: _buildModuleCard(context, mod, api),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, int activeCount, int totalCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SuperAdminTheme.cardDecoration(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SuperAdminTheme.purpleAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.extension_rounded, color: SuperAdminTheme.purpleAccent, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Platform Feature & Module Management',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: SuperAdminTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Control platform-wide feature flags, plan assignments, and grant temporary promotional business overrides.',
                  style: TextStyle(fontSize: 13, color: SuperAdminTheme.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: SuperAdminTheme.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: SuperAdminTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 16, color: SuperAdminTheme.successGreen),
                const SizedBox(width: 8),
                Text(
                  '$activeCount of $totalCount Globally Active',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, List<String> categories) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SuperAdminTheme.cardDecoration(context),
      child: Row(
        children: [
          // Search Box
          Expanded(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: SuperAdminTheme.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SuperAdminTheme.border),
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: const TextStyle(fontSize: 13, color: SuperAdminTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search modules by name, description, or key...',
                  hintStyle: TextStyle(fontSize: 13, color: SuperAdminTheme.textMuted),
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: SuperAdminTheme.textSecondary),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Category Chips
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: isSelected,
                      selectedColor: SuperAdminTheme.primaryBlue,
                      backgroundColor: SuperAdminTheme.background,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : SuperAdminTheme.textSecondary,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: isSelected ? Colors.transparent : SuperAdminTheme.border),
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedCategory = cat);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleCard(BuildContext context, PlatformModuleConfig mod, SuperAdminApiService api) {
    final hasTempOverrides = mod.temporaryBusinessAccess.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SuperAdminTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon + Global Switch
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: mod.isGloballyEnabled
                      ? SuperAdminTheme.primaryBlue.withOpacity(0.12)
                      : SuperAdminTheme.border,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  mod.icon,
                  color: mod.isGloballyEnabled ? SuperAdminTheme.primaryBlue : SuperAdminTheme.textMuted,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mod.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: SuperAdminTheme.background,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: SuperAdminTheme.border),
                      ),
                      child: Text(
                        mod.category.toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SuperAdminTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              // Global Switch
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: mod.isGloballyEnabled,
                  activeColor: SuperAdminTheme.primaryBlue,
                  onChanged: (val) {
                    api.toggleModuleGlobal(mod.key);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${mod.name} is now ${val ? "Globally Enabled" : "Disabled"}'),
                        backgroundColor: val ? SuperAdminTheme.successGreen : SuperAdminTheme.warningAmber,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Description
          Text(
            mod.description,
            style: TextStyle(fontSize: 12, color: SuperAdminTheme.textSecondary, height: 1.35),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: SuperAdminTheme.border),
          const SizedBox(height: 12),

          // Enabled In Plans Badges
          const Text(
            'Included in Plans:',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: SuperAdminTheme.textSecondary),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildPlanBadge('Starter', mod.enabledPlans.contains('plan_starter')),
              _buildPlanBadge('Growth Pro', mod.enabledPlans.contains('plan_pro')),
              _buildPlanBadge('Enterprise', mod.enabledPlans.contains('plan_enterprise')),
            ],
          ),

          if (hasTempOverrides) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: SuperAdminTheme.warningAmber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: SuperAdminTheme.warningAmber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 14, color: SuperAdminTheme.warningAmber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${mod.temporaryBusinessAccess.length} businesses on temporary override',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: SuperAdminTheme.warningAmber),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Action Button: Grant Temp Access Override
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showGrantTempAccessDialog(context, mod, api),
              icon: const Icon(Icons.timer_rounded, size: 15),
              label: const Text('Grant Temporary Business Access'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: SuperAdminTheme.primaryBlue.withOpacity(0.4)),
                foregroundColor: SuperAdminTheme.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanBadge(String planName, bool isIncluded) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isIncluded
            ? SuperAdminTheme.successGreen.withOpacity(0.12)
            : SuperAdminTheme.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isIncluded ? SuperAdminTheme.successGreen.withOpacity(0.4) : SuperAdminTheme.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isIncluded ? Icons.check_circle_rounded : Icons.cancel_outlined,
            size: 12,
            color: isIncluded ? SuperAdminTheme.successGreen : SuperAdminTheme.textMuted,
          ),
          const SizedBox(width: 4),
          Text(
            planName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isIncluded ? FontWeight.w700 : FontWeight.w500,
              color: isIncluded ? SuperAdminTheme.successGreen : SuperAdminTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  void _showGrantTempAccessDialog(
    BuildContext context,
    PlatformModuleConfig mod,
    SuperAdminApiService api,
  ) {
    String? selectedBizId = api.businesses.first.id;
    int selectedDays = 14;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: SuperAdminTheme.cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: SuperAdminTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(mod.icon, color: SuperAdminTheme.primaryBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Grant Temp Access: ${mod.name}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary)),
                        Text('Promotional module trial override', style: TextStyle(fontSize: 12, color: SuperAdminTheme.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Select Target Business:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: SuperAdminTheme.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: SuperAdminTheme.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedBizId,
                          isExpanded: true,
                          items: api.businesses.map((b) {
                            return DropdownMenuItem(
                              value: b.id,
                              child: Text('${b.name} (${b.planName})', style: const TextStyle(fontSize: 13, color: SuperAdminTheme.textPrimary)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedBizId = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Trial Duration:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [7, 14, 30, 60].map((days) {
                        final isSel = selectedDays == days;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: OutlinedButton(
                              onPressed: () => setDialogState(() => selectedDays = days),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: isSel ? SuperAdminTheme.primaryBlue : SuperAdminTheme.border,
                                  width: isSel ? 2 : 1,
                                ),
                                backgroundColor: isSel ? SuperAdminTheme.primaryBlue.withOpacity(0.08) : SuperAdminTheme.background,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(
                                '$days Days',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                  color: isSel ? SuperAdminTheme.primaryBlue : SuperAdminTheme.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: SuperAdminTheme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedBizId != null) {
                      api.grantTemporaryModuleAccess(mod.key, selectedBizId!, selectedDays);
                      Navigator.pop(dialogCtx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Granted $selectedDays days temporary access for ${mod.name}!'),
                          backgroundColor: SuperAdminTheme.successGreen,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SuperAdminTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Apply Override'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
