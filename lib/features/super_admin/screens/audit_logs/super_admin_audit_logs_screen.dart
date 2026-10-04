import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/super_admin_theme.dart';
import '../../services/super_admin_api_service.dart';
import '../../models/super_admin_audit_log_model.dart';

class SuperAdminAuditLogsScreen extends StatefulWidget {
  const SuperAdminAuditLogsScreen({super.key});

  @override
  State<SuperAdminAuditLogsScreen> createState() => _SuperAdminAuditLogsScreenState();
}

class _SuperAdminAuditLogsScreenState extends State<SuperAdminAuditLogsScreen> {
  String _searchQuery = '';
  String _selectedTargetType = 'All';

  @override
  Widget build(BuildContext context) {
    final api = SuperAdminApiService();

    return ListenableBuilder(
      listenable: api,
      builder: (context, _) {
        final logs = api.auditLogs;

        final filtered = logs.where((l) {
          final query = _searchQuery.toLowerCase();
          final matchesSearch = query.isEmpty ||
              l.action.toLowerCase().contains(query) ||
              l.adminName.toLowerCase().contains(query) ||
              l.targetName.toLowerCase().contains(query) ||
              l.details.toLowerCase().contains(query);

          final matchesType = _selectedTargetType == 'All' || l.targetType.label == _selectedTargetType;

          return matchesSearch && matchesType;
        }).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(context, logs.length),
              const SizedBox(height: 20),

              // Filter Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: SuperAdminTheme.cardDecoration(context),
                child: Row(
                  children: [
                    // Search box
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
                            hintText: 'Search audit records by action, admin, target, or keywords...',
                            hintStyle: TextStyle(fontSize: 13, color: SuperAdminTheme.textMuted),
                            prefixIcon: Icon(Icons.search_rounded, size: 20, color: SuperAdminTheme.textSecondary),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Target Type Filter
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: SuperAdminTheme.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: SuperAdminTheme.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedTargetType,
                          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: SuperAdminTheme.textSecondary),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary),
                          items: [
                            'All',
                            ...AuditTargetType.values.map((t) => t.label),
                          ].map((t) => DropdownMenuItem(value: t, child: Text('Target: $t'))).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _selectedTargetType = v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Export Audit Trail
                    OutlinedButton.icon(
                      onPressed: () => _exportLogs(filtered),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Export Audit Trail'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: SuperAdminTheme.primaryBlue.withOpacity(0.4)),
                        foregroundColor: SuperAdminTheme.primaryBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Audit Logs Table
              Container(
                decoration: SuperAdminTheme.cardDecoration(context),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      color: SuperAdminTheme.background,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: const Row(
                        children: [
                          Expanded(flex: 2, child: Text('Timestamp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textSecondary))),
                          Expanded(flex: 2, child: Text('Admin User', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textSecondary))),
                          Expanded(flex: 2, child: Text('Target Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textSecondary))),
                          Expanded(flex: 3, child: Text('Action & Target Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textSecondary))),
                          Expanded(flex: 3, child: Text('Details / Audit Reason', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textSecondary))),
                          SizedBox(width: 90, child: Text('Inspect', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textSecondary))),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: SuperAdminTheme.border),

                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.history_toggle_off_rounded, size: 48, color: SuperAdminTheme.textMuted),
                              const SizedBox(height: 12),
                              const Text('No audit log events match your search criteria', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary)),
                            ],
                          ),
                        ),
                      )
                    else
                      ...filtered.map((log) => _buildLogRow(context, log)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, int totalLogs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SuperAdminTheme.cardDecoration(context),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: SuperAdminTheme.warningAmber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.security_rounded, color: SuperAdminTheme.warningAmber, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Platform Audit & Compliance Logs',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: SuperAdminTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Immutable forensic record of all administrative interventions, plan modifications, financial refunds, and account state changes.',
                  style: TextStyle(fontSize: 13, color: SuperAdminTheme.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: SuperAdminTheme.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SuperAdminTheme.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_clock_rounded, size: 16, color: SuperAdminTheme.successGreen),
                const SizedBox(width: 6),
                Text(
                  'Audit Immutability Active ($totalLogs events)',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogRow(BuildContext context, AuditLogRecord log) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SuperAdminTheme.border, width: 0.8)),
      ),
      child: Row(
        children: [
          // Timestamp
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.timestamp.toString().split('.').first,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
                ),
                Text(
                  log.ipAddress,
                  style: TextStyle(fontSize: 11, color: SuperAdminTheme.textMuted),
                ),
              ],
            ),
          ),

