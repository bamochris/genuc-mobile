import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifiantController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mfaController = TextEditingController();

  bool _obscurePassword = true;
  int _carouselIndex = 0;
  Timer? _carouselTimer;

  static const _carouselImages = [
    'assets/images/university/HECEME.png',
    'assets/images/university/dash.jpg',
    'assets/images/university/upn-rectorat.jpg',
    'assets/images/university/upn.jpg',
    'assets/images/university/unikinv.jpg',
    'assets/images/university/hecarbre.jpg',
    'assets/images/university/heccour.jpg',
    'assets/images/university/UNILUpaysage.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _carouselTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        setState(() {
          _carouselIndex = (_carouselIndex + 1) % _carouselImages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _identifiantController.dispose();
    _passwordController.dispose();
    _mfaController.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    await authProvider.login(
      identifiant: _identifiantController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    // Succès : `_RacineAuthentifiee` bascule seule sur le portail.
    // Second facteur requis : le formulaire de code s'affiche.
    // Échec : on remonte le message renvoyé par le backend.
    final error = authProvider.error;
    if (error != null && !authProvider.mfaRequired) {
      _afficherErreur(error);
    }
  }

  Future<void> _submitMfa() async {
    final code = _mfaController.text.trim();
    if (code.isEmpty) return;

    final authProvider = context.read<AuthProvider>();
    final ok = await authProvider.verifyMfa(code);

    if (!mounted || ok) return;
    _afficherErreur(authProvider.error ?? 'Code invalide');
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.error,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isWideScreen = MediaQuery.of(context).size.width > 900;
    final mfaRequired = context.select<AuthProvider, bool>((p) => p.mfaRequired);

    return Scaffold(
      body: isWideScreen
          ? Row(
              children: [
                Expanded(flex: 5, child: _buildLeftSide(mfaRequired)),
                Expanded(flex: 4, child: _buildRightSide(mfaRequired)),
              ],
            )
          : Column(
              children: [
                // Sur téléphone, la bande de marque n'occupe que le tiers haut
                // de l'écran : elle s'y présente en version courte (voir
                // `_buildLeftSide`), sans quoi ses garanties de sécurité
                // tombent hors champ et il faut faire défiler une image pour
                // les lire.
                Expanded(flex: 3, child: _buildLeftSide(mfaRequired, court: true)),
                Expanded(flex: 4, child: _buildRightSide(mfaRequired)),
              ],
            ),
    );
  }

  Widget _buildLeftSide(bool mfaRequired, {bool court = false}) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, AppTheme.primaryDark],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fondu enchaîné d'une vue à l'autre : la coupure sèche d'origine
          // faisait « sauter » l'écran de connexion toutes les 15 secondes.
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 900),
              child: Image.asset(
                _carouselImages[_carouselIndex],
                key: ValueKey(_carouselIndex),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          // Voile dégradé plutôt qu'un aplat noir à 80 % : les campus restent
          // visibles au centre, et le texte garde son contraste là où il est
          // posé — en haut et en bas.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xF20B1F4A),
                  Color(0xB306132B),
                  Color(0xF206132B),
                ],
                stops: [0, 0.48, 1],
              ),
            ),
            child: SizedBox.expand(),
          ),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: court ? 24 : 40,
                vertical: court ? 18 : 30,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: court ? 92 : 132,
                    height: court ? 92 : 132,
                    padding: EdgeInsets.all(court ? 8 : 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.28),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.secondary.withValues(alpha: 0.35),
                          blurRadius: 34,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logo-genuc.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.school_rounded,
                        size: 56,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: court ? 14 : 18),
                  Text(
                    'GENUC',
                    style: textTheme.headlineLarge?.copyWith(
                      fontSize: court ? 30 : 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 3,
                      // Le texte se pose sur des photos : cette ombre le tient
                      // lisible même sur une vue claire.
                      shadows: const [
                        Shadow(color: Color(0x8006132B), blurRadius: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'GESTION NUMÉRIQUE UNIVERSITAIRE COMPLÈTE',
                    textAlign: TextAlign.center,
                    style: textTheme.labelMedium?.copyWith(
                      fontSize: 11.5,
                      color: AppTheme.secondaryLight,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w600,
                      shadows: const [
                        Shadow(color: Color(0x8006132B), blurRadius: 10),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Puce(
                    icone: mfaRequired
                        ? Icons.verified_user_rounded
                        : Icons.lock_rounded,
                    texte: mfaRequired ? 'Vérification 2FA' : 'Portail sécurisé',
                  ),
                  // La phrase d'accueil ne tient pas dans le tiers d'écran d'un
                  // téléphone : le formulaire, juste dessous, dit déjà ce qu'il
                  // y a à faire.
                  if (!court) ...[
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        mfaRequired
                            ? 'Entrez le code de vérification généré par votre application d\'authentification.'
                            : 'Connectez-vous pour accéder à vos services académiques et administratifs.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.82),
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: court ? 14 : 22),
                  // Ce que le compte gagne réellement à la connexion — pas de
                  // chiffres d'établissements ni de compteurs d'utilisateurs :
                  // ceux qui figuraient ici étaient inventés.
                  //
                  // Sur téléphone, les trois garanties tiennent sur une ligne :
                  // il n'y a pas la hauteur pour leur version détaillée, et
                  // trois jetons côte à côte se renvoyaient à la ligne.
                  if (court)
                    const _LigneSecuriteCourte()
                  else ...[
                    const _LigneSecurite(
                      icone: Icons.shield_rounded,
                      titre: 'Protection anti-bruteforce',
                      detail: 'Les tentatives répétées sont limitées.',
                    ),
                    const _LigneSecurite(
                      icone: Icons.phonelink_lock_rounded,
                      titre: 'Double authentification',
                      detail: 'Code à usage unique, si votre compte l\'active.',
                    ),
                    const _LigneSecurite(
                      icone: Icons.enhanced_encryption_rounded,
                      titre: 'Session chiffrée',
                      detail: 'Identifiants et session gardés sur l\'appareil.',
                    ),
                  ],
                  SizedBox(height: court ? 16 : 24),
                  _IndicateursCarrousel(
                    total: _carouselImages.length,
                    actif: _carouselIndex,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightSide(bool mfaRequired) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: mfaRequired ? _buildMfaForm() : _buildCredentialsForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildCredentialsForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _identifiantController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Email ou matricule',
              prefixIcon: Icon(Icons.person_rounded),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Veuillez saisir votre email ou matricule';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submitLogin(),
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              prefixIcon: const Icon(Icons.lock_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                ),
                tooltip: _obscurePassword
                    ? 'Afficher le mot de passe'
                    : 'Masquer le mot de passe',
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Veuillez saisir votre mot de passe';
              }
              // Le backend refuse en deçà (LoginRequest : @Size(min = 8)).
              if (value.length < 8) {
                return 'Le mot de passe doit contenir au moins 8 caractères';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          _BoutonPrincipal(label: 'Se connecter', onPressed: _submitLogin),
        ],
      ),
    );
  }

  Widget _buildMfaForm() {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Vérification en deux étapes',
          textAlign: TextAlign.center,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Entrez le code à 6 chiffres généré par votre application d\'authentification',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _mfaController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          autofocus: true,
          maxLength: 6,
          onSubmitted: (_) => _submitMfa(),
          style: const TextStyle(
            fontSize: 24,
            letterSpacing: 8,
            fontWeight: FontWeight.w600,
          ),
          decoration: const InputDecoration(
            labelText: 'Code de vérification',
            prefixIcon: Icon(Icons.security_rounded),
            counterText: '',
          ),
        ),
        const SizedBox(height: 20),
        _BoutonPrincipal(label: 'Vérifier', onPressed: _submitMfa),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () {
            _mfaController.clear();
            context.read<AuthProvider>().annulerMfa();
          },
          child: const Text('← Retour à la connexion'),
        ),
      ],
    );
  }
}

