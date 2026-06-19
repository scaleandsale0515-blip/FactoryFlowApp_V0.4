import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:factoryflow/services/settings_service.dart';
//import 'package:factoryflow/utils/app_colors.dart';
import 'package:factoryflow/utils/app_theme.dart';
import 'package:factoryflow/utils/app_strings.dart';

class AdminLockScreen extends StatefulWidget {
  final VoidCallback onActivated;

  const AdminLockScreen({super.key, required this.onActivated});

  @override
  State<AdminLockScreen> createState() => _AdminLockScreenState();
}

class _AdminLockScreenState extends State<AdminLockScreen> {
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  bool _pwVisible = false;
  bool _loading = false;

  String? _error;
  int _attempts = 0;

  bool _verify(String id, String pw) {
    final realHash = sha256
        .convert(utf8.encode('FactoryFlowRP2026:AdxyRBP@7989Qwop'))
        .toString();

    final inputHash =
        sha256.convert(utf8.encode('$id:$pw')).toString();

    return inputHash == realHash;
  }

  Future<void> _activate() async {
    if (_idCtrl.text.trim().isEmpty ||
        _pwCtrl.text.isEmpty) {
      setState(() =>
          _error = 'Please enter ID and Password');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    await Future.delayed(const Duration(milliseconds: 700));

    if (_verify(_idCtrl.text.trim(), _pwCtrl.text)) {
      await SettingsService.instance.activate();
      widget.onActivated();
    } else {
      _attempts++;
      setState(() {
        _loading = false;
        _error = AppStrings.get('wrong_credentials');

        if (_attempts >= 3) {
          _pwCtrl.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                /// LOGO
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.darkCard,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color:
                          AppColors.primary.withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.factory_rounded,
                    color: AppColors.primary,
                    size: 54,
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'FactoryFlow',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  AppStrings.get('admin_subtitle'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 48),

                /// ADMIN ID
                TextField(
                  controller: _idCtrl,
                  style:
                      const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText:
                        AppStrings.get('admin_id'),
                    prefixIcon: const Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                /// PASSWORD
                TextField(
                  controller: _pwCtrl,
                  obscureText: !_pwVisible,
                  style:
                      const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText:
                        AppStrings.get('admin_password'),
                    prefixIcon: const Icon(
                      Icons.lock_rounded,
                      color: AppColors.primary,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _pwVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () => setState(() =>
                          _pwVisible = !_pwVisible),
                    ),
                  ),
                  onSubmitted: (_) => _activate(),
                ),

                /// ERROR
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.danger
                          .withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.danger
                            .withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.danger,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                /// BUTTON
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _loading ? null : _activate,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child:
                                CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            AppStrings.get('activate'),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 32),

                const Text(
                  'Powered by FactoryFlow v3',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