          // Admin
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.adminName,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary),
                ),
                Text(
                  log.adminRole,
                  style: TextStyle(fontSize: 11, color: SuperAdminTheme.textSecondary),
                ),
              ],
            ),
          ),

          // Target Type
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: log.targetType.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(log.targetType.icon, size: 12, color: log.targetType.color),
                    const SizedBox(width: 4),
                    Text(
                      log.targetType.label,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: log.targetType.color),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Action & Target Name
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.action,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: SuperAdminTheme.primaryBlue),
                ),
                Text(
                  log.targetName,
                  style: TextStyle(fontSize: 11, color: SuperAdminTheme.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Details / Reason
          Expanded(
            flex: 3,
            child: Text(
              log.details,
              style: const TextStyle(fontSize: 12, color: SuperAdminTheme.textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Inspect Button
          SizedBox(
            width: 90,
            child: OutlinedButton(
              onPressed: () => _showAuditDetailDialog(context, log),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: SuperAdminTheme.primaryBlue.withOpacity(0.3)),
                foregroundColor: SuperAdminTheme.primaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('Inspect', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAuditDetailDialog(BuildContext context, AuditLogRecord log) {
    showDialog(
      context: context,
      builder: (ctx) {
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
                child: const Icon(Icons.fingerprint_rounded, color: SuperAdminTheme.primaryBlue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Audit Event: ${log.action}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary)),
                    Text('Log ID: ${log.id}', style: TextStyle(fontSize: 11, color: SuperAdminTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildModalDetailRow('Admin Operator:', '${log.adminName} (${log.adminRole})'),
                _buildModalDetailRow('Timestamp:', log.timestamp.toString()),
                _buildModalDetailRow('IP Address & Client:', log.ipAddress),
                _buildModalDetailRow('Target Entity:', '${log.targetType.label} - ${log.targetName} [${log.targetId}]'),
                _buildModalDetailRow('Action Details:', log.details),

                if (log.previousValue != null || log.newValue != null) ...[
                  const SizedBox(height: 16),
                  const Text('State Diff Inspection:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SuperAdminTheme.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: SuperAdminTheme.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('PREVIOUS VALUE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SuperAdminTheme.errorRed)),
                              const SizedBox(height: 4),
                              Text(log.previousValue ?? 'None', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded, size: 16, color: SuperAdminTheme.textMuted),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('NEW VALUE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: SuperAdminTheme.successGreen)),
                              const SizedBox(height: 4),
                              Text(log.newValue ?? 'None', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SuperAdminTheme.textPrimary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close Inspector', style: TextStyle(color: SuperAdminTheme.primaryBlue, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModalDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: SuperAdminTheme.textSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SuperAdminTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  void _exportLogs(List<AuditLogRecord> list) {
    final buffer = StringBuffer();
    buffer.writeln('LogID,Timestamp,Admin,Role,Action,TargetType,TargetName,Details,IPAddress');
    for (final l in list) {
      buffer.writeln('"${l.id}","${l.timestamp}","${l.adminName}","${l.adminRole}","${l.action}","${l.targetType.label}","${l.targetName}","${l.details}","${l.ipAddress}"');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${list.length} audit trail logs to clipboard for compliance archiving!'),
        backgroundColor: SuperAdminTheme.successGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
