import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // Import go_router
import 'package:wanzo/constants/constants.dart';

/// Classe représentant une page d'onboarding
class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
  });
}

/// Écran d'onboarding affiché lors de la première utilisation de l'application
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Liste des pages d'onboarding
  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Gérez vos ventes',
      description:
          'Enregistrez facilement vos ventes, émettez des factures et suivez vos revenus en temps réel.',
      icon: Icons.shopping_cart,
    ),
    OnboardingPage(
      title: 'Contrôlez votre stock',
      description:
          'Suivez votre inventaire, recevez des alertes de stock bas et gérez vos approvisionnements.',
      icon: Icons.inventory,
    ),
    OnboardingPage(
      title: 'Analysez vos données',
      description:
          'Visualisez vos performances commerciales et prenez des décisions éclairées grâce aux tableaux de bord.',
      icon: Icons.bar_chart,
    ),
    OnboardingPage(
      title: 'Travaillez partout',
      description:
          'Accédez à vos données même sans connexion internet et synchronisez-les quand vous êtes en ligne.',
      icon: Icons.cloud_sync,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Passe à la page suivante ou termine l'onboarding
  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Fin de l'onboarding, redirection vers l'écran d'information Auth0
      context.go('/auth0_info');
    }
  }

  /// Passe à la dernière page pour sauter l'onboarding
  void _skipOnboarding() {
    context.go('/auth0_info');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Bouton pour sauter l'onboarding
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

            // Pages d'onboarding
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
                    padding: const EdgeInsets.all(WanzoSpacing.xl),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Calcul dynamique de la taille de l'icône selon l'espace disponible
                        final iconSize =
                            constraints.maxHeight > 300
                                ? 120.0
                                : constraints.maxHeight > 200
                                ? 80.0
                                : 50.0;
                        return SingleChildScrollView(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  page.icon,
                                  size: iconSize,
                                  color: WanzoColors.primary,
                                ),
                                const SizedBox(height: WanzoSpacing.lg),
                                Text(
                                  page.title,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: WanzoTypography.fontSizeXl,
                                    fontWeight: WanzoTypography.fontWeightBold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: WanzoSpacing.md),
                                Text(
                                  page.description,
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: WanzoTypography.fontSizeMd,
                                    fontWeight:
                                        WanzoTypography.fontWeightNormal,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            // Indicateurs de page
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        _currentPage == index
                            ? WanzoColors.primary
                            : Colors.grey.shade300,
                  ),
                ),
              ),
            ),

            // Bouton pour passer à la page suivante ou terminer
            Padding(
              padding: const EdgeInsets.all(WanzoSpacing.xl),
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
          ],
        ),
      ),
    );
  }
}
