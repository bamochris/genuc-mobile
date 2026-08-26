import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/etudiant/paiement.dart';
import 'tachpay_flow.dart';
import '../../../providers/student_provider.dart';
import '../../../widgets/etat_widgets.dart';
import '../../../widgets/portail_widgets.dart';

/// Hub paiements de l'étudiant.
///
/// Correspond à `FraisAcademiques.jsx` du portail web : situation financière
/// (total attendu / payé / reste), frais à payer et historique des paiements.
/// Les données viennent de `FraisEtudiantService` (`/situation`, `/a-payer`,
/// `/historique`).
class PaiementsScreen extends StatefulWidget {
  const PaiementsScreen({super.key});

  @override
  State<PaiementsScreen> createState() => _PaiementsScreenState();
}

class _PaiementsScreenState extends State<PaiementsScreen> {
  int _onglet = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _charger());
  }

  Future<void> _charger() async {
    await context.read<StudentProvider>().loadSituationFinanciere();
  }

  @override
  Widget build(BuildContext context) {
    final studentProvider = context.watch<StudentProvider>();

    return PagePortail(
      titre: 'Mes paiements',
      corps: studentProvider.isLoading
          ? const EtatChargement(message: 'Chargement de votre situation financière…')
          : studentProvider.error != null
              ? EtatErreur(message: studentProvider.error!, onRetry: _charger)
              : _Contenu(
                  situation: studentProvider.situationFinanciere,
                  onglet: _onglet,
                  onChangerOnglet: (i) => setState(() => _onglet = i),
                  onRetry: _charger,
                ),
    );
  }
}

class _Contenu extends StatelessWidget {
  final SituationFinanciere? situation;
  final int onglet;
  final ValueChanged<int> onChangerOnglet;
  final Future<void> Function() onRetry;

  const _Contenu({
    required this.situation,
    required this.onglet,
    required this.onChangerOnglet,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final dettes = situation?.dettes ?? [];

    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Paiement mobile TachPay — flux dédié en 3 écrans (frais →
          // opérateur → confirmation + bon PDF). Mis en avant : c'est
          // l'action principale attendue sur cet écran.
          _BoutonTachPay(
            visible: dettes.isNotEmpty,
            onTap: () => ouvrirFluxTachPay(context),
          ),
          const SizedBox(height: 16),
          if (situation != null) _StatsFinancieres(situation: situation!),
          const SizedBox(height: 16),
          _Onglets(
            onglet: onglet,
            onChangerOnglet: onChangerOnglet,
            nbDettes: dettes.length,
          ),
          const SizedBox(height: 16),
          if (onglet == 0)
            _FraisAPayer(dettes: dettes)
          else
            _Historique(paiements: situation?.paiements ?? const []),
        ],
      ),
    );
  }
}

/// Bandeau d'accès au paiement TachPay. Discret quand il n'y a rien à payer.
class _BoutonTachPay extends StatelessWidget {
  final bool visible;
  final VoidCallback onTap;

  const _BoutonTachPay({required this.visible, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.primary.withValues(alpha: .25), width: 1.5),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset('assets/images/logo-tachpay.png', height: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(visible ? 'Payer mes frais maintenant' : 'TachPay',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 2),
              Text(visible ? 'Mobile money — simple et sécurisé' : 'Aucun frais à payer',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ]),
          ),
          if (visible)
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(9)),
              child: const Text('Payer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))),
        ]),
      ),
    );
  }
}

class _StatsFinancieres extends StatelessWidget {
  final SituationFinanciere situation;

  const _StatsFinancieres({required this.situation});

  @override
  Widget build(BuildContext context) {
    final reste = situation.totalReste;
    final couleurReste = reste > 0 ? AppTheme.error : AppTheme.success;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatFinancier(
                icon: Icons.receipt_long_rounded,
                label: 'Total attendu',
                valeur: formatMontant(situation.totalAttendu),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatFinancier(
                icon: Icons.check_circle_rounded,
                label: 'Déjà payé',
                valeur: formatMontant(situation.totalPaye),
                couleur: AppTheme.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatFinancier(
                icon: Icons.warning_amber_rounded,
                label: reste > 0 ? 'Reste à payer' : 'Soldé',
                valeur: formatMontant(reste),
                couleur: couleurReste,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatFinancier(
                icon: Icons.trending_up_rounded,
                label: 'Taux de couverture',
                valeur: '${situation.pourcentage.round()}%',
                couleur: AppTheme.info,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _BarreProgression(pourcentage: situation.pourcentage),
      ],
    );
  }
}

class _StatFinancier extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valeur;
  final Color? couleur;

  const _StatFinancier({
    required this.icon,
    required this.label,
    required this.valeur,
    this.couleur,
  });

  @override
  Widget build(BuildContext context) {
    // Dark : le montant par défaut passe en orange clair (le bleu nuit de
    // marque disparaît sur l'ardoise) ; clair : bleu conservé.
    final teinte = couleur ??
        (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFFFB74D)
            : AppTheme.primary);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        children: [
          Icon(icon, color: teinte, size: 26),
          const SizedBox(height: 8),
          Text(
            valeur,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: teinte,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondaryOf(context),
                  fontSize: 10,
                ),
          ),
        ],
      ),
    );
  }
}

