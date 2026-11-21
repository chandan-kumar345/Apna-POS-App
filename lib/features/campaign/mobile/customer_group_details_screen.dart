import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/campaign_models.dart';
import 'campaign_editor.dart';
import 'create_customer_group_screen.dart';
import 'customer_style.dart';
import 'mobile_campaign_data.dart';
import 'mobile_customers_data.dart';

class CustomerGroupDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> group;
  final CampaignOptions? options;
  final VoidCallback? onGroupUpdated;
  final MobileCustomersApi? api;
  const CustomerGroupDetailsScreen({
    super.key,
    required this.group,
    this.options,
    this.onGroupUpdated,
    this.api,
  });
  @override
  State<CustomerGroupDetailsScreen> createState() =>
      _CustomerGroupDetailsScreenState();
}

class _CustomerGroupDetailsScreenState
    extends State<CustomerGroupDetailsScreen> {
  late AudienceGroupModel _group = AudienceGroupModel.fromJson(widget.group);
  late final MobileCustomersApi _api = widget.api ?? MobileCustomersApi();
  final _search = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _edit() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateCustomerGroupScreen(
          api: _api,
          group: _group,
          options: widget.options,
        ),
      ),
    );
    if (result != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await _api.group(_group.id);
      if (mounted) {
        setState(() {
          _group = updated;
          _error = null;
        });
      }
      widget.onGroupUpdated?.call();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not refresh the group. Go back and reopen it to retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(ContactNumberModel contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove number?'),
        content: Text('Remove ${contact.phone} from this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await _api.saveGroup(
        id: _group.id,
        name: _group.name,
        source: _group.source,
        description: _group.description,
        numbers: _group.numbers
            .where((number) => !identical(number, contact))
            .map((n) => n.toJson().cast<String, String>())
            .toList(),
      );
      if (mounted) setState(() => _group = saved);
      widget.onGroupUpdated?.call();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not remove this number. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCampaign() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final options = await MobileCampaignApi().options();
      if (!mounted) return;
      final draft = MobileCampaignDraft()
        ..group = _group.id
        ..title = 'Special for ${_group.name}';
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CampaignEditor(
            api: MobileCampaignApi(),
            approved: false,
            options: options,
            draft: draft,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not open the campaign editor. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      String safe(String value) =>
          RegExp(r'^[=+@\-]').hasMatch(value) ? "'$value" : value;
      final bytes = Uint8List.fromList(
        utf8.encode(
          csv.encode([
            ['Name', 'Mobile Number'],
            ..._group.numbers.map((n) => [safe(n.name), safe(n.phone)]),
          ]),
        ),
      );
      final path = await FilePicker.platform.saveFile(
        fileName: 'customer_group.csv',
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (!kIsWeb &&
          path != null &&
          [
            TargetPlatform.windows,
            TargetPlatform.macOS,
            TargetPlatform.linux,
          ].contains(defaultTargetPlatform)) {
        await File(path).writeAsBytes(bytes);
      }
      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group contacts exported')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not export the group. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = _group.numbers
        .where(
          (n) => '${n.name} ${n.phone}'.toLowerCase().contains(
            _search.text.trim().toLowerCase(),
          ),
        )
        .toList();
    return CustomerShell(
      header: CustomerHeader(
        title: _group.name,
        leading: CustomerHeaderButton(
          icon: Icons.arrow_back_rounded,
          tooltip: 'Back',
          onTap: () => Navigator.maybePop(context),
        ),
        trailing: CustomerHeaderButton(
          icon: Icons.edit_outlined,
          tooltip: 'Edit group',
          onTap: () {
            if (!_busy) _edit();
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: customerCard(
              colors: const [Color(0xFFEDE0FF), Color(0xFFD8CAFC)],
            ),
            child: Row(
              children: [
                const CustomerIconTile(
                  icon: Icons.folder_outlined,
                  color: customerPurple,
                  background: Color(0xFFDEC7FF),
                  size: 52,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _group.name,
                        style: customerText(22, weight: FontWeight.w800),
                      ),
                      Text(
                        '${NumberFormat.decimalPattern('en_IN').format(_group.totalNumbers)} ${_group.totalNumbers == 1 ? 'number' : 'numbers'}',
                        style: customerText(15, color: customerBlue),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _edit,
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Add numbers'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy || _group.numbers.isEmpty ? null : _export,
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Export'),
                ),
              ),
            ],
          ),
          if (_group.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _group.description,
                style: customerText(
                  14,
                  color: customerBlue,
                  weight: FontWeight.w400,
                ),
              ),
            ),
          if (_group.createdAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Created ${DateFormat('d MMM yyyy').format(indiaClock(_group.createdAt!))}',
                style: customerText(12, color: customerBlue),
              ),
            ),
          const SizedBox(height: 18),
          Text(
            'Group members',
            style: customerText(21, weight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: customerInput(
              'Search group members',
              prefix: const Icon(Icons.search),
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _error!,
                style: customerText(13, color: Colors.red.shade800),
              ),
            ),
          const SizedBox(height: 12),
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _search.text.isEmpty
                    ? 'No numbers in this group yet.'
                    : 'No matching members.',
                textAlign: TextAlign.center,
                style: customerText(14, color: customerBlue),
              ),
            ),
          for (final member in members)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: customerCard(radius: 14),
              child: ListTile(
                leading: const Icon(Icons.person_outline, color: customerBlue),
                title: Text(member.phone, style: customerText(15)),
                subtitle: Text(member.name),
                trailing: IconButton(
                  tooltip: 'Remove ${member.phone}',
                  icon: const Icon(Icons.person_remove_outlined),
                  onPressed: _busy ? null : () => _remove(member),
                ),
              ),
            ),
        ],
      ),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: SizedBox(
          width: double.infinity,
          child: CustomerPrimary(
            'Create campaign',
            icon: Icons.campaign_outlined,
            onPressed: _busy || _group.numbers.isEmpty ? null : _sendCampaign,
          ),
        ),
      ),
    );
  }
}
