import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Écran de démarrage, affiché le temps de restaurer la session.
///
/// Prolonge exactement l'écran natif (`launch_background.xml`) : même fond
/// bleu nuit, même logo à la même place, pour que la bascule vers Flutter ne
/// se voie pas. Le logo est affiché tel quel — sa version claire est faite
/// pour ce fond de marque, comme sur le portail web.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image(
              image: AssetImage('assets/images/logo-genuc.png'),
              width: 180,
              height: 180,
              fit: BoxFit.contain,
            ),
            SizedBox(height: 40),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
