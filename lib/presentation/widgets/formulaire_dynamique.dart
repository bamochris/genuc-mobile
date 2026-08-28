import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/fichiers.dart';
import '../../core/utils/responsive.dart';

/// Nature d'un champ de formulaire, calquée sur les `<input type=…>` des
/// formulaires du portail web.
enum TypeChamp { texte, multiligne, nombre, decimal, date, heure, liste, bascule, fichier }

/// Description d'un champ. Les écrans déclarent leur formulaire au lieu de le
/// dessiner : les quarante formulaires des deux portails ont la même forme —
/// libellé, contrôle, obligatoire ou non — et les recopier à la main faisait
/// diverger l'un d'eux à chaque fois (champ sans libellé, date sans sélecteur,
/// nombre sans clavier numérique).
class ChampFormulaire {
  final String cle;
  final String libelle;
  final TypeChamp type;
  final bool obligatoire;
  final String? indice;
  final dynamic valeurInitiale;

  /// Options d'une liste déroulante : valeur envoyée → libellé affiché.
  final Map<String, String> options;

  final num? minimum;
  final num? maximum;

  /// Extensions acceptées par le sélecteur de fichier, sans point (`['pdf']`).
  final List<String>? extensions;

  const ChampFormulaire({
    required this.cle,
    required this.libelle,
    this.type = TypeChamp.texte,
    this.obligatoire = false,
    this.indice,
    this.valeurInitiale,
    this.options = const {},
    this.minimum,
    this.maximum,
    this.extensions,
  });
}

/// Boîte de dialogue de saisie construite depuis une liste de [ChampFormulaire].
///
/// Rend `null` si l'utilisateur annule, sinon la carte des valeurs saisies.
class DialogueFormulaire extends StatefulWidget {
  final String titre;
  final List<ChampFormulaire> champs;
  final String libelleValidation;
  final Map<String, dynamic>? valeurs;

  const DialogueFormulaire({
    super.key,
    required this.titre,
    required this.champs,
    this.libelleValidation = 'Enregistrer',
    this.valeurs,
  });

  static Future<Map<String, dynamic>?> ouvrir(
    BuildContext context, {
    required String titre,
    required List<ChampFormulaire> champs,
    String libelleValidation = 'Enregistrer',
    Map<String, dynamic>? valeurs,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => DialogueFormulaire(
        titre: titre,
        champs: champs,
        libelleValidation: libelleValidation,
        valeurs: valeurs,
      ),
    );
  }

  @override
  State<DialogueFormulaire> createState() => _DialogueFormulaireState();
}

class _DialogueFormulaireState extends State<DialogueFormulaire> {
  final _cleFormulaire = GlobalKey<FormState>();
  final Map<String, dynamic> _valeurs = {};
  final Map<String, TextEditingController> _controleurs = {};

