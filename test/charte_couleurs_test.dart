import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genuc_mobile/core/theme/app_theme.dart';

/// Charte des couleurs, identique au portail web (charte-couleurs.css et
/// utils/actionsDestructives.js).
void main() {
  group('Actions qui retirent', () {
    test('les verbes de la charte sont destructifs', () {
      for (final l in [
        'Supprimer',
        'Rejeter',
        'Refuser',
        'Révoquer',
        'Renoncer',
        'Supprimer le brouillon',
        "Annuler l'inscription",
      ]) {
        expect(AppTheme.estDestructif(l), isTrue, reason: l);
      }
    });

    test('« Annuler » seul dans une fenêtre reste neutre', () {
      expect(AppTheme.estDestructif('Annuler'), isFalse);
      expect(AppTheme.estDestructif('Annuler', dansUneFenetre: false), isTrue);
    });

    test('un verbe en préfixe d\'un autre mot ne compte pas', () {
      expect(AppTheme.estDestructif('Refusées'), isFalse);
      expect(AppTheme.estDestructif('Publier'), isFalse);
      expect(AppTheme.estDestructif('Enregistrer'), isFalse);
    });
  });

  group('Couleurs', () {
    test('bleu marine et rouge de la charte', () {
      expect(AppTheme.accent, const Color(0xFF12396A));
      expect(AppTheme.error, const Color(0xFFB42318));
    });

    test('libellé blanc lisible sur les boutons pleins', () {
      const blanc = Color(0xFFFFFFFF);
      expect(AppTheme.contraste(blanc, AppTheme.accent),
          greaterThanOrEqualTo(AppTheme.ratioTexte));
      expect(AppTheme.contraste(blanc, AppTheme.accentLight),
          greaterThanOrEqualTo(AppTheme.ratioTexte));
      expect(AppTheme.contraste(blanc, AppTheme.error),
          greaterThanOrEqualTo(AppTheme.ratioTexte));
      expect(AppTheme.contraste(blanc, const Color(0xFFC8372C)),
          greaterThanOrEqualTo(AppTheme.ratioTexte));
    });

    test('bleu des liens lisible sur l\'ardoise opaque du thème sombre', () {
      expect(AppTheme.contraste(AppTheme.bleuLienSombre, const Color(0xFF1E293B)),
          greaterThanOrEqualTo(AppTheme.ratioTexte));
    });

    test('ambre du texte d\'avertissement lisible sur son fond', () {
      expect(AppTheme.contraste(AppTheme.ambreTexte, AppTheme.ambreFond),
          greaterThanOrEqualTo(AppTheme.ratioTexte));
    });
  });
}
