# Guide de publication — GENUC Mobile sur Google Play

> **Date** : août 2026 — **Version** : 1.0.0 (build 1)
> **Applicable** à la fois au portail étudiant et à l'app « Genuc » (mêmes étapes).

Ce guide couvre la publication **avec Play App Signing**, la méthode recommandée et
**obligatoire** pour les nouvelles apps sur Google Play. Elle diffère de la signature
directe que nous avons configurée localement : Google conserve la clé d'app et signe
lui-même les APK distribués, tandis que votre keystore local devient la **clé de
téléversement** (upload key) qui n'ouvre que votre console Play.

---

## 1. Prérequis

| Élément | État chez nous | Où |
|---|---|---|
| Compte développeur Google Play | À créer — **25 $ US, frais uniques** | https://play.google.com/console |
| Keystore upload | ✅ `android/upload-keystore.jks` | `GENUC PACK/Genuc-Mobile/android/` |
| `key.properties` (mot de passe) | ✅ (ignoré par git) | `GENUC PACK/Genuc-Mobile/android/` |
| SDK Java 21 + Flutter | ✅ | — |

**Avant de commencer, faites 2 sauvegardes hors ligne** (disque externe, coffre-fort,
gestionnaire de mots de passe) :
1. `android/upload-keystore.jks`
2. le mot de passe `@Bamo4525`

> ⚠️ Sans la clé upload **et** son mot de passe, il est impossible de mettre à jour
> l'application (ni Play App Signing, ni Google ne peuvent régénérer votre clé de
> téléversement).

---

## 2. Générer l'AAB (format requis par Google Play)

Google Play n'accepte **plus les APK pour les nouvelles apps** : il exige un
**Android App Bundle (`.aab`)**.

```bash
cd "GENUC PACK/Genuc-Mobile"
flutter build appbundle --release
```

Résultat :
```
build/app/outputs/bundle/release/app-release.aab
```

> L'AAB est déjà signé avec votre clé upload (la config `signingConfigs.release` du
> `build.gradle.kts` s'applique aussi au bundle). Le fichier fait quelques Mo — c'est
> Google qui en dérive les APK par architecture lors de la distribution.

---

## 3. Créer l'app dans la console Play

1. Connectez-vous sur https://play.google.com/console
2. **Créer une application** :
   - **Nom** : `GENUC` (ou `GENUC Mobile`)
   - **Langue** : Français (RDC)
   - **Type d'app** : Application
   - **Gratuite ou payante** : Gratuite (vous pourrez ajouter des achats intégrés
     plus tard si besoin)
   - Cochez la case des politiques → **Créer**