  @override
  void initState() {
    super.initState();
    for (final champ in widget.champs) {
      final initiale = widget.valeurs?[champ.cle] ?? champ.valeurInitiale;
      _valeurs[champ.cle] = initiale;
      if (champ.type != TypeChamp.liste && champ.type != TypeChamp.bascule) {
        _controleurs[champ.cle] =
            TextEditingController(text: initiale?.toString() ?? '');
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controleurs.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Plein écran sur téléphone : une boîte de dialogue à six champs, sur un
    // écran de 360 px avec le clavier ouvert, ne laisse rien voir du contenu.
    final pleinEcran = Responsive.estTelephone(context);

    final formulaire = Form(
      key: _cleFormulaire,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final champ in widget.champs) ...[
            _construireChamp(champ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );

    if (pleinEcran) {
      return Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.titre),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => Navigator.pop(context),
              tooltip: 'Annuler',
            ),
            actions: [
              TextButton(
                onPressed: _valider,
                child: Text(
                  widget.libelleValidation,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: formulaire,
          ),
        ),
      );
    }

    return AlertDialog(
      title: Text(widget.titre),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(child: formulaire),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _valider,
          child: Text(widget.libelleValidation),
        ),
      ],
    );
  }

  void _valider() {
    if (!(_cleFormulaire.currentState?.validate() ?? false)) return;
    Navigator.pop(context, Map<String, dynamic>.from(_valeurs));
  }

  Widget _construireChamp(ChampFormulaire champ) {
    final libelle = champ.obligatoire ? '${champ.libelle} *' : champ.libelle;

    switch (champ.type) {
      case TypeChamp.liste:
        return DropdownButtonFormField<String>(
          initialValue: _valeurs[champ.cle]?.toString().isNotEmpty == true
              ? _valeurs[champ.cle].toString()
              : null,
          isExpanded: true,
          // `helperText` et non `hintText` : un menu déroulant affiche déjà sa
          // sélection à la place du texte d'invite, qui ne se voit donc jamais.
          // L'indice était accepté par `ChampFormulaire` et transporté par
          // `EcranRessource._champsResolus`, mais silencieusement perdu ici —
          // une consigne écrite qui ne s'affichait nulle part.
          decoration: InputDecoration(
            labelText: libelle,
            helperText: champ.indice,
          ),
          items: champ.options.entries
              .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          validator: champ.obligatoire
              ? (v) => (v == null || v.isEmpty) ? 'Champ obligatoire' : null
              : null,
          onChanged: (v) => setState(() => _valeurs[champ.cle] = v),
        );

      case TypeChamp.bascule:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            champ.libelle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          value: _valeurs[champ.cle] == true,
          onChanged: (v) => setState(() => _valeurs[champ.cle] = v),
        );

      case TypeChamp.date:
      case TypeChamp.heure:
        return TextFormField(
          controller: _controleurs[champ.cle],
          readOnly: true,
          decoration: InputDecoration(
            labelText: libelle,
            hintText: champ.indice,
            suffixIcon: Icon(
              champ.type == TypeChamp.date
                  ? Icons.calendar_today_rounded
                  : Icons.schedule_rounded,
              size: 18,
            ),
          ),
          validator: champ.obligatoire
              ? (v) => (v == null || v.isEmpty) ? 'Champ obligatoire' : null
              : null,
          onTap: () => champ.type == TypeChamp.date
              ? _choisirDate(champ)
              : _choisirHeure(champ),
        );

      case TypeChamp.nombre:
      case TypeChamp.decimal:
        final decimal = champ.type == TypeChamp.decimal;
        return TextFormField(
          controller: _controleurs[champ.cle],
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              decimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
            ),
          ],
          decoration: InputDecoration(
            labelText: libelle,
            hintText: champ.indice,
          ),
          validator: (v) => _validerNombre(champ, v),
          onChanged: (v) => _valeurs[champ.cle] =
              decimal ? double.tryParse(v.replaceAll(',', '.')) : int.tryParse(v),
        );

      case TypeChamp.multiligne:
        return TextFormField(
          controller: _controleurs[champ.cle],
          maxLines: 4,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: libelle,
            hintText: champ.indice,
            alignLabelWithHint: true,
          ),
          validator: champ.obligatoire
              ? (v) => (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null
              : null,
          onChanged: (v) => _valeurs[champ.cle] = v,
        );

      case TypeChamp.fichier:
        final fichier = _valeurs[champ.cle] as FichierChoisi?;
        return TextFormField(
          controller: _controleurs[champ.cle],
          readOnly: true,
          decoration: InputDecoration(
            labelText: libelle,
            hintText: fichier == null
                ? (champ.indice ?? 'Choisir un fichier')
                : fichier.nom,
            suffixIcon: const Icon(Icons.attach_file_rounded, size: 18),
          ),
          validator: champ.obligatoire
              ? (_) => fichier == null ? 'Champ obligatoire' : null
              : null,
          onTap: () async {
            final choisi =
                await Fichiers.choisir(extensions: champ.extensions);
            if (choisi == null || !mounted) return;
            setState(() {
              _valeurs[champ.cle] = choisi;
              _controleurs[champ.cle]?.text = choisi.nom;
            });
          },
        );

      case TypeChamp.texte:
        return TextFormField(
          controller: _controleurs[champ.cle],
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: libelle,
            hintText: champ.indice,
          ),
          validator: champ.obligatoire
              ? (v) => (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null
              : null,
          onChanged: (v) => _valeurs[champ.cle] = v,
        );
    }
  }

  String? _validerNombre(ChampFormulaire champ, String? saisie) {
    if (saisie == null || saisie.trim().isEmpty) {
      return champ.obligatoire ? 'Champ obligatoire' : null;
    }
    final valeur = double.tryParse(saisie.replaceAll(',', '.'));
    if (valeur == null) return 'Valeur numérique attendue';
    if (champ.minimum != null && valeur < champ.minimum!) {
      return 'Minimum ${champ.minimum}';
    }
    if (champ.maximum != null && valeur > champ.maximum!) {
      return 'Maximum ${champ.maximum}';
    }
    return null;
  }

  Future<void> _choisirDate(ChampFormulaire champ) async {
    final maintenant = DateTime.now();
    final choisie = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_valeurs[champ.cle]?.toString() ?? '') ??
          maintenant,
      firstDate: DateTime(maintenant.year - 5),
      lastDate: DateTime(maintenant.year + 5),
      locale: const Locale('fr'),
    );
    if (choisie == null) return;
    // Format ISO court : c'est ce qu'attendent les contrôleurs (`LocalDate`).
    final texte = choisie.toIso8601String().substring(0, 10);
    setState(() {
      _valeurs[champ.cle] = texte;
      _controleurs[champ.cle]?.text = texte;
    });
  }

  Future<void> _choisirHeure(ChampFormulaire champ) async {
    final choisie = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (choisie == null) return;
    final texte = '${choisie.hour.toString().padLeft(2, '0')}:'
        '${choisie.minute.toString().padLeft(2, '0')}';
    setState(() {
      _valeurs[champ.cle] = texte;
      _controleurs[champ.cle]?.text = texte;
    });
  }
}

/// Sélecteur de cours réutilisable : la quasi-totalité des écrans enseignant
/// commence par « choisissez un cours ».
class SelecteurCours extends StatelessWidget {
  final String? valeur;
  final Map<String, String> cours;
  final ValueChanged<String?> onChange;
  final String libelle;

  const SelecteurCours({
    super.key,
    required this.valeur,
    required this.cours,
    required this.onChange,
    this.libelle = 'Cours',
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: valeur,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: libelle,
        prefixIcon: Icon(
          Icons.menu_book_rounded,
          size: 18,
          color: AppTheme.iconAccent(context),
        ),
      ),
      hint: const Text('— Sélectionner —'),
      items: cours.entries
          .map((e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: onChange,
    );
  }
}
