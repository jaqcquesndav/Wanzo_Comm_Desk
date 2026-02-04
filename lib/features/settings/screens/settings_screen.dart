import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wanzo/l10n/app_localizations.dart'; // Corrected import
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import '../models/settings.dart';
import 'company_settings_screen.dart';
import 'invoice_settings_screen.dart';
import 'display_settings_screen.dart';
import 'inventory_settings_screen.dart';
import 'backup_settings_screen.dart';
import 'notification_settings_screen.dart';
import 'financial_account_settings_screen.dart';
import '../../security/screens/security_settings_screen.dart';

/// Écran principal des paramètres
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Charge les paramètres au démarrage
    context.read<SettingsBloc>().add(const LoadSettings());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle), // Localized
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            context.pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.searchSettings, // Localized
            onPressed: () {
              // TODO: Implement search functionality
            },
          ),
        ],
      ),
      body: BlocConsumer<SettingsBloc, SettingsState>(
        listener: (context, state) {
          if (state is SettingsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)), // Potentially localize if message is generic
            );
          } else if (state is SettingsUpdated) {
             ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.changesSaved)), // Localized
            );
          }
        },
        builder: (context, state) {
          if (state is SettingsLoading) {
            return Center(child: Text(l10n.loadingSettings)); // Localized
          } else if (state is SettingsLoaded || state is SettingsUpdated) {
            final settings = state is SettingsLoaded
                ? state.settings
                : (state as SettingsUpdated).settings;
            
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/logo_with_text.png',
                          height: 60,
                          errorBuilder: (context, error, stackTrace) {
                            return Text(
                              l10n.wanzoFallbackText, // Localized
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.appVersion, // Corrected: appVersion is a direct string
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildSettingsList(settings, l10n),
                ],
              ),
            );
          }
          return Center(child: Text(l10n.loadingSettings)); // Localized
        },
      ),
    );
  }

  Widget _buildSettingsList(Settings settings, AppLocalizations l10n) {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildSettingsCard(
          icon: Icons.business,
          title: l10n.companyInformation, // Localized
          subtitle: l10n.companyInformationSubtitle, // Localized
          onTap: () => _navigateToCompanySettings(settings),
        ),
        _buildSettingsCard(
          icon: Icons.receipt_long,
          title: l10n.invoiceSettings, // Localized
          subtitle: l10n.invoiceSettingsSubtitle, // Localized
          onTap: () => _navigateToInvoiceSettings(settings),
        ),
        _buildSettingsCard(
          icon: Icons.account_balance_wallet,
          title: l10n.financeSettings, // Localized
          subtitle: l10n.financeSettingsSubtitle, // Localized
          onTap: () => _navigateToFinancialSettings(),
        ),
        _buildSettingsCard(
          icon: Icons.palette,
          title: l10n.appearanceAndDisplay, // Localized
          subtitle: l10n.appearanceAndDisplaySubtitle, // Localized
          onTap: () => _navigateToDisplaySettings(settings),
        ),
        _buildSettingsCard(
          icon: Icons.inventory_2,
          title: l10n.inventorySettings, // Localized
          subtitle: l10n.inventorySettingsSubtitle, // Localized
          onTap: () => _navigateToInventorySettings(settings),
        ),
        _buildSettingsCard(
          icon: Icons.backup,
          title: l10n.backupAndReports, // Localized
          subtitle: l10n.backupAndReportsSubtitle, // Localized
          onTap: () => _navigateToBackupSettings(settings),
        ),
        _buildSettingsCard(
          icon: Icons.notifications,
          title: l10n.notifications, // Localized
          subtitle: l10n.notificationsSubtitle, // Localized
          onTap: () => _navigateToNotificationSettings(settings),
        ),
        _buildSettingsCard(
          icon: Icons.security,
          title: 'Sécurité locale',
          subtitle: 'Verrouillage par code PIN et sécurité hors ligne',
          onTap: () => _navigateToSecuritySettings(),
        ),
        const SizedBox(height: 16),
        _buildResetButton(l10n),
      ],
    );
  }

  Widget _buildSettingsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Icon(
          icon,
          size: 40,
          color: Theme.of(context).primaryColor,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildResetButton(AppLocalizations l10n) {
    return ElevatedButton.icon(
      onPressed: () => _confirmReset(l10n),
      icon: const Icon(Icons.restore),
      label: Text(l10n.resetSettings), // Localized
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }

  void _confirmReset(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.resetSettings), // Localized
          content: Text(l10n.confirmResetSettings), // Localized
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel), // Localized
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.read<SettingsBloc>().add(const ResetSettings());
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(l10n.reset), // Localized
            ),
          ],
        );
      },
    );
  }

  void _navigateToCompanySettings(Settings settings) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CompanySettingsScreen(settings: settings),
      ),
    );
  }

  void _navigateToInvoiceSettings(Settings settings) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InvoiceSettingsScreen(settings: settings),
      ),
    );
  }

  void _navigateToDisplaySettings(Settings settings) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DisplaySettingsScreen(settings: settings),
      ),
    );
  }

  void _navigateToInventorySettings(Settings settings) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InventorySettingsScreen(settings: settings),
      ),
    );
  }

  void _navigateToBackupSettings(Settings settings) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BackupSettingsScreen(settings: settings),
      ),
    );
  }

  void _navigateToNotificationSettings(Settings settings) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NotificationSettingsScreen(settings: settings),
      ),
    );
  }

  void _navigateToFinancialSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FinancialAccountSettingsScreen(),
      ),
    );
  }

  void _navigateToSecuritySettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SecuritySettingsScreen(),
      ),
    );
  }
}
