import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wanzo/constants/constants.dart';
import 'package:wanzo/core/platform/platform_service.dart';

/// Classe représentant une page d'onboarding
class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final String? desktopDescription; // Description plus détaillée pour desktop

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    this.desktopDescription,
  });
}

/// Écran d'onboarding affiché lors de la première utilisation de l'application
/// Adapté pour mobile et desktop
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final PlatformService _platform = PlatformService.instance;
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Gérez vos ventes',
      description:
          'Enregistrez facilement vos ventes, émettez des factures et suivez vos revenus en temps réel.',
      desktopDescription:
          'Interface optimisée pour gérer efficacement vos ventes quotidiennes. Créez des factures professionnelles, suivez les paiements et analysez vos performances commerciales avec des tableaux de bord détaillés.',
      icon: Icons.shopping_cart,
    ),
    OnboardingPage(
      title: 'Contrôlez votre stock',
      description:
          'Suivez votre inventaire, recevez des alertes de stock bas et gérez vos approvisionnements.',
      desktopDescription:
          'Gestion avancée des stocks avec suivi en temps réel, alertes automatiques de réapprovisionnement, codes-barres et historique complet des mouvements de stock.',
      icon: Icons.inventory,
    ),
    OnboardingPage(
      title: 'Analysez vos données',
      description:
          'Visualisez vos performances commerciales et prenez des décisions éclairées grâce aux tableaux de bord.',
      desktopDescription:
          'Tableaux de bord analytiques puissants avec graphiques interactifs, rapports exportables et indicateurs clés de performance pour optimiser votre activité.',
      icon: Icons.bar_chart,
    ),
    OnboardingPage(
      title: 'Travaillez partout',
      description:
          'Accédez à vos données même sans connexion internet et synchronisez-les quand vous êtes en ligne.',
      desktopDescription:
          'Synchronisation transparente entre tous vos appareils. Travaillez hors ligne sur desktop et retrouvez vos données actualisées sur mobile et vice versa.',
      icon: Icons.cloud_sync,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/auth0_info');
    }
  }

  void _skipOnboarding() {
    context.go('/auth0_info');
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width >= _platform.desktopMinWidth;
    final isTablet = screenSize.width >= _platform.tabletMinWidth && !isDesktop;

    if (isDesktop) {
      return _buildDesktopLayout(context);
    }

    return _buildMobileLayout(context, isTablet);
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Panneau gauche avec illustration
          Expanded(
            flex: 5,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    WanzoColors.primary,
                    WanzoColors.primary.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Pattern décoratif
                  Positioned(
                    top: -100,
                    right: -100,
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -50,
                    left: -50,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                  // Contenu principal
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(48),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              _pages[_currentPage].icon,
                              key: ValueKey(_currentPage),
                              size: 150,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'WANZO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Solution de gestion commerciale',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Panneau droit avec contenu
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Skip button
                  Align(
                    alignment: Alignment.topRight,
                    child: TextButton(
                      onPressed: _skipOnboarding,
                      child: Text(
                        'Passer',
                        style: TextStyle(
                          color: WanzoColors.primary,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Contenu de la page
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Column(
                      key: ValueKey(_currentPage),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pages[_currentPage].title,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _pages[_currentPage].desktopDescription ??
                              _pages[_currentPage].description,
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.black54,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Indicateurs et bouton
                  Row(
                    children: [
                      // Page indicators
                      ...List.generate(
                        _pages.length,
                        (index) => GestureDetector(
                          onTap: () {
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: _currentPage == index ? 32 : 12,
                            height: 12,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color:
                                  _currentPage == index
                                      ? WanzoColors.primary
                                      : Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Next button
                      ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: WanzoColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentPage < _pages.length - 1
                                  ? 'Suivant'
                                  : 'Commencer',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _currentPage < _pages.length - 1
                                  ? Icons.arrow_forward
                                  : Icons.login,
                              color: Colors.white,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, bool isTablet) {
    final iconSize = isTablet ? 100.0 : 80.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: WanzoSpacing.md,
                  right: WanzoSpacing.md,
                ),
                child: TextButton(
                  onPressed: _skipOnboarding,
                  child: Text(
                    'Passer',
                    style: TextStyle(
                      color: WanzoColors.primary,
                      fontSize: WanzoTypography.fontSizeMd,
                      fontWeight: WanzoTypography.fontWeightMedium,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: EdgeInsets.all(
                      isTablet ? WanzoSpacing.xxl : WanzoSpacing.xl,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(isTablet ? 32 : 24),
                          decoration: BoxDecoration(
                            color: WanzoColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            page.icon,
                            size: iconSize,
                            color: WanzoColors.primary,
                          ),
                        ),
                        SizedBox(height: isTablet ? 48 : WanzoSpacing.lg),
                        Text(
                          page.title,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize:
                                isTablet ? 28 : WanzoTypography.fontSizeXl,
                            fontWeight: WanzoTypography.fontWeightBold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isTablet ? 24 : WanzoSpacing.md),
                        Container(
                          constraints: BoxConstraints(
                            maxWidth: isTablet ? 500 : double.infinity,
                          ),
                          child: Text(
                            isTablet
                                ? (page.desktopDescription ?? page.description)
                                : page.description,
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize:
                                  isTablet ? 18 : WanzoTypography.fontSizeMd,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Indicateurs
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 12,
                  height: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color:
                        _currentPage == index
                            ? WanzoColors.primary
                            : Colors.grey.shade300,
                  ),
                ),
              ),
            ),
            // Bouton
            Padding(
              padding: EdgeInsets.all(
                isTablet ? WanzoSpacing.xxl : WanzoSpacing.xl,
              ),
              child: SizedBox(
                width: isTablet ? 300 : double.infinity,
                child: ElevatedButton(
                  onPressed: _nextPage,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(WanzoBorderRadius.md),
                    ),
                  ),
                  child: Text(
                    _currentPage < _pages.length - 1 ? 'Suivant' : 'Commencer',
                    style: const TextStyle(
                      fontSize: WanzoTypography.fontSizeMd,
                      fontWeight: WanzoTypography.fontWeightMedium,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
