// lib/presentation/screens/etudiant/paiements/mes_recus_screen.dart
//
// Écran "Mes reçus" : liste persistante de tous les bons de caisse
// et reçus de paiement générés dans l'application.

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/dio_client.dart';
import '../../../../data/services/recu_historique_service.dart';
import '../../../../data/services/tachpay_service.dart';
import '../../../widgets/etat_widgets.dart';
import 'pdf_viewer_screen.dart';

class MesRecusScreen extends StatefulWidget {
  const MesRecusScreen({super.key});

  @override
  State<MesRecusScreen> createState() => _MesRecusScreenState();
}

class _MesRecusScreenState extends State<MesRecusScreen> {
  List<RecuHistorique> _recus = [];
  bool _chargement = true;
  String? _erreur;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final recus = await RecuHistoriqueService.obtenirTous();
      if (mounted) {
        setState(() {
          _recus = recus;
          _chargement = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _erreur = e.toString();
          _chargement = false;
        });
      }
    }
  }

  Future<void> _supprimerRecu(RecuHistorique recu) async {
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce reçu ?'),
        content: Text('Le reçu ${recu.numero} sera retiré de la liste. '
            'Le fichier PDF téléchargé dans vos fichiers ne sera pas affecté.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmer != true) return;

    try {
      await RecuHistoriqueService.supprimer(recu.numero);
      if (mounted) {
        setState(() => _recus.removeWhere((r) => r.numero == recu.numero));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reçu supprimé de l\'historique')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  Future<void> _telechargerEtVoir(RecuHistorique recu) async {

    final tachPayService = TachPayService(DioClient().dio);

    try {
      final octets = await tachPayService.telechargerBonPdf(recu.numero);
      if (!mounted) return;

      // Affiche le PDF en plein écran
      await PdfViewerScreen.ouvrir(
        context,
        pdfBytes: Uint8List.fromList(octets),
        titre: recu.libelleType,
        numeroBon: recu.numero,
        montant: recu.montant,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de charger le PDF : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final estSombre = Theme.of(context).brightness == Brightness.dark;
    final fondPage = estSombre ? const Color(0xFF0D1420) : const Color(0xFFF6F8FB);
    final fondCarte = estSombre ? const Color(0xFF1B2534) : Colors.white;
    final textePrincipal = estSombre ? const Color(0xFFF7F9FC) : const Color(0xFF14213D);
    final texteSecondaire = estSombre ? const Color(0xFFAFC0D6) : Colors.grey.shade600;
    final bordureCarte = estSombre ? const Color(0xFF33415C) : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: fondPage,
      appBar: AppBar(
        title: const Text('Mes reçus'),
        backgroundColor: estSombre ? const Color(0xFF16202E) : Colors.white,
        foregroundColor: estSombre ? Colors.white : Colors.black87,
        elevation: 0.5,
        centerTitle: true,
        actions: [
          if (_recus.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Tout effacer',
              onPressed: _confirmerToutSupprimer,
            ),
        ],
      ),
      body: _chargement
          ? Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : _erreur != null
              ? EtatErreur(message: _erreur!, onRetry: _charger)
              : _recus.isEmpty
                  ? _etatVide(fondCarte, textePrincipal, texteSecondaire, bordureCarte)
                  : _listeRecus(fondCarte, textePrincipal, texteSecondaire, bordureCarte),
    );
  }

  Widget _etatVide(Color fondCarte, Color textePrincipal, Color texteSecondaire, Color bordureCarte) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: fondCarte,
                shape: BoxShape.circle,
                border: Border.all(color: bordureCarte),
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                size: 40,
                color: texteSecondaire,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Aucun reçu enregistré',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textePrincipal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Vos bons de caisse et reçus de paiement\napparaîtront ici automatiquement.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: texteSecondaire,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded),
              label: const Text('Effectuer un paiement'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(context).popUntil((r) => r.isFirst);
                // L'utilisateur revient à l'écran principal, il peut accéder aux paiements
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _listeRecus(
    Color fondCarte,
    Color textePrincipal,
    Color texteSecondaire,
    Color bordureCarte,
  ) {
    return RefreshIndicator(
      onRefresh: _charger,
      color: AppTheme.primary,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _recus.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final recu = _recus[index];
          return _RecuTile(
            recu: recu,
            fondCarte: fondCarte,
            textePrincipal: textePrincipal,
            texteSecondaire: texteSecondaire,
            bordureCarte: bordureCarte,
            onTap: () => _telechargerEtVoir(recu),
            onSupprimer: () => _supprimerRecu(recu),
          );
        },
      ),
    );
  }

  Future<void> _confirmerToutSupprimer() async {
    final confirmer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tout effacer ?'),
        content: const Text(
          'Tous les reçus seront retirés de la liste. '
          'Les fichiers PDF déjà téléchargés dans vos fichiers ne seront pas affectés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Tout effacer'),
          ),
        ],
      ),
    );

    if (confirmer != true) return;

    try {
      await RecuHistoriqueService.toutSupprimer();
      if (mounted) {
        setState(() => _recus.clear());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Historique vidé')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }
}

class _RecuTile extends StatelessWidget {
  final RecuHistorique recu;
  final Color fondCarte;
  final Color textePrincipal;
  final Color texteSecondaire;
  final Color bordureCarte;
  final VoidCallback onTap;
  final VoidCallback onSupprimer;

  const _RecuTile({
    required this.recu,
    required this.fondCarte,
    required this.textePrincipal,
    required this.texteSecondaire,
    required this.bordureCarte,
    required this.onTap,
    required this.onSupprimer,
  });

  @override
  Widget build(BuildContext context) {
    final estBon = recu.type == 'bon';
    final couleurAccent = estBon ? const Color(0xFF185FA5) : const Color(0xFF2E7D32);
    final fondAccent = estBon ? const Color(0xFFE6F1FB) : const Color(0xFFDFF0D8);

    return Container(
      decoration: BoxDecoration(
        color: fondCarte,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bordureCarte),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icône type
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: fondAccent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    estBon ? Icons.receipt_long_rounded : Icons.check_circle_rounded,
                    color: couleurAccent,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),

                // Infos principales
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            recu.libelleType,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: textePrincipal,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: couleurAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              recu.numero,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: couleurAccent,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Généré le ${recu.dateAjoutFormate}',
                        style: TextStyle(fontSize: 11.5, color: texteSecondaire),
                      ),
                      if (recu.referencePaiement != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Paiement : ${recu.referencePaiement}',
                          style: TextStyle(fontSize: 11, color: texteSecondaire),
                        ),
                      ],
                    ],
                  ),
                ),

                // Montant + actions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      recu.montantFormate,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: textePrincipal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.picture_as_pdf_rounded,
                            color: AppTheme.primary,
                            size: 22,
                          ),
                          tooltip: 'Voir le PDF',
                          onPressed: onTap,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: AppTheme.error,
                            size: 22,
                          ),
                          tooltip: 'Retirer de la liste',
                          onPressed: onSupprimer,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}