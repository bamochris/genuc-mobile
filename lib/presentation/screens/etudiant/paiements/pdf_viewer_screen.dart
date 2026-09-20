// lib/presentation/screens/etudiant/paiements/pdf_viewer_screen.dart
//
// Écran plein écran pour visualiser un PDF (reçu/bon de paiement).
// Utilise le paquet `printing` qui fournit un visualiseur PDF natif.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../core/utils/fichiers.dart';

class PdfViewerScreen extends StatefulWidget {
  final Uint8List pdfBytes;
  final String titre;
  final String? numeroBon;
  final double? montant;

  const PdfViewerScreen({
    super.key,
    required this.pdfBytes,
    required this.titre,
    this.numeroBon,
    this.montant,
  });

  static Future<void> ouvrir(
    BuildContext context, {
    required Uint8List pdfBytes,
    required String titre,
    String? numeroBon,
    double? montant,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          pdfBytes: pdfBytes,
          titre: titre,
          numeroBon: numeroBon,
          montant: montant,
        ),
      ),
    );
  }

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  // Les octets du PDF arrivent déjà chargés par le constructeur : il n'y a rien
  // à attendre ici. Un indicateur de chargement à cet endroit ne s'éteindrait
  // jamais — l'écran resterait bloqué sur sa roue.

  @override
  Widget build(BuildContext context) {
    final estSombre = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: estSombre ? const Color(0xFF0D1420) : Colors.white,
      appBar: AppBar(
        title: Text(widget.titre),
        backgroundColor: estSombre ? const Color(0xFF16202E) : Colors.white,
        foregroundColor: estSombre ? Colors.white : Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Télécharger',
            onPressed: _telecharger,
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'Imprimer',
            onPressed: _imprimer,
          ),
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Partager',
            onPressed: _partager,
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) async => widget.pdfBytes,
        allowPrinting: true,
        allowSharing: true,
        pdfFileName: widget.numeroBon != null
            ? 'bon_${widget.numeroBon}.pdf'
            : 'recu_${DateTime.now().millisecondsSinceEpoch}.pdf',
        canChangePageFormat: false,
        canChangeOrientation: false,
        initialPageFormat: PdfPageFormat.a4,
      ),
    );
  }

  Future<void> _telecharger() async {
    try {
      final nomFichier = widget.numeroBon != null
          ? 'bon_paiement_${widget.numeroBon}.pdf'
          : 'recu_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final resultat = await Fichiers.enregistrerDansTelechargements(
        widget.pdfBytes,
        nomFichier,
      );

      if (!mounted) return;

      if (resultat != null && resultat != 'partagé') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enregistré dans Téléchargements'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Ouvrir',
              onPressed: () => Fichiers.enregistrerEtOuvrir(
                widget.pdfBytes,
                nomFichier,
              ),
            ),
          ),
        );
      } else if (resultat == 'partagé') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Partage ouvert'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec du téléchargement : $e')),
      );
    }
  }

  Future<void> _imprimer() async {
    await Printing.layoutPdf(
      onLayout: (format) async => widget.pdfBytes,
      name: widget.numeroBon != null
          ? 'bon_${widget.numeroBon}.pdf'
          : 'recu.pdf',
    );
  }

  Future<void> _partager() async {
    await Printing.sharePdf(
      bytes: widget.pdfBytes,
      filename: widget.numeroBon != null
          ? 'bon_${widget.numeroBon}.pdf'
          : 'recu.pdf',
    );
  }
}