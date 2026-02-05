import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wanzo/l10n/app_localizations.dart';
import 'package:wanzo/core/platform/platform_service.dart';
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
    final screenWidth = MediaQuery.of(context).size.width;
    final platform = PlatformService.instance;
    final isDesktop = screenWidth >= platform.desktopMinWidth;
    final isTablet = screenWidth >= platform.tabletMinWidth && !isDesktop;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Vérifier s'il y a une page précédente dans la pile de navigation
            if (context.canPop()) {
              context.pop();
            } else {
              // Si navigué via sidebar (go), retourner au dashboard
              context.go('/dashboard');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.searchSettings,
            onPressed: () {
              // TODO: Implement search functionality
            },
          ),
        ],
      ),
      body: BlocConsumer<SettingsBloc, SettingsState>(
        listener: (context, state) {
          if (state is SettingsError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          } else if (state is SettingsUpdated) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.changesSaved)));
          }
        },
        builder: (context, state) {
          if (state is SettingsLoading) {
            return Center(child: Text(l10n.loadingSettings));
          } else if (state is SettingsLoaded || state is SettingsUpdated) {
            final settings =
                state is SettingsLoaded
                    ? state.settings
                    : (state as SettingsUpdated).settings;

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth:
                      isDesktop ? 1200 : (isTablet ? 800 : double.infinity),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(
                    isDesktop ? 32 : (isTablet ? 24 : 16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/images/logo_with_text.png',
                              height: isDesktop ? 80 : 60,
                              errorBuilder: (context, error, stackTrace) {
                                return Text(
                                  l10n.wanzoFallbackText,
                                  style: TextStyle(
                                    fontSize: isDesktop ? 36 : 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.appVersion,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildSettingsList(settings, l10n, isDesktop, isTablet),
                    ],
                  ),
                ),
              ),
            );
          }
          return Center(child: Text(l10n.loadingSettings));
        },
      ),
    );
  }

  Widget _buildSettingsList(
    Settings settings,
    AppLocalizations l10n,
    bool isDesktop,
    bool isTablet,
  ) {
    final settingsItems = [
      _SettingsItem(
        icon: Icons.business,
        title: l10n.companyInformation,
        subtitle: l10n.companyInformationSubtitle,
        onTap: () => _navigateToCompanySettings(settings),
      ),
      _SettingsItem(
        icon: Icons.receipt_long,
        title: l10n.invoiceSettings,
        subtitle: l10n.invoiceSettingsSubtitle,
        onTap: () => _navigateToInvoiceSettings(settings),
      ),
      _SettingsItem(
        icon: Icons.account_balance_wallet,
        title: l10n.financeSettings,
        subtitle: l10n.financeSettingsSubtitle,
        onTap: () => _navigateToFinancialSettings(),
      ),
      _SettingsItem(
        icon: Icons.palette,
        title: l10n.appearanceAndDisplay,
        subtitle: l10n.appearanceAndDisplaySubtitle,
        onTap: () => _navigateToDisplaySettings(settings),
      ),
      _SettingsItem(
        icon: Icons.inventory_2,
        title: l10n.inventorySettings,
        subtitle: l10n.inventorySettingsSubtitle,
        onTap: () => _navigateToInventorySettings(settings),
      ),
      _SettingsItem(
        icon: Icons.backup,
        title: l10n.backupAndReports,
        subtitle: l10n.backupAndReportsSubtitle,
        onTap: () => _navigateToBackupSettings(settings),
      ),
      _SettingsItem(
        icon: Icons.notifications,
        title: l10n.notifications,
        subtitle: l10n.notificationsSubtitle,
        onTap: () => _navigateToNotificationSettings(settings),
      ),
      _SettingsItem(
        icon: Icons.security,
        title: 'Sécurité locale',
        subtitle: 'Verrouillage par code PIN et sécurité hors ligne',
        onTap: () => _navigateToSecuritySettings(),
      ),
    ];

    // Desktop: grille 3 colonnes, Tablet: 2 colonnes, Mobile: liste
    if (isDesktop || isTablet) {
      final crossAxisCount = isDesktop ? 3 : 2;
      return Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isDesktop ? 2.0 : 1.8,
            ),
            itemCount: settingsItems.length,
            itemBuilder: (context, index) {
              final item = settingsItems[index];
              return _buildDesktopSettingsCard(
                icon: item.icon,
                title: item.title,
                subtitle: item.subtitle,
                onTap: item.onTap,
              );
            },
          ),
          const SizedBox(height: 24),
          SizedBox(width: 300, child: _buildResetButton(l10n)),
        ],
      );
    }

    // Mobile: liste classique
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        ...settingsItems.map(
          (item) => _buildSettingsCard(
            icon: item.icon,
            title: item.title,
            subtitle: item.subtitle,
            onTap: item.onTap,
          ),
        ),
        const SizedBox(height: 16),
        _buildResetButton(l10n),
      ],
    );
  }

  Widget _buildDesktopSettingsCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).primaryColor.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, size: 40, color: Theme.of(context).primaryColor),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
      MaterialPageRoute(builder: (context) => const SecuritySettingsScreen()),
    );
  }
}

/// Helper class pour définir les items de settings
class _SettingsItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
