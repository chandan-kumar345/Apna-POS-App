import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/campaign_models.dart';
import 'customer_group_import.dart';
import 'customer_style.dart';
import 'mobile_campaign_data.dart';
import 'mobile_customers_data.dart';

class CreateCustomerGroupScreen extends StatefulWidget {
  final CampaignOptions? options;
  final VoidCallback? onGroupCreated;
  final MobileCustomersApi? api;
  final AudienceGroupModel? group;
  const CreateCustomerGroupScreen({
    super.key,
    this.options,
    this.onGroupCreated,
    this.api,
    this.group,
  });
  @override
  State<CreateCustomerGroupScreen> createState() =>
      _CreateCustomerGroupScreenState();
}

class _CreateCustomerGroupScreenState extends State<CreateCustomerGroupScreen> {
  final _name = TextEditingController(), _numbers = TextEditingController();
  final _errorAnchor = GlobalKey();
  late final MobileCustomersApi _api = widget.api ?? MobileCustomersApi();
  List<CustomerImportTable> _tables = [];
  int _sheet = 0, _column = 0;
  String? _fileName, _error;
  bool _reading = false, _saving = false, _downloading = false;
  CustomerImportTable? get _table => _tables.isEmpty ? null : _tables[_sheet];
  CustomerNumberCheck get _check => CustomerNumberCheck.parse([
    ...CustomerNumberCheck.manual(_numbers.text),
    ...?_table?.values(_column),
  ]);
  @override
  void initState() {
    super.initState();
    _name.text = widget.group?.name ?? '';
    _numbers.text = widget.group?.numbers.map((n) => n.phone).join(', ') ?? '';
    _name.addListener(_changed);
    _numbers.addListener(_changed);
  }

  void _changed() => setState(() {});
  @override
  void dispose() {
    _name.dispose();
    _numbers.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    try {
      final value = (await Clipboard.getData(
        Clipboard.kTextPlain,
      ))?.text?.trim();
      if (!mounted) return;
      if (value == null || value.isEmpty) {
        _message('No numbers found on the clipboard.');
        return;
      }
      _numbers.text = [
        _numbers.text.trim(),
        value,
      ].where((v) => v.isNotEmpty).join(', ');
    } catch (_) {
      if (mounted) {
        _message('Could not read the clipboard. Paste into the field instead.');
      }
    }
  }