3. **Configurer la fiche du store** (menu « Contenu de l'app » → « Fiche du store ») :
   - **Brève description** (80 caractères max) :
     ```
     Portail universitaire GENUC : notes, cours, paiements et présence en salle.
     ```
   - **Description complète** (4000 caractères max) — exemple à adapter :
     ```
     GENUC Mobile est le portail officiel de la Plateforme Nationale de Gestion
     Universitaire (RDC). Les étudiants retrouvent :
     • Tableau de bord académique (moyenne, crédits, situation financière)
     • Notes et relevés de notes
     • Cours et leçons, avec progression
     • Paiement des frais et historique
     • Notifications officielles de l'université
     • Smart Présence : marquez votre présence en salle en scannant le QR du
       professeur, avec vérification de proximité
     ```
   - **Catégorie** : Éducation
   - **Icône** : 512×512 px (`assets/images/logo-genuc.png` — demandez une version
     carrée au design si besoin)
   - **Visuels du store** : 2 à 8 captures d'écran (téléphone, ≥ 320 px de large) —
     réalisez-les sur un émulateur/écran réel
   - **Image de fonctionnalité** : 1024×500 px
   - **Type d'appli** : Privée ou publique selon votre diffusion

4. **Classement et contacts** (menu « Contenu de l'app ») :
   - Email de contact obligatoire (ex : contact@genuc.cd)
   - Site web optionnel

5. **Politique de confidentialité** :
   - **Obligatoire dès que l'app collecte des données** (GENUC collecte position,
     appareil, données académiques)
   - Hébergez un fichier PDF/HTML (ex : `https://genuc.cd/confidentialite`)
   - Indiquez les types de données : « Informations personnelles » (nom, email,
     téléphone), « Position approximative » (Smart Présence), « Identifiants
     d'appareil » (empreinte anti-fraude)

6. **Déclaration de données** (« Sécurité des données ») : répondez au formulaire
   honnêtement. Points GENUC :
   - données partagées avec des tiers : non (hébergement propre)
   - collecte : profil étudiant, notes, paiements, position (uniquement pendant
     l'usage, pour Smart Présence), identifiant d'appareil
   - chiffrement en transit : oui (HTTPS)
   - suppression de compte : à prévoir dans l'app ou via le service académique

---

## 4. Téléverser l'AAB et activer Play App Signing

1. Menu **Version** → **Parcours de publication** → **Version de production**
   → **Créer une version** (bouton vert)
2. **Téléverser** `app-release.aab`
3. Google vous demande la clé de chiffrement Play App Signing :
   - choisissez « **Créer une clé** » (la plus simple) — Google génère et conserve
     la clé d'app
   - ou importez votre propre clé de signature d'app (pour une migration depuis
     une app déjà publiée signée manuellement — pas notre cas)
4. Conservez l'**empreinte de la clé upload** affichée : notez que
   `5392:c659:c206:ba95:daf5:ad92:ed20:b749:754d:dc5d:b369:dcc0:6e4b:3b75:2e06:bc1d`
   (ou la valeur affichée dans Play Console) correspond bien à votre keystore
   local — vérification :
   ```bash
   keytool -list -keystore android/upload-keystore.jks -alias upload
   ```
   (mot de passe demandé : `@Bamo4525`)

5. **Notes de version** (obligatoires) — exemple :
   ```
   Version 1.0.0 — première publication.
   Portail étudiant : tableau de bord, notes, relevés, cours, paiements,
   notifications et Smart Présence.
   ```

6. Laissez la version en **brouillon** pour l'instant (les tests sont faits plus bas).

---

## 5. Remplir les déclarations Play (obligatoires avant validation)

Menu **Contenu de l'app** → complétez **toutes** les sections marquées requises :

- **Questionnaire sur les annonces** : non (pas de pub)
- **Évaluation du contenu** : répondez au questionnaire IARC (5 min) — GENUC est
  « Tout public » (Éducation)
- **Cibles (âge)** : 13 ans et plus (ou selon votre politique)
- **Politique de confidentialité** : lien obligatoire (cf. §3.5)
- **Comptes de test** : facultatifs
- **Autorisations** : GENUC déclare l'usage de **Caméra** (scan QR Smart Présence)
  et de **Position** (preuve de proximité) — le formulaire le déduit du manifeste

---

## 6. Tester avant la mise en ligne

1. **Piste de test interne** (recommandé) :
   - Menu **Version** → **Piste de test** → **Test interne**
   - Téléversez l'AAB, ajoutez les emails de vos testeurs
   - Ils reçoivent un lien d'installation Play (pas besoin de `adb`)
2. **Test fermé** (ouverture progressive) : mêmes étapes, audience plus large
3. Vérifiez sur l'appareil de test :
   - connexion (email + matricule)
   - Smart Présence : démarrer une séance côté professeur, scanner le QR
   - notes, paiements, cours, notifications

---

## 7. Mise en production

1. **Version de production** → **Créer une version** → téléversez l'AAB final
2. **Examen de l'application** : Google relit les infos (comptez quelques heures
   à quelques jours pour la première publication)
3. **Publier**

---

## 8. Mettre à jour l'app (version suivante)

1. Bump de version dans `pubspec.yaml` :
   ```yaml
   version: 1.1.0+2   # versionName 1.1.0, versionCode 2 (le +N doit augmenter)
   ```
2. ```bash
   flutter build appbundle --release
   ```
3. Play Console → **Créer une version** → téléverser le nouvel AAB → notes de
   version → envoyer en examen (déploiement progressif possible)

> Le `versionCode` (+N) doit **strictement augmenter** à chaque version, sinon
> Google refuse le téléversement.

---

## 9. Distribution directe (alternative / complément)

Pour une diffusion hors Play Store (site, écoles, MDM, WhatsApp), utilisez les APK
signés déjà générés :

| Architecture | Fichier | Taille |
|---|---|---|
| Téléphones récents (99 % des appareils) | `app-arm64-v8a-release.apk` | 29,5 Mo |
| Téléphones anciens (32 bits) | `app-armeabi-v7a-release.apk` | 25,7 Mo |
| Émulateurs / PC x86_64 | `app-x86_64-release.apk` | 31,8 Mo |
| APK universel (toutes archis) | `app-release.apk` | 72 Mo |

Installation : `adb install <fichier>.apk` ou ouverture directe sur l'appareil.

---

## 10. Checklist finale

- [ ] `app-release.aab` généré (`flutter build appbundle --release`)
- [ ] Keystore + mot de passe sauvegardés hors ligne (2 emplacements)
- [ ] Compte développeur créé (25 $ US)
- [ ] Fiche du store complète (description, icône, captures d'écran)
- [ ] Politique de confidentialité en ligne
- [ ] Déclarations Play remplies (données, contenu, annonces)
- [ ] AAB téléversé sur la piste de test interne
- [ ] Tests effectués sur appareil réel
- [ ] Publication en production

---

*Généré le 16/08/2026 — à mettre à jour au fil des versions.*
