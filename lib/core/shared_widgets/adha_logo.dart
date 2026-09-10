import 'package:flutter/material.dart';

/// Logo officiel de la marque Adha.
///
/// Encode la regle unique : clair -> monogramme bleu, sombre -> monogramme blanc.
/// Passez [dark] pour forcer la variante quand le fond est fixe
/// (ex. avatar blanc -> dark:false ; bandeau colore/sombre -> dark:true).
class AdhaLogo extends StatelessWidget {
  final double size;
  final bool? dark;

  const AdhaLogo({super.key, this.size = 24, this.dark});

  @override
  Widget build(BuildContext context) {
    final isDark = dark ?? Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      isDark
          ? 'assets/images/adha/adha_white.png'
          : 'assets/images/adha/adha_blue.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