class _BoutonPrincipal extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _BoutonPrincipal({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<AuthProvider, bool>((p) => p.isLoading);

    if (isLoading) {
      return Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.secondary, AppTheme.secondaryDark],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Text(label),
    );
  }
}

/// Étiquette d'état posée sous le nom de marque (« Portail sécurisé »).
class _Puce extends StatelessWidget {
  final IconData icone;
  final String texte;

  const _Puce({required this.icone, required this.texte});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.secondaryLight.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppTheme.secondaryLight.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 15, color: AppTheme.secondaryLight),
          const SizedBox(width: 7),
          Text(
            texte,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Garantie de sécurité : icône vectorielle sur sa plaque de verre, titre,
/// détail. Les émojis d'origine (🛡️ 🔐 🔑) changeaient de dessin d'un
/// téléphone à l'autre, ne suivaient ni la couleur ni la graisse du reste de
/// l'écran, et se posaient de travers sur la ligne de texte.
class _LigneSecurite extends StatelessWidget {
  final IconData icone;
  final String titre;
  final String detail;

  const _LigneSecurite({
    required this.icone,
    required this.titre,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.20),
                  Colors.white.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Icon(icone, size: 18, color: AppTheme.secondaryLight),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                Text(
                  detail,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Les trois garanties en une ligne, pour la bande de marque des téléphones.
class _LigneSecuriteCourte extends StatelessWidget {
  const _LigneSecuriteCourte();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_rounded, size: 14, color: AppTheme.secondaryLight),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            'Anti-bruteforce · Double authentification · Session chiffrée',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.80),
              fontSize: 11.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Points du carrousel : la vue courante s'allonge en pastille.
class _IndicateursCarrousel extends StatelessWidget {
  final int total;
  final int actif;

  const _IndicateursCarrousel({required this.total, required this.actif});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == actif ? 20 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == actif
                  ? AppTheme.secondaryLight
                  : Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
