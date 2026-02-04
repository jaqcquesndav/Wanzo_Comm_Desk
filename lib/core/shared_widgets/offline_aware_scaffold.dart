// filepath: c:\Users\DevSpace\Flutter\wanzo\lib\core\shared_widgets\offline_aware_scaffold.dart

import 'package:flutter/material.dart';
import '../../features/connectivity/widgets/subtle_offline_indicator.dart';

/// Scaffold qui affiche un indicateur discret de connectivité
class OfflineAwareScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final Widget? endDrawer;
  final Color? backgroundColor;
  final bool extendBody;
  final bool extendBodyBehindAppBar;
  final bool showOfflineIndicator;
  /// Constructeur
  const OfflineAwareScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.drawer,
    this.endDrawer,
    this.backgroundColor,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.showOfflineIndicator = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBarWithIndicator(),
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      drawer: drawer,
      endDrawer: endDrawer,
      backgroundColor: backgroundColor,
      extendBody: extendBody,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
    );
  }
  
  /// Construit l'AppBar avec l'indicateur hors ligne
  PreferredSizeWidget? _buildAppBarWithIndicator() {
    if (appBar == null) return null;
    
    return PreferredSize(
      preferredSize: appBar!.preferredSize,
      child: Stack(
        children: [
          appBar!,
          if (showOfflineIndicator)
            Positioned(
              top: 5,
              right: 10,
              child: const SubtleOfflineIndicator(),
            ),
        ],
      ),
    );
  }
}
