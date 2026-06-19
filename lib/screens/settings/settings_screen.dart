import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/settings_service.dart';
import '../../services/excel_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_strings.dart';

class SettingsScreen extends StatefulWidget {
  final bool isDark;
  final Function(bool) onThemeChanged;
  final Function(String) onLanguageChanged;
  const SettingsScreen({super.key, required this.isDark, required this.onThemeChanged, required this.onLanguageChanged});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _companyCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _paymentTermsCtrl = TextEditingController();
  final _tcCtrl = TextEditingController();
  String _language = 'en';
  String? _logoPath;
  bool _storageEnabled = true;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final s = await SettingsService.instance.getAll();
    _companyCtrl.text = s['company_name'] ?? '';
    _gstCtrl.text = s['gst_number'] ?? '';
    _addressCtrl.text = s['address'] ?? '';
    _phoneCtrl.text = s['phone'] ?? '';
    _paymentTermsCtrl.text = s['payment_terms'] ?? '';
    _tcCtrl.text = s['terms_conditions'] ?? '';
    _language = s['language'] ?? 'en';
    _logoPath = s['logo_path'];
    _storageEnabled = s['storage_enabled'] != 'false';
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await SettingsService.instance.set('company_name', _companyCtrl.text.trim());
    await SettingsService.instance.set('gst_number', _gstCtrl.text.trim());
    await SettingsService.instance.set('address', _addressCtrl.text.trim());
    await SettingsService.instance.set('phone', _phoneCtrl.text.trim());
    await SettingsService.instance.set('payment_terms', _paymentTermsCtrl.text.trim());
    await SettingsService.instance.set('terms_conditions', _tcCtrl.text.trim());
    if (_logoPath != null) await SettingsService.instance.set('logo_path', _logoPath!);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved!')));
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => _logoPath = picked.path);
  }

  Future<void> _toggleStorage(bool val) async {
    setState(() => _storageEnabled = val);
    await SettingsService.instance.set('storage_enabled', val.toString());
    if (val) {
      final granted = await ExcelService.instance.requestPermission();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Storage permission denied')));
      }
    }
  }

  Future<void> _manualExport() async {
    await ExcelService.instance.checkAndRotate();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel updated!')));
  }

  Future<void> _startNewCycle() async {
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(AppStrings.get('new_cycle')),
      content: const Text('This will close the current cycle and start a fresh Excel file. Continue?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.get('cancel'))),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Start New')),
      ],
    ));
    if (confirm == true) {
      final cycle = await ExcelService.instance.getActiveCycle();
      if (cycle != null) {
        // Force expire by checking rotate after marking inactive — handled internally
      }
      await ExcelService.instance.checkAndRotate();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(AppStrings.get('cycle_started')),
    backgroundColor: Colors.green,
    behavior: SnackBarBehavior.floating,
  ),
);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.get('settings'))),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Logo
        Center(child: GestureDetector(
          onTap: _pickLogo,
          child: Container(width: 90, height: 90, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary, width: 2), color: AppColors.darkCard),
            child: _logoPath != null ? ClipOval(child: Image.file(File(_logoPath!), fit: BoxFit.cover, width: 90, height: 90)) : const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 30)),
        )),
        const SizedBox(height: 24),

        Text(AppStrings.get('company_name'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 16),
        TextField(controller: _companyCtrl, decoration: InputDecoration(labelText: AppStrings.get('company_name'))),
        const SizedBox(height: 12),
        TextField(controller: _gstCtrl, decoration: InputDecoration(labelText: AppStrings.get('gst_number'))),
        const SizedBox(height: 12),
        TextField(controller: _addressCtrl, decoration: InputDecoration(labelText: AppStrings.get('address')), maxLines: 2),
        const SizedBox(height: 12),
        TextField(controller: _phoneCtrl, decoration: InputDecoration(labelText: AppStrings.get('phone')), keyboardType: TextInputType.phone),
        const SizedBox(height: 24),

        Text(AppStrings.get('language'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 10),
        Row(children: [
          for (final e in [('en', 'English'), ('gu', 'ગુજરાતી'), ('hi', 'हिंदी')])
            Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
              onTap: () { setState(() => _language = e.$1); widget.onLanguageChanged(e.$1); SettingsService.instance.set('language', e.$1); },
              child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: _language == e.$1 ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(8), border: Border.all(color: _language == e.$1 ? AppColors.primary : AppColors.darkBorder)),
                child: Text(e.$2, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _language == e.$1 ? Colors.white : Colors.grey))),
            ))),
        ]),
        const SizedBox(height: 20),

        SwitchListTile(value: widget.isDark, onChanged: widget.onThemeChanged, title: Text(AppStrings.get('theme')), subtitle: Text(widget.isDark ? AppStrings.get('dark_mode') : AppStrings.get('light_mode')), activeColor: AppColors.primary, contentPadding: EdgeInsets.zero),
        const Divider(),

        SwitchListTile(value: _storageEnabled, onChanged: _toggleStorage, title: Text(AppStrings.get('storage')), subtitle: const Text('Backup Excel files to phone storage', style: TextStyle(fontSize: 11)), activeColor: AppColors.primary, contentPadding: EdgeInsets.zero),
        const SizedBox(height: 24),

        Text(AppStrings.get('payment_terms'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 10),
        TextField(controller: _paymentTermsCtrl, decoration: const InputDecoration(hintText: 'One per line'), maxLines: 4),
        const SizedBox(height: 20),

        Text(AppStrings.get('terms_conditions'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 10),
        TextField(controller: _tcCtrl, decoration: const InputDecoration(hintText: 'One per line'), maxLines: 8),
        const SizedBox(height: 24),

        SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(AppStrings.get('save')))),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: _manualExport, icon: const Icon(Icons.upload_file_rounded, size: 18), label: Text(AppStrings.get('export_excel')), style: OutlinedButton.styleFrom(foregroundColor: AppColors.info, side: const BorderSide(color: AppColors.info), padding: const EdgeInsets.symmetric(vertical: 12)))),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(onPressed: _startNewCycle, icon: const Icon(Icons.autorenew_rounded, size: 18), label: Text(AppStrings.get('new_cycle')), style: OutlinedButton.styleFrom(foregroundColor: AppColors.warning, side: const BorderSide(color: AppColors.warning), padding: const EdgeInsets.symmetric(vertical: 12)))),
        ]),
        const SizedBox(height: 40),
      ])),
    );
  }
}