class _BarreProgression extends StatelessWidget {
  final double pourcentage;

  const _BarreProgression({required this.pourcentage});

  @override
  Widget build(BuildContext context) {
    final p = pourcentage.clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Progression du paiement'),
              Text(
                '${p.round()}%',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: p / 100,
              minHeight: 10,
              backgroundColor: AppTheme.borderOf(context),
              color: p >= 80 ? AppTheme.success : AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Onglets extends StatelessWidget {
  final int onglet;
  final ValueChanged<int> onChangerOnglet;
  final int nbDettes;

  const _Onglets({
    required this.onglet,
    required this.onChangerOnglet,
    required this.nbDettes,
  });

  @override
  Widget build(BuildContext context) {
    final labels = [
      'Frais à payer${nbDettes > 0 ? ' ($nbDettes)' : ''}',
      'Historique',
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final actif = onglet == i;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onChangerOnglet(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: actif ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: actif ? Colors.white : AppTheme.textSecondaryOf(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _FraisAPayer extends StatelessWidget {
  final List<FraisAcademique> dettes;

  const _FraisAPayer({required this.dettes});

  @override
  Widget build(BuildContext context) {
    if (dettes.isEmpty) {
      return const EtatVide(
        icon: Icons.task_alt_rounded,
        titre: 'Aucun frais à payer',
        message: 'Vous êtes à jour !',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: dettes.map((d) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _DetteTile(dette: d),
        );
      }).toList(),
    );
  }
}

class _DetteTile extends StatelessWidget {
  final FraisAcademique dette;

  const _DetteTile({required this.dette});

  @override
  Widget build(BuildContext context) {
    final enRetard = dette.estEnRetard;
    final couleurStatut = enRetard ? AppTheme.error : AppTheme.warning;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: enRetard
              ? AppTheme.error.withValues(alpha: 0.4)
              : AppTheme.borderOf(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dette.libelle,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (dette.code.isNotEmpty)
                      Text(
                        dette.code,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondaryOf(context),
                              fontSize: 11,
                            ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMontant(dette.reste),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: enRetard
                              ? AppTheme.error
                              : AppTheme.textPrimaryOf(context),
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (enRetard) const PillBadge(label: 'En retard', color: AppTheme.error),
                ],
              ),
            ],
          ),
          if (dette.dateEcheance.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Échéance : ${formatDate(dette.dateEcheance)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryOf(context),
                    fontSize: 11,
                  ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payé : ${formatMontant(dette.montantPaye)} / ${formatMontant(dette.montant)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryOf(context),
                      fontSize: 11,
                    ),
              ),
              Text(
                '${dette.pourcentagePaye.round()}%',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: couleurStatut,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Historique extends StatelessWidget {
  final List<Paiement> paiements;

  const _Historique({required this.paiements});

  @override
  Widget build(BuildContext context) {
    if (paiements.isEmpty) {
      return const EtatVide(
        icon: Icons.history_rounded,
        titre: 'Aucun paiement enregistré',
      );
    }

    return Column(
      children: paiements.map((p) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _PaiementTile(paiement: p),
        );
      }).toList(),
    );
  }
}

class _PaiementTile extends StatelessWidget {
  final Paiement paiement;

  const _PaiementTile({required this.paiement});

  Color _couleurStatut(BuildContext contexte) {
    if (paiement.estValide) return AppTheme.success;
    if (paiement.estEnAttente) return AppTheme.warning;
    if (paiement.estRejete) return AppTheme.error;
    return AppTheme.textSecondaryOf(contexte);
  }

  @override
  Widget build(BuildContext context) {
    final couleur = _couleurStatut(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderOf(context)),
      ),
      child: Row(
        children: [
          IconePlaque(
            icone: paiement.estValide
                ? Icons.check_circle_rounded
                : Icons.schedule_rounded,
            couleur: couleur,
            taille: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paiement.reference,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatDate(paiement.datePaiement, avecHeure: true)} • ${paiement.libelleMode}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                        fontSize: 11,
                      ),
                ),
                if (paiement.type.isNotEmpty)
                  Text(
                    paiement.type.replaceAll('_', ' ').toLowerCase(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryOf(context),
                          fontSize: 11,
                        ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMontant(paiement.montant, paiement.devise),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              PillBadge(label: paiement.libelleStatut, color: couleur),
            ],
          ),
        ],
      ),
    );
  }
}
