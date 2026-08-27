import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Une colonne de la liste exportée.
class ColonneExport {
  final String libelle;

  /// Extrait la valeur d'une ligne. Rendre une chaîne vide plutôt que nul :
  /// une cellule absente et une cellule vide se lisent pareil sur papier.
  final String Function(Map<String, dynamic> ligne) valeur;

  /// Aligner à droite ce qui se compare : effectifs, montants, moyennes.
  final bool aDroite;

  const ColonneExport({
    required this.libelle,
    required this.valeur,
    this.aDroite = false,
  });
}

/// Export d'une liste : impression, enregistrement en PDF, partage.
///
/// ── Pourquoi le PDF est fabriqué sur le téléphone ──
///
/// Le serveur produit les documents officiels — relevé, carte, PV — avec leur
/// mise en page réglementaire. Une liste de travail n'en est pas un : elle
/// change à chaque filtre appliqué à l'écran, et c'est CE qui est affiché que
/// l'enseignant veut sur papier. La fabriquer ici évite un endpoint par liste,
/// et respecte les filtres en cours.
///
/// `Printing.layoutPdf` ouvre la feuille système d'Android : imprimer,
/// « Enregistrer au format PDF », ou partager. Un seul geste pour les trois.
class ExportListe {
  const ExportListe._();

  /// Ouvre la feuille système avec la liste mise en page.
  ///
  /// [titre] intitulé du document, [sousTitre] les précisions utiles
  /// (promotion, vacation, filtres actifs), [etablissement] l'en-tête.
  static Future<void> ouvrir({
    required String titre,
    String? sousTitre,
    String? etablissement,
    required List<ColonneExport> colonnes,
    required List<Map<String, dynamic>> lignes,
  }) async {
    final document = pw.Document();
    final edite = DateTime.now();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (contexte) => _entete(
          titre: titre,
          sousTitre: sousTitre,
          etablissement: etablissement,
          edite: edite,
          nombre: lignes.length,
          premierePage: contexte.pageNumber == 1,
        ),
        footer: (contexte) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'GENUC — page ${contexte.pageNumber}/${contexte.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (contexte) => [_tableau(colonnes, lignes)],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => document.save(),
      name: _nomFichier(titre, edite),
    );
  }

  static String _nomFichier(String titre, DateTime edite) {
    final base = titre
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final jour = '${edite.year}'
        '${edite.month.toString().padLeft(2, '0')}'
        '${edite.day.toString().padLeft(2, '0')}';
    return '${base.isEmpty ? 'liste' : base}-$jour.pdf';
  }

  static pw.Widget _entete({
    required String titre,
    required String? sousTitre,
    required String? etablissement,
    required DateTime edite,
    required int nombre,
    required bool premierePage,
  }) {
    // Les pages suivantes ne reprennent que le titre : répéter l'en-tête
    // complet mangerait le quart de chaque feuille.
    if (!premierePage) {
      return pw.Container(
        alignment: pw.Alignment.centerLeft,
        margin: const pw.EdgeInsets.only(bottom: 10),
        child: pw.Text(titre,
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700,
                fontWeight: pw.FontWeight.bold)),
      );
    }

    final horodatage = '${edite.day.toString().padLeft(2, '0')}/'
        '${edite.month.toString().padLeft(2, '0')}/${edite.year} à '
        '${edite.hour.toString().padLeft(2, '0')}:'
        '${edite.minute.toString().padLeft(2, '0')}';

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColor.fromInt(0xFF0B1F4A), width: 1.6),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (etablissement != null && etablissement.isNotEmpty)
            pw.Text(etablissement.toUpperCase(),
                style: pw.TextStyle(
                    fontSize: 8,
                    letterSpacing: 0.6,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor.fromInt(0xFF185FA5))),
          pw.SizedBox(height: 4),
          pw.Text(titre,
              style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: const PdfColor.fromInt(0xFF0B1F4A))),
          if (sousTitre != null && sousTitre.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(sousTitre,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          ],
          pw.SizedBox(height: 6),
          // Une liste nominative qui circule sans date ni auteur n'est pas
          // exploitable : on ne sait ni de quand elle date, ni d'où elle sort.
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Édité le $horodatage',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('$nombre ligne${nombre > 1 ? 's' : ''}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _tableau(
      List<ColonneExport> colonnes, List<Map<String, dynamic>> lignes) {
    pw.Widget cellule(String texte,
            {bool entete = false, bool aDroite = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: pw.Text(
            texte,
            textAlign: aDroite ? pw.TextAlign.right : pw.TextAlign.left,
            style: pw.TextStyle(
              fontSize: entete ? 7.5 : 8.5,
              fontWeight: entete ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: entete ? const PdfColor.fromInt(0xFF0B1F4A) : PdfColors.black,
            ),
          ),
        );

    return pw.Table(
      border: pw.TableBorder(
        horizontalInside:
            const pw.BorderSide(color: PdfColors.grey300, width: 0.4),
        bottom: const pw.BorderSide(color: PdfColors.grey300, width: 0.4),
      ),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
          children: [
            cellule('#', entete: true, aDroite: true),
            for (final c in colonnes)
              cellule(c.libelle.toUpperCase(), entete: true, aDroite: c.aDroite),
          ],
        ),
        for (var i = 0; i < lignes.length; i++)
          pw.TableRow(
            children: [
              cellule('${i + 1}', aDroite: true),
              for (final c in colonnes)
                cellule(c.valeur(lignes[i]), aDroite: c.aDroite),
            ],
          ),
      ],
    );
  }
}

/// Bouton d'export, à poser dans les actions d'un écran de liste.
///
/// Désactivé quand la liste est vide : proposer d'imprimer zéro ligne est une
/// promesse creuse, et l'utilisateur croit à une panne.
class BoutonExportListe extends StatelessWidget {
  final String titre;
  final String? sousTitre;
  final String? etablissement;
  final List<ColonneExport> colonnes;
  final List<Map<String, dynamic>> lignes;
  final bool compact;

  const BoutonExportListe({
    super.key,
    required this.titre,
    required this.colonnes,
    required this.lignes,
    this.sousTitre,
    this.etablissement,
    this.compact = false,
  });

  Future<void> _exporter(BuildContext context) async {
    final messager = ScaffoldMessenger.maybeOf(context);
    try {
      await ExportListe.ouvrir(
        titre: titre,
        sousTitre: sousTitre,
        etablissement: etablissement,
        colonnes: colonnes,
        lignes: lignes,
      );
    } catch (e) {
      messager?.showSnackBar(
        SnackBar(content: Text('Impression impossible : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final actif = lignes.isNotEmpty;
    if (compact) {
      return IconButton(
        tooltip: actif ? 'Imprimer / PDF' : 'Rien à imprimer',
        icon: const Icon(Icons.print_rounded),
        onPressed: actif ? () => _exporter(context) : null,
      );
    }
    return OutlinedButton.icon(
      onPressed: actif ? () => _exporter(context) : null,
      icon: const Icon(Icons.print_rounded, size: 18),
      label: const Text('Imprimer / PDF'),
    );
  }
}
