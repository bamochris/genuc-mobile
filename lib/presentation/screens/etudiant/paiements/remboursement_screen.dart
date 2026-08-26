import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../providers/student_provider.dart';
import '../../../widgets/etat_widgets.dart';
import '../../../widgets/portail_widgets.dart';

/// Écran de demande de remboursement pour l'étudiant.
///
/// Permet à l'étudiant de sélectionner un paiement validé et de soumettre
/// une demande de remboursement avec un motif. Correspond à l'endpoint
/// `POST /api/remboursements/demander` du backend.
class RemboursementScreen extends StatefulWidget {
  const RemboursementScreen({super.key});

  @override
  State<RemboursementScreen> createState() => _RemboursementScreenState();
}

class _RemboursementScreenState extends State<RemboursementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _motifController = TextEditingController();
  int? _selectedPaiementId;
  bool _submitting = false;
  String? _message;
  bool _isError = false;

  @override
  void dispose() {
    _motifController.dispose();
    super.dispose();
  }

  Future<void> _soumettre() async {
    if (!_formKey.currentState!.validate() || _selectedPaiementId == null) return;

    setState(() {
      _submitting = true;
      _message = null;
    });

    try {
      final studentProvider = context.read<StudentProvider>();
      await studentProvider.demanderRemboursement(
        paiementId: _selectedPaiementId!,
        motif: _motifController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _message = '✅ Votre demande de remboursement a été soumise avec succès.';
          _isError = false;
          _motifController.clear();
          _selectedPaiementId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = '❌ Erreur: ${e.toString()}';
          _isError = true;
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentProvider = context.watch<StudentProvider>();
    final paiementsValides = studentProvider.paiementsValides;

    return PagePortail(
      titre: 'Demander un remboursement',
      corps: RefreshIndicator(
        onRefresh: () => studentProvider.loadSituationFinanciere(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.info.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppTheme.info, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sélectionnez un paiement validé et expliquez la raison de votre demande. '
                      'Le service social et l\'administration traiteront votre requête.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryOf(context),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Message de statut
            if (_message != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_isError ? AppTheme.error : AppTheme.success)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (_isError ? AppTheme.error : AppTheme.success)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Text(_message!, style: TextStyle(
                  color: _isError ? AppTheme.error : AppTheme.success,
                  fontSize: 13,
                )),
              ),
              const SizedBox(height: 16),
            ],

            // Formulaire
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Paiement à rembourser',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (studentProvider.isLoading)
                    const EtatChargement(message: 'Chargement de vos paiements…')
                  else if (paiementsValides.isEmpty)
                    const EtatVide(
                      icon: Icons.check_circle_outline_rounded,
                      titre: 'Aucun paiement éligible',
                      message: 'Vous n\'avez aucun paiement validé pouvant faire l\'objet d\'un remboursement.',
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderOf(context)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: paiementsValides.map((p) {
                          final selected = _selectedPaiementId == p.id;
                          return InkWell(
                            onTap: () => setState(() => _selectedPaiementId = p.id),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppTheme.primary.withValues(alpha: 0.08)
                                    : null,
                                border: Border(
                                  bottom: BorderSide(color: AppTheme.borderOf(context)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selected
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    color: selected ? AppTheme.primary : AppTheme.textMutedOf(context),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.reference,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${formatDate(p.datePaiement)} • ${p.libelleMode}',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: AppTheme.textSecondaryOf(context),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    formatMontant(p.montant, p.devise),
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  if (_selectedPaiementId == null && paiementsValides.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Sélectionnez un paiement dans la liste ci-dessus.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.warning,
                        fontSize: 11,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  Text(
                    'Motif de la demande',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _motifController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Expliquez la raison de votre demande de remboursement…',
                      hintStyle: TextStyle(color: AppTheme.textMutedOf(context)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Veuillez saisir un motif';
                      }
                      if (value.trim().length < 10) {
                        return 'Le motif doit contenir au moins 10 caractères';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _soumettre,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(_submitting ? 'Envoi en cours…' : 'Soumettre la demande'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
