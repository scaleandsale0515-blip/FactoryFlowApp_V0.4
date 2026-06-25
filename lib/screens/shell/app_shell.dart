import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../utils/app_strings.dart';
import '../../services/settings_service.dart';
import '../dashboard/dashboard_screen.dart';
import '../production/production_screen.dart';
import '../transport/transport_screen.dart';
import '../inventory/inventory_screen.dart';
import '../billing/billing_screen.dart';
import '../purchase/purchase_screen.dart';
import '../workers/workers_screen.dart';
import '../transporters/transporters_screen.dart';
import '../customers/customers_screen.dart';
import '../suppliers/suppliers_screen.dart';
import '../quotation/quotation_screen.dart';
import '../reports/reports_screen.dart';
import '../archives/archives_screen.dart';
import '../settings/settings_screen.dart';

class AppShell extends StatefulWidget {
  final bool isDark;
  final Function(bool) onThemeChanged;
  const AppShell({super.key, required this.isDark, required this.onThemeChanged});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  String _language = 'en';

  @override
  void initState() { super.initState(); _loadLanguage(); }

  Future<void> _loadLanguage() async {
    final lang = await SettingsService.instance.get('language') ?? 'en';
    AppStrings.setLanguage(lang);
    if (mounted) setState(() => _language = lang);
  }

  void _changeLanguage(String lang) {
    setState(() => _language = lang);
    AppStrings.setLanguage(lang);
    SettingsService.instance.set('language', lang);
  }

  final List<Widget> _screens = const [
    DashboardScreen(), ProductionScreen(), TransportScreen(), InventoryScreen(), BillingScreen(),
  ];

  String get _title {
    switch (_index) {
      case 0: return AppStrings.get('home');
      case 1: return AppStrings.get('production');
      case 2: return AppStrings.get('transport');
      case 3: return AppStrings.get('inventory');
      case 4: return AppStrings.get('billing');
      default: return 'FactoryFlow';
    }
  }

  Widget _handle() => Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2)));

  void _showMoreMenu() {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      //builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        builder: (ctx) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7, // 👈 IMPORTANT
        child: SingleChildScrollView(
          child: Column(
            children: [
        _handle(),
        _MenuTile(icon: Icons.shopping_cart_rounded, color: AppColors.info, label: AppStrings.get('purchase'), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text(AppStrings.get('purchase'))), body: const PurchaseScreen()))); }),
        _MenuTile(icon: Icons.people_rounded, color: AppColors.accent, label: AppStrings.get('workers'), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text(AppStrings.get('workers'))), body: const WorkersScreen()))); }),
        _MenuTile(icon: Icons.local_shipping_rounded, color: AppColors.warning, label: AppStrings.get('transporters'), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text(AppStrings.get('transporters'))), body: const TransportersScreen()))); }),
        _MenuTile(icon: Icons.business_rounded, color: AppColors.info, label: AppStrings.get('customers'), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text(AppStrings.get('customers'))), body: const CustomersScreen()))); }),
        _MenuTile(icon: Icons.local_shipping_outlined, color: AppColors.warning, label: AppStrings.get('suppliers'), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text(AppStrings.get('suppliers'))), body: const SuppliersScreen()))); }),
        _MenuTile(icon: Icons.request_quote_rounded, color: AppColors.primary, label: AppStrings.get('quotations'), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const QuotationScreen())); }),
        _MenuTile(icon: Icons.bar_chart_rounded, color: AppColors.success, label: AppStrings.get('reports'), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: Text(AppStrings.get('reports'))), body: const ReportsScreen()))); }),
        _MenuTile(icon: Icons.folder_zip_rounded, color: AppColors.accent, label: AppStrings.get('archives'), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const ArchivesScreen())); }),
        _MenuTile(icon: Icons.settings_rounded, color: Colors.grey, label: AppStrings.get('settings'), onTap: () {
          Navigator.pop(ctx);
          Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(isDark: widget.isDark, onThemeChanged: widget.onThemeChanged, onLanguageChanged: _changeLanguage)));
        }),
        const SizedBox(height: 8),
      ])),
    );
  }

  void _showQuickAdd() {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
     // builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        builder: (ctx) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7, // 👈 IMPORTANT
        child: SingleChildScrollView(
          child: Column(
            children: [
        _handle(),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Text('Quick Add', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
        _MenuTile(icon: Icons.factory_rounded, color: AppColors.accent, label: AppStrings.get('add_production'), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditProductionScreen())); }),
        _MenuTile(icon: Icons.local_shipping_rounded, color: AppColors.warning, label: AppStrings.get('add_transport'), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditTransportScreen())); }),
        _MenuTile(icon: Icons.shopping_cart_rounded, color: AppColors.info, label: AppStrings.get('add_purchase'), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEditPurchaseScreen())); }),
        _MenuTile(icon: Icons.receipt_rounded, color: AppColors.primary, label: AppStrings.get('create_invoice'), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const AddInvoiceScreen())); }),
        _MenuTile(icon: Icons.request_quote_rounded, color: AppColors.success, label: AppStrings.get('new_quote'), onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const AddQuotationScreen())); }),
        const SizedBox(height: 8),
      ])),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(width: 28, height: 28, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(7)), child: const Icon(Icons.factory_rounded, color: Colors.white, size: 16)),
          const SizedBox(width: 10),
          Text(_title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        ]),
        actions: [
          Container(margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(color: widget.isDark ? AppColors.darkCard : AppColors.lightBorder, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (final e in [('en', 'EN'), ('gu', 'ગુજ'), ('hi', 'हिं')])
                GestureDetector(onTap: () => _changeLanguage(e.$1),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
                    decoration: BoxDecoration(color: _language == e.$1 ? AppColors.primary : Colors.transparent, borderRadius: BorderRadius.circular(7)),
                    child: Text(e.$2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _language == e.$1 ? Colors.white : Colors.grey)))),
            ]),
          ),
          const SizedBox(width: 2),
          IconButton(icon: const Icon(Icons.more_vert_rounded), onPressed: _showMoreMenu),
        ],
      ),
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index, onTap: (i) => setState(() => _index = i),
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.dashboard_rounded), label: AppStrings.get('home')),
          BottomNavigationBarItem(icon: const Icon(Icons.factory_rounded), label: AppStrings.get('production')),
          BottomNavigationBarItem(icon: const Icon(Icons.local_shipping_rounded), label: AppStrings.get('transport')),
          BottomNavigationBarItem(icon: const Icon(Icons.inventory_2_rounded), label: AppStrings.get('inventory')),
          BottomNavigationBarItem(icon: const Icon(Icons.receipt_rounded), label: AppStrings.get('billing')),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: _showQuickAdd, backgroundColor: AppColors.primary, child: const Icon(Icons.add_rounded, size: 28)),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon; final Color color; final String label; final VoidCallback onTap;
  const _MenuTile({required this.icon, required this.color, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(9)), child: Icon(icon, color: color, size: 20)),
    title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 18),
  );
}
