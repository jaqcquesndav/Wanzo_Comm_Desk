import 'package:flutter/material.dart';
import '../../services/export/table_export_service.dart';

/// Bouton d'export discret pour les tables de données
/// Affiche un dropdown avec les options PDF, Excel, CSV
class TableExportButton extends StatelessWidget {
  /// Configuration de l'export
  final TableExportConfig config;

  /// Callback appelé avant l'export (pour afficher un loader par exemple)
  final VoidCallback? onExportStart;

  /// Callback appelé après l'export
  final void Function(bool success)? onExportEnd;

  /// Style du bouton (par défaut discret/outlined)
  final bool isOutlined;

  /// Taille du bouton
  final ButtonSize size;

  /// Icône personnalisée
  final IconData? icon;

  /// Tooltip personnalisé
  final String? tooltip;

  const TableExportButton({
    super.key,
    required this.config,
    this.onExportStart,
    this.onExportEnd,
    this.isOutlined = true,
    this.size = ButtonSize.small,
    this.icon,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ExportFormat>(
      tooltip: tooltip ?? 'Exporter les données',
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: _buildButton(context),
      onSelected: (format) => _handleExport(context, format),
      itemBuilder:
          (context) => [
            _buildMenuItem(
              context,
              ExportFormat.pdf,
              Icons.picture_as_pdf,
              'Exporter en PDF',
              'Format idéal pour l\'impression',
              Colors.red,
            ),
            const PopupMenuDivider(),
            _buildMenuItem(
              context,
              ExportFormat.xlsx,
              Icons.table_chart,
              'Exporter en Excel',
              'Format .xlsx compatible Excel',
              Colors.green,
            ),
            const PopupMenuDivider(),
            _buildMenuItem(
              context,
              ExportFormat.csv,
              Icons.description,
              'Exporter en CSV',
              'Format universel pour tableaux',
              Colors.blue,
            ),
          ],
    );
  }

  Widget _buildButton(BuildContext context) {
    final theme = Theme.of(context);
    final buttonPadding = _getButtonPadding();
    final iconSize = _getIconSize();

    if (isOutlined) {
      return Container(
        padding: buttonPadding,
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? Icons.file_download_outlined,
              size: iconSize,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              'Exporter',
              style: TextStyle(
                fontSize: _getFontSize(),
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: iconSize,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: buttonPadding,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon ?? Icons.file_download_outlined,
            size: iconSize,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            'Exporter',
            style: TextStyle(fontSize: _getFontSize(), color: Colors.white),
          ),
          const SizedBox(width: 2),
          Icon(Icons.arrow_drop_down, size: iconSize, color: Colors.white),
        ],
      ),
    );
  }

  PopupMenuItem<ExportFormat> _buildMenuItem(
    BuildContext context,
    ExportFormat format,
    IconData icon,
    String title,
    String subtitle,
    Color iconColor,
  ) {
    return PopupMenuItem<ExportFormat>(
      value: format,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExport(BuildContext context, ExportFormat format) async {
    onExportStart?.call();

    final success = await TableExportService().export(
      context: context,
      config: config,
      format: format,
    );

    onExportEnd?.call(success);
  }

  EdgeInsets _getButtonPadding() {
    switch (size) {
      case ButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: 8, vertical: 6);
      case ButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case ButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
    }
  }

  double _getIconSize() {
    switch (size) {
      case ButtonSize.small:
        return 16;
      case ButtonSize.medium:
        return 18;
      case ButtonSize.large:
        return 20;
    }
  }

  double _getFontSize() {
    switch (size) {
      case ButtonSize.small:
        return 12;
      case ButtonSize.medium:
        return 14;
      case ButtonSize.large:
        return 16;
    }
  }
}

/// Tailles du bouton
enum ButtonSize { small, medium, large }

/// Version icône seule du bouton d'export (encore plus discret)
class TableExportIconButton extends StatelessWidget {
  final TableExportConfig config;
  final VoidCallback? onExportStart;
  final void Function(bool success)? onExportEnd;
  final double? iconSize;
  final Color? iconColor;

  const TableExportIconButton({
    super.key,
    required this.config,
    this.onExportStart,
    this.onExportEnd,
    this.iconSize,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopupMenuButton<ExportFormat>(
      tooltip: 'Exporter les données',
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      icon: Icon(
        Icons.file_download_outlined,
        size: iconSize ?? 20,
        color: iconColor ?? theme.colorScheme.primary,
      ),
      onSelected: (format) => _handleExport(context, format),
      itemBuilder:
          (context) => [
            PopupMenuItem<ExportFormat>(
              value: ExportFormat.pdf,
              child: _buildSimpleMenuItem(
                Icons.picture_as_pdf,
                'PDF',
                Colors.red,
              ),
            ),
            PopupMenuItem<ExportFormat>(
              value: ExportFormat.xlsx,
              child: _buildSimpleMenuItem(
                Icons.table_chart,
                'Excel',
                Colors.green,
              ),
            ),
            PopupMenuItem<ExportFormat>(
              value: ExportFormat.csv,
              child: _buildSimpleMenuItem(
                Icons.description,
                'CSV',
                Colors.blue,
              ),
            ),
          ],
    );
  }

  Widget _buildSimpleMenuItem(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(label),
      ],
    );
  }

  Future<void> _handleExport(BuildContext context, ExportFormat format) async {
    onExportStart?.call();

    final success = await TableExportService().export(
      context: context,
      config: config,
      format: format,
    );

    onExportEnd?.call(success);
  }
}
