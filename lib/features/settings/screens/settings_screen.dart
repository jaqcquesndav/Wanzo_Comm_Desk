import 'package:wanzo/core/utils/offline_write_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wanzo/l10n/app_localizations.dart';
import 'package:wanzo/core/platform/platform_service.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/enums/user_role.dart';
import 'package:wanzo/core/auth/user_rights.dart';
import 'package:wanzo/core/modules/activity_mode.dart';
import 'package:wanzo/core/modules/module_registry.dart';
import 'package:wanzo/core/shared_widgets/wanzo_scaffold.dart';
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
import 'printer_settings_screen.dart';
import '../../business_unit/widgets/join_business_unit_dialog.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/models/join_request.dart' show canDecideJoinRequests;
import '../../auth/services/join_request_service.dart';
import '../../users/screens/join_requests_screen.dart';

/// Écran principal des paramètres
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _pendingJoinRequests = 0;

  @override
  void initState() {
    super.initState();
    // Charge les paramètres au démarrage
    context.read<SettingsBloc>().add(const LoadSettings());
    _loadPendingJoinRequests();
  }

  /// Administrateur ou propriétaire : seuls à décider des demandes.
  bool _canDecideJoinRequests() {
    final authState = context.read<AuthBloc>().state;
    return authState is AuthAuthenticated &&
        canDecideJoinRequests(authState.user.role);
  }

  /// Administrateur, super administrateur ou comptable (comptes financiers).
  bool _isAdminOrAccountant() {
    // Même source que le choix du mode (UserRights), propriétaire compris.
    return UserRights.isAdmin() ||
        (UserRights.role()?.canManageFinancialAccounts ?? false);
  }

  /// Nombre de demandes en attente (badge). Hors ligne, le badge reste vide :
  /// la liste elle-même dira qu'il faut le réseau.
  Future<void> _loadPendingJoinRequests() async {
    if (!_canDecideJoinRequests()) return;
    try {
      final count = await JoinRequestService().pendingCount();
      if (mounted) setState(() => _pendingJoinRequests = count);
    } catch (_) {}
  }

  Future<void> _openJoinRequests() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const JoinRequestsScreen()),
    );
    if (mounted) _loadPendingJoinRequests();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final platform = PlatformService.instance;
    final isDesktop = screenWidth >= platform.desktopMinWidth;
    final isTablet = screenWidth >= platform.tabletMinWidth && !isDesktop;

    return WanzoScaffold(
      currentIndex: -1, // onglet actif dérivé de la route par le scaffold
      title: l10n.settingsTitle,
      onBackPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/dashboard');
        }
      },
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
    // Sections thématiques façon Windows 11 : liste verticale à colonne unique,
    // chaque entrée = icône + titre + sous-titre + chevron (style ListTile).
    final sections = <_SettingsSection>[
      _SettingsSection(
        title: l10n.settingsTitle,
        items: [
          _SettingsItem(
            icon: Icons.storefront,
            title: 'Mode d\'activité',
            subtitle: BusinessContextService().canChangeActivityMode
                ? 'Configuration de l\'app : ${BusinessContextService().activityMode.label}'
                : '${BusinessContextService().activityMode.label} (choisi par l\'administrateur)',
            onTap: _showActivityModePicker,
          ),
          _SettingsItem(
            icon: Icons.account_tree_outlined,
            title: "Unité d'affaires",
            subtitle: _uniteCouranteLibelle(),
            onTap: _rejoindreUnite,
          ),
          if (_canDecideJoinRequests())
            _SettingsItem(
              icon: Icons.how_to_reg_outlined,
              title: 'Demandes de rattachement',
              subtitle: _pendingJoinRequests > 0
                  ? '$_pendingJoinRequests en attente de votre accord'
                  : 'Personnes qui demandent à rejoindre l\'entreprise',
              badgeCount: _pendingJoinRequests,
              onTap: _openJoinRequests,
            ),
          _SettingsItem(
            icon: Icons.security,
            title: 'Sécurité locale',
            subtitle: 'Verrouillage par code PIN et sécurité hors ligne',
            onTap: () => _navigateToSecuritySettings(),
          ),
        ],
      ),
      _SettingsSection(
        title: l10n.companyInformation,
        items: [
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
          // Comptes financiers (banque, Mobile Money) : administrateur ou
          // comptable seulement, comme sur mobile.
          if (_isAdminOrAccountant())
            _SettingsItem(
              icon: Icons.account_balance_wallet,
              title: l10n.financeSettings,
              subtitle: l10n.financeSettingsSubtitle,
              onTap: () => _navigateToFinancialSettings(),
            ),
        ],
      ),
      _SettingsSection(
        title: l10n.inventorySettings,
        items: [
          _SettingsItem(
            icon: Icons.inventory_2,
            title: l10n.inventorySettings,
            subtitle: l10n.inventorySettingsSubtitle,
            onTap: () => _navigateToInventorySettings(settings),
          ),
          _SettingsItem(
            icon: Icons.print,
            title: l10n.printerSettingsTitle,
            subtitle: l10n.printerSettingsSubtitle,
            onTap: () => _navigateToPrinterSettings(),
          ),
        ],
      ),
      _SettingsSection(
        title: l10n.appearanceAndDisplay,
        items: [
          _SettingsItem(
            icon: Icons.palette,
            title: l10n.appearanceAndDisplay,
            subtitle: l10n.appearanceAndDisplaySubtitle,
            onTap: () => _navigateToDisplaySettings(settings),
          ),
          _SettingsItem(
            icon: Icons.notifications,
            title: l10n.notifications,
            subtitle: l10n.notificationsSubtitle,
            onTap: () => _navigateToNotificationSettings(settings),
          ),
          _SettingsItem(
            icon: Icons.backup,
            title: l10n.backupAndReports,
            subtitle: l10n.backupAndReportsSubtitle,
            onTap: () => _navigateToBackupSettings(settings),
          ),
        ],
      ),
    ];

    // Colonne unique centrée, largeur confortable pour écran large.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 840),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final section in sections) ...[
            _buildSectionHeader(section.title),
            Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  for (var i = 0; i < section.items.length; i++) ...[
                    if (i > 0) const Divider(height: 1, indent: 72),
                    _buildSettingsTile(section.items[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 8),
          _buildResetButton(l10n),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(_SettingsItem item) {
    final icon = Icon(
      item.icon,
      size: 28,
      color: Theme.of(context).primaryColor,
    );
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: item.badgeCount > 0
          ? Badge(
              label: Text(item.badgeCount > 99 ? '99+' : '${item.badgeCount}'),
              child: icon,
            )
          : icon,
      title: Text(
        item.title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(item.subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: item.onTap,
    );
  }

  /// Sélecteur de mode d'activité, réservé aux administrateurs. Le mode est
  /// écrit sur la fiche de l'entreprise (tous les postes le reçoivent) et
  /// recompose la navigation via [BusinessContextService.setActivityMode].
  Future<void> _showActivityModePicker() async {
    final ctx = BusinessContextService();
    final messenger = ScaffoldMessenger.of(context);
    // Droits relus quand ils sont inconnus, ou quand ils disent « pas
    // administrateur » et datent de plus de 5 minutes (rôle resté en cache).
    var rights = UserRights.adminStatus(ctx);
    if (rights == AdminRightsStatus.unknown) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Vérification de vos droits…')),
      );
      await RoleRefresh.instance.refreshNow('choix du mode');
      messenger.hideCurrentSnackBar();
    } else if (rights == AdminRightsStatus.notAdmin) {
      await RoleRefresh.instance.refreshIfStale('choix du mode');
    }
    rights = UserRights.adminStatus(ctx);
    if (!mounted) return;
    final current = ctx.activityMode;
    if (rights != AdminRightsStatus.admin) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            rights == AdminRightsStatus.unknown
                ? 'Vérification de vos droits impossible pour le moment. Réessayez une fois connecté.'
                : 'Seul un administrateur de l\'entreprise change le mode d\'activité.',
          ),
        ),
      );
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Mode d\'activité'),
          content: SizedBox(
            width: 420,
            // Défilable : avec 5 modes, le contenu pourrait dépasser la hauteur
            // de la fenêtre sur petit écran → évite le débordement.
            child: SingleChildScrollView(
              child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // App boutique/commerce : hôtellerie vit dans l'app Assets,
                // et « services » est couvert par la facturation → non listés.
                for (final mode in const [
                  ActivityMode.retail,
                  ActivityMode.restaurant,
                  ActivityMode.atelier,
                  ActivityMode.atelierMaintenance,
                  ActivityMode.salon,
                  ActivityMode.imprimerie,
                  ActivityMode.pressing,
                  ActivityMode.garage,
                ])
                  RadioListTile<ActivityMode>(
                    value: mode,
                    groupValue: current,
                    title: Text(mode.label),
                    subtitle: Text(mode.description),
                    onChanged: (selected) async {
                      if (selected == null) return;
                      Navigator.of(dialogContext).pop();
                      final erreur = await ctx.setActivityMode(selected);
                      if (!mounted) return;
                      setState(() {}); // rafraîchir le sous-titre de la carte
                      if (erreur != null) {
                        // Hors ligne : en attente ; refus : motif affiché.
                        showWriteOutcome(
                          context,
                          erreur,
                          failureLabel: 'Mode non enregistré',
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Mode : ${selected.label}')),
                        );
                      }
                      // Le shell écoute BusinessContextService : la nav se
                      // recompose immédiatement. On atterrit sur la 1re
                      // destination du nouveau mode pour ne pas rester sur un
                      // écran devenu hors-nav.
                      final nav = ModuleRegistry.sidebar(
                        ctx.activityMode,
                        ctx.currentContext?.userRole,
                      );
                      if (nav.isNotEmpty && context.mounted) {
                        context.go(nav.first.route);
                      }
                    },
                  ),
              ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
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

  void _navigateToPrinterSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrinterSettingsScreen()),
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

  /// Ce que l'utilisateur voit comme rattachement courant.
  String _uniteCouranteLibelle() {
    final contexte = BusinessContextService();
    final nom = contexte.businessUnitName ?? contexte.businessUnitCode;
    return nom == null
        ? "Vous travaillez au niveau de l'entreprise"
        : 'Rattaché à : $nom';
  }

  /// Changement d'unité d'affaires : saisie du code, ou retour à l'entreprise.
  Future<void> _rejoindreUnite() async {
    final change = await JoinBusinessUnitDialog.show(context);
    if (change != true || !mounted) return;

    final contexte = BusinessContextService();
    final libelle = contexte.businessUnitName ??
        contexte.businessUnitCode ??
        "l'entreprise générale";

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Vous travaillez maintenant sur $libelle')),
    );

    // Les caches de l'unité précédente ont été vidés : on retourne au tableau
    // de bord pour que les écrans se reconstruisent sur les nouvelles données,
    // plutôt que de garder en mémoire celles de l'unité quittée.
    context.go('/dashboard');
  }

  void _navigateToSecuritySettings() {
    // Par le routeur : l'ecran porte le shell commun (WanzoScaffold), qui lit
    // l'etat de la route courante.
    context.push('/settings/security');
  }
}

/// Helper class pour définir les items de settings
class _SettingsItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badgeCount;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeCount = 0,
  });
}

/// Helper class pour regrouper les items de settings en sections
class _SettingsSection {
  final String title;
  final List<_SettingsItem> items;

  const _SettingsSection({required this.title, required this.items});
}