  Future<void> _chooseFile() async {
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );
      if (result == null) return;
      final file = result.files.single;
      if (file.size > 10 * 1024 * 1024) {
        throw const FormatException('Choose a file smaller than 10 MB.');
      }
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw const FormatException('This file is empty or could not be read.');
      }
      final extension = file.extension?.toLowerCase() ?? '';
      if (!['xlsx', 'xls', 'csv'].contains(extension)) {
        throw const FormatException('Choose an .xlsx, .xls or .csv file.');
      }
      final tables = await compute(decodeCustomerImport, <String, Object>{
        'bytes': bytes,
        'extension': extension,
      });
      final populated = tables
          .where((t) => t.rows.isNotEmpty && t.columns.isNotEmpty)
          .toList();
      if (populated.isEmpty) {
        throw const FormatException(
          'No data rows found. Add a phone number column and try again.',
        );
      }
      if (!mounted) return;
      setState(() {
        _tables = populated;
        _sheet = 0;
        _column = populated.first.suggestedColumn;
        _fileName = file.name;
      });
    } catch (error) {
      if (mounted) {
        _showError(
          error is FormatException
              ? error.message.toString()
              : 'Could not read this spreadsheet. Save it as XLSX or CSV and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _downloadSample() async {
    setState(() => _downloading = true);
    try {
      final bytes = Uint8List.fromList(
        utf8.encode(
          'Name,Mobile Number\r\nSample customer,919876500001\r\nAnother customer,919876500002\r\n',
        ),
      );
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Download sample file',
        fileName: 'customer_group_sample.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: bytes,
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
      if (mounted && path != null) _message('Sample file downloaded.');
    } catch (_) {
      if (mounted) _message('Could not download the sample. Please try again.');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _submit() async {
    if (_saving || _reading) return;
    final check = _check;
    if (_name.text.trim().isEmpty || check.valid.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final names = {
        for (final contact in widget.group?.numbers ?? <ContactNumberModel>[])
          normalizeCustomerPhone(contact.phone): contact.name,
      };
      await _api.saveGroup(
        id: widget.group?.id,
        name: _name.text.trim(),
        source: _fileName == null ? 'Manual' : 'Excel/CSV',
        description: widget.group?.description ?? '',
        numbers: check.valid
            .map((phone) => {'name': names[phone] ?? 'Contact', 'phone': phone})
            .toList(),
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      widget.onGroupCreated?.call();
      Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.group == null
                ? 'Group "${_name.text.trim()}" created successfully'
                : 'Group updated successfully',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        _showError(
          'Could not save your group. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _showError(String message) {
    setState(() => _error = message);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anchor = _errorAnchor.currentContext;
      if (mounted && anchor != null) {
        Scrollable.ensureVisible(
          anchor,
          duration: const Duration(milliseconds: 200),
        );
      }
    });
  }

  void _reviewInvalid(CustomerNumberCheck check) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .55,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Text(
                'Invalid numbers (${check.invalid.length})',
                style: customerText(20, weight: FontWeight.w800),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Include the country code. These entries will be skipped.',
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: check.invalid.length,
                itemBuilder: (_, index) => ListTile(
                  leading: const Icon(Icons.error_outline, color: Colors.red),
                  title: SelectableText(check.invalid[index]),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final check = _check;
    final manualCount = CustomerNumberCheck.manual(_numbers.text).length;
    return PopScope(
      canPop: !_saving,
      child: CustomerShell(
        header: CustomerHeader(
          title: widget.group == null ? 'Create group' : 'Edit group',
          leading: CustomerHeaderButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onTap: () {
              if (!_saving) Navigator.maybePop(context);
            },
          ),
          trailing: const Icon(
            Icons.people_outline_rounded,
            color: Colors.white,
            size: 28,
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const CustomerIconTile(
                    icon: Icons.people_outline_rounded,
                    color: customerPurple,
                    background: Color(0xFFDEC7FF),
                    size: 50,
                  ),
                  Container(
                    width: 1,
                    height: 43,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: const Color(0xFF9DC8E1),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Build your customer group',
                          style: customerText(20, weight: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Add numbers manually or import from Excel.',
                          style: customerText(
                            13,
                            color: customerBlue,
                            weight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 19),
              Text.rich(
                TextSpan(
                  text: 'Group title ',
                  children: [
                    TextSpan(
                      text: '*',
                      style: TextStyle(color: Colors.red.shade600),
                    ),
                  ],
                ),
                style: customerText(16, weight: FontWeight.w800),
              ),
              const SizedBox(height: 7),
              TextField(
                key: const ValueKey('group-title'),
                controller: _name,
                enabled: !_saving,
                maxLength: 100,
                textCapitalization: TextCapitalization.sentences,
                style: customerText(16),
                decoration: customerInput(
                  'e.g. Weekend offers',
                  prefix: const Icon(
                    Icons.folder_outlined,
                    color: customerBlue,
                  ),
                ).copyWith(counterText: ''),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mobile numbers',
                    style: customerText(16, weight: FontWeight.w800),
                  ),
                  TextButton(
                    onPressed: _saving ? null : _paste,
                    child: const Text('Paste'),
                  ),
                ],
              ),
              TextField(
                key: const ValueKey('group-numbers'),
                controller: _numbers,
                enabled: !_saving,
                minLines: 2,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                style: customerText(16, weight: FontWeight.w400),
                decoration: customerInput('+919876500001, +919876500002'),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  Text(
                    'Separate each number with a comma.\nInclude the country code, e.g. +91.',
                    style: customerText(
                      12,
                      color: customerBlue,
                      weight: FontWeight.w400,
                    ),
                  ),
                  CustomerPill(
                    '$manualCount ${manualCount == 1 ? 'number' : 'numbers'} entered',
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    const Expanded(child: Divider(color: Color(0xFF96C9E5))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR IMPORT NUMBERS',
                        style: customerText(13, weight: FontWeight.w800),
                      ),
                    ),
                    const Expanded(child: Divider(color: Color(0xFF96C9E5))),
                  ],
                ),
              ),
              _importCard(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Number check',
                    style: customerText(18, weight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Text(
                    '${check.entries} ${check.entries == 1 ? 'entry' : 'entries'}',
                    style: customerText(
                      14,
                      color: customerBlue,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: _metric(
                      'Valid',
                      check.valid.length,
                      Icons.check_circle_outline,
                      customerGreen,
                      const Color(0xFFCCFBE4),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _metric(
                      'Duplicates',
                      check.duplicates,
                      Icons.copy_outlined,
                      const Color(0xFFA56D00),
                      const Color(0xFFFFEFD2),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _metric(
                      'Invalid',
                      check.invalid.length,
                      Icons.cancel_outlined,
                      const Color(0xFFD33730),
                      const Color(0xFFFFDFE6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Duplicates are removed. Invalid numbers are skipped.',
                style: customerText(
                  12,
                  color: customerBlue,
                  weight: FontWeight.w400,
                ),
              ),
              if (check.invalid.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => _reviewInvalid(check),
                    child: const Text(
                      'Review invalid numbers',
                      style: TextStyle(decoration: TextDecoration.underline),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: customerCard(
                  colors: const [Color(0xFFD8FFE7), Color(0xFFC4FBE7)],
                  radius: 14,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: customerGreen,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${check.valid.length} unique ${check.valid.length == 1 ? 'number' : 'numbers'} will be ${widget.group == null ? 'added' : 'saved'}',
                        style: customerText(14, weight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  key: _errorAnchor,
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    key: const ValueKey('group-error'),
                    style: customerText(13, color: Colors.red.shade800),
                  ),
                ),
            ],
          ),
        ),
        footer: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.maybePop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: customerInk,
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    side: const BorderSide(color: customerBlue, width: 1.3),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Cancel',
                      style: customerText(17, weight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 6,
                child: CustomerPrimary(
                  widget.group == null ? 'Create group' : 'Save changes',
                  icon: Icons.person_add_alt_1_outlined,
                  busy: _saving,
                  onPressed:
                      _name.text.trim().isEmpty ||
                          check.valid.isEmpty ||
                          _reading ||
                          _saving
                      ? null
                      : _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _importCard() => Container(
    padding: const EdgeInsets.all(12),
    decoration: customerCard(
      colors: const [Color(0xFFEBFAFF), Color(0xFFDEF8F8)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final description = Row(
              children: [
                const CustomerIconTile(
                  icon: Icons.table_chart_outlined,
                  color: customerGreen,
                  background: Color(0xFFB9FAD6),
                  size: 46,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Import from Excel',
                        style: customerText(18, weight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Upload an .xlsx, .xls or .csv file',
                        style: customerText(
                          12,
                          color: customerBlue,
                          weight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
            final button = OutlinedButton.icon(
              onPressed: _saving || _reading ? null : _chooseFile,
              icon: const Icon(Icons.file_upload_outlined, size: 20),
              label: Text(_reading ? 'Reading…' : 'Choose file'),
              style: OutlinedButton.styleFrom(
                foregroundColor: customerInk,
                side: const BorderSide(color: customerBlue),
                minimumSize: const Size(0, 42),
              ),
            );
            if (constraints.maxWidth < 320) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  description,
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerRight, child: button),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: description),
                const SizedBox(width: 14),
                button,
              ],
            );
          },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _downloading || _saving ? null : _downloadSample,
            icon: const Icon(Icons.file_download_outlined, size: 19),
            label: Text(
              _downloading ? 'Downloading…' : 'Download sample file',
              style: const TextStyle(decoration: TextDecoration.underline),
            ),
          ),
        ),
        if (_fileName != null) ...[
          Container(
            decoration: customerCard(radius: 12),
            child: ListTile(
              dense: true,
              leading: const Icon(
                Icons.description_rounded,
                color: customerGreen,
                size: 30,
              ),
              title: Text(
                _fileName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: customerText(14, weight: FontWeight.w700),
              ),
              subtitle: Text('${_table!.rows.length} rows loaded'),
              trailing: IconButton(
                tooltip: 'Remove imported file',
                icon: const Icon(Icons.close),
                onPressed: _saving
                    ? null
                    : () => setState(() {
                        _tables = [];
                        _fileName = null;
                      }),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (_tables.length > 1) ...[
            Text('Worksheet', style: customerText(13, weight: FontWeight.w700)),
            const SizedBox(height: 5),
            DropdownButtonFormField<int>(
              key: ValueKey('sheet-$_fileName-$_sheet'),
              initialValue: _sheet,
              isExpanded: true,
              decoration: customerInput('Select worksheet'),
              items: [
                for (var i = 0; i < _tables.length; i++)
                  DropdownMenuItem(value: i, child: Text(_tables[i].name)),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() {
                          _sheet = value;
                          _column = _table!.suggestedColumn;
                        });
                      }
                    },
            ),
            const SizedBox(height: 10),
          ],
          Text(
            'Phone number column',
            style: customerText(13, weight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          DropdownButtonFormField<int>(
            key: ValueKey('column-$_fileName-$_sheet-$_column'),
            initialValue: _column,
            isExpanded: true,
            decoration: customerInput('Select phone column'),
            items: [
              for (var i = 0; i < _table!.columns.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    _table!.columns[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _saving
                ? null
                : (value) {
                    if (value != null) setState(() => _column = value);
                  },
          ),
        ],
      ],
    ),
  );

  Widget _metric(
    String label,
    int value,
    IconData icon,
    Color color,
    Color background,
  ) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    decoration: customerCard(
      colors: [Color.lerp(background, Colors.white, .2)!, background],
      radius: 14,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  style: customerText(11, weight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 3),
          child: Text(
            '$value',
            key: ValueKey('check-${label.toLowerCase()}'),
            style: customerText(24, weight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}
