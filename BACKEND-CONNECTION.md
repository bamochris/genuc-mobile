# GENUC Mobile - Connexion Backend

## 🔗 Architecture de Connexion

L'application mobile GENUC est connectée directement au backend GENUC existant via l'API REST Spring Boot. Aucune invention n'est faite - tous les modèles de données correspondent exactement aux DTOs et entités du backend.

## 📡 API Endpoints

### Authentification
- `POST /api/auth/login` - Connexion
- `POST /api/auth/connecter` - Connexion (alias)
- `POST /api/auth/refresh` - Refresh token
- `POST /api/auth/logout` - Déconnexion
- `GET /api/auth/moi` - Informations utilisateur

### Portail Étudiant
- `GET /api/etudiant/portal/dashboard/{inscriptionId}` - Dashboard complet
- `GET /api/etudiant/portal/profil/{inscriptionId}` - Profil étudiant
- `PUT /api/etudiant/portal/profil/{inscriptionId}` - Mise à jour profil
- `GET /api/etudiant/portal/{inscriptionId}/cours` - Liste des cours
- `GET /api/etudiant/portal/{inscriptionId}/cours/{coursId}` - Détails cours
- `POST /api/etudiant/portal/{inscriptionId}/cours/{coursId}/lecon/{leconId}/complete` - Marquer leçon complète
- `GET /api/etudiant/portal/{inscriptionId}/notes` - Notes
- `GET /api/etudiant/portal/{inscriptionId}/releve` - Relevé de notes
- `GET /api/etudiant/portal/{inscriptionId}/travaux` - Travaux et devoirs
- `GET /api/etudiant/portal/{inscriptionId}/documents-officiels` - Documents officiels
- `GET /api/etudiant/portal/{inscriptionId}/stage` - Stages
- `GET /api/etudiant/portal/{inscriptionId}/tfc` - TFC/Mémoire
- `GET /api/horaires/etudiant/{inscriptionId}` - Emploi du temps (semaine type)
- `GET /api/etudiant/portal/{inscriptionId}/presences` - Pointages de présence
- `GET /api/etudiant/portal/{inscriptionId}/examens` - Examens planifiés
- `GET /api/etudiant/portal/{inscriptionId}/evenements` - Événements du campus
- `GET /api/etudiant/portal/{inscriptionId}/annees-disponibles` - Années académiques avec notes
- `GET /api/etudiant/portal/{inscriptionId}/parcours` - Parcours académique (délibérations publiées)
- `GET /api/etudiant/portal/{inscriptionId}/bulletins` - Bulletins disponibles (`?annee=`)
- `GET /api/etudiant/portal/{inscriptionId}/preferences` - Préférences (notifications, langue)
- `PUT /api/etudiant/portal/{inscriptionId}/preferences` - Mise à jour préférences
- `POST /api/social/calcul-bourse` - Estimation indicative de bourse

### Paiements
- `GET /api/etudiant/frais/situation` - Situation financière
- `GET /api/etudiant/frais/a-payer` - Frais à payer
- `GET /api/etudiant/frais/historique` - Historique paiements
- `GET /api/etudiant/frais/recu/{paiementId}` - Reçu d'un paiement
- `GET /api/paiements` - Liste paiements

### Notifications
- `GET /api/notifications/mes-notifications` - Liste notifications
- `GET /api/notifications/mes-notifications/non-lues` - Notifications non lues
- `GET /api/notifications/non-lues/count` - Compteur notifications
- `POST /api/notifications/tout-lire` - Marquer tout comme lu
- `PUT /api/notifications/{id}/lue` - Marquer comme lu

## 📊 Correspondance des Modèles

### Dashboard
**Backend**: `EtudiantDashboardDto` (Java)  
**Mobile**: `DashboardData` (Dart)

Champs correspondants:
- `matricule` ↔ `matricule`
- `nomComplet` ↔ `nomComplet`
- `email` ↔ `email`
- `photo` ↔ `photo`
- `universite` ↔ `universite`
- `departement` ↔ `departement`
- `filiere` ↔ `filiere`
- `promotion` ↔ `promotion`
- `niveau` ↔ `niveau`
- `anneeAcademique` ↔ `anneeAcademique`
- `moyenneGenerale` ↔ `moyenneGenerale`
- `creditsValides` ↔ `creditsValides`
- `soldeAPayer` ↔ `soldeAPayer`
- `progressionGlobale` ↔ `progressionGlobale`
- `notifications` ↔ `notifications` (List<NotificationDto>)
- `prochainsCours` ↔ `prochainsCours` (List<CoursSimpleDto>)
- `prochainsExamens` ↔ `prochainsExamens` (List<ExamenSimpleDto>)
- `stats` ↔ `stats` (StatsDto)

### Profil Étudiant
**Backend**: Réponse `EtudiantPortalController.getProfil()` (Java)  
**Mobile**: `EtudiantProfile` (Dart)

Champs correspondants:
- `id` ↔ `id`
- `matricule` ↔ `matricule`
- `nom` ↔ `nom`
- `prenom` ↔ `prenom`
- `email` ↔ `email`
- `telephone` ↔ `telephone`
- `dateNaissance` ↔ `dateNaissance`
- `lieuNaissance` ↔ `lieuNaissance`
- `sexe` ↔ `sexe`
- `adresse` ↔ `adresse`
- `universite` ↔ `universite`
- `departement` ↔ `departement`
- `filiere` ↔ `filiere`
- `promotion` ↔ `promotion`
- `anneeAcademique` ↔ `anneeAcademique`
- `bulletin` ↔ `bulletin`
- `photo` ↔ `photo`
- `acte` ↔ `acte`

### Cours
**Backend**: `Cours` entity (Java)  
**Mobile**: `Cours` (Dart)

Champs correspondants:
- `id` ↔ `id`
- `code` ↔ `code`
- `titre` ↔ `titre`
- `credits` ↔ `credits`
- `enseignant` ↔ `enseignant`
- `semestre` ↔ `semestre`
- `anneeAcademique` ↔ `anneeAcademique`

### Notes
**Backend**: `Note` entity (Java)  
**Mobile**: `Note` (Dart)

Champs correspondants:
- `id` ↔ `id`
- `coursCode` ↔ `coursCode`
- `coursTitre` ↔ `coursTitre`
- `note` ↔ `note`
- `mention` ↔ `mention`
- `credits` ↔ `credits`
- `semestre` ↔ `semestre`
- `anneeAcademique` ↔ `anneeAcademique`

## 🔐 Sécurité

### Authentification
- JWT tokens stockés dans `flutter_secure_storage`
- Refresh token automatique via interceptor Dio
- Cookies XSRF gérés automatiquement

### Configuration
- Base URL configurable via `DioClient`
- Timeout configurable
- Gestion des erreurs centralisée dans `ApiException`

## 🧪 Tests

Pour tester la connexion:
1. Démarrer le backend GENUC sur `http://localhost:8082`
2. Configurer l'URL base dans `DioClient`
3. Tester l'authentification avec les comptes de test:
   - `etudiant@unikin.cd` / `Etudiant123!`
   - Matricule: `HECKIN202500001`

## 📝 Notes

- Tous les modèles de données sont basés sur les DTOs et entités réels du backend
- Aucune donnée fictive n'est utilisée en production
- Les validations côté mobile correspondent aux validations backend
- Les erreurs sont traitées selon les codes d'erreur backend