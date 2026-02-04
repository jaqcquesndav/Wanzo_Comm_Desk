import 'package:flutter/material.dart';
import '../models/financing_request.dart';

/// Widget pour afficher l'état d'une demande de financement selon le cycle de vie
class FinancingRequestStatusWidget extends StatelessWidget {
  final FinancingRequest request;
  final bool showFullDetails;

  const FinancingRequestStatusWidget({
    super.key,
    required this.request,
    this.showFullDetails = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getStatusDisplayText(),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: _getStatusColor(),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (request.requestNumber != null)
                        Text(
                          'N° ${request.requestNumber}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                _buildStatusBadge(context),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatusDescription(context),
            if (showFullDetails) ...[
              const SizedBox(height: 12),
              _buildStatusTimeline(context),
            ],
            const SizedBox(height: 12),
            _buildNextStepsInfo(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color = _getStatusColor();

    switch (request.status.toLowerCase()) {
      case 'pending':
        icon = Icons.hourglass_empty;
        break;
      case 'under_review':
        icon = Icons.search;
        break;
      case 'approved':
        icon = Icons.check_circle;
        break;
      case 'rejected':
        icon = Icons.cancel;
        break;
      case 'disbursed':
        icon = Icons.account_balance_wallet;
        break;
      case 'active':
        icon = Icons.trending_up;
        break;
      case 'completed':
        icon = Icons.check_circle_outline;
        break;
      case 'defaulted':
        icon = Icons.warning;
        break;
      case 'suspended':
        icon = Icons.pause_circle;
        break;
      case 'litigation':
        icon = Icons.gavel;
        break;
      case 'canceled':
        icon = Icons.block;
        break;
      default:
        icon = Icons.help_outline;
    }

    return Icon(icon, color: color, size: 32);
  }

  Widget _buildStatusBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getStatusColor(), width: 1),
      ),
      child: Text(
        _getStatusDisplayText().toUpperCase(),
        style: TextStyle(
          color: _getStatusColor(),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildStatusDescription(BuildContext context) {
    String description = _getStatusDescription();
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(BuildContext context) {
    final List<Map<String, dynamic>> timeline = [];
    
    timeline.add({
      'title': 'Demande soumise',
      'date': request.requestDate,
      'completed': true,
    });

    if (request.status != 'pending') {
      timeline.add({
        'title': 'Mise en examen',
        'date': request.statusDate,
        'completed': true,
      });
    }

    if (request.approvalDate != null) {
      timeline.add({
        'title': 'Demande approuvée',
        'date': request.approvalDate,
        'completed': true,
      });
    }

    if (request.disbursementDate != null) {
      timeline.add({
        'title': 'Fonds déboursés',
        'date': request.disbursementDate,
        'completed': true,
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Historique',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...timeline.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                item['completed'] ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 16,
                color: item['completed'] ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item['title'],
                  style: TextStyle(
                    fontSize: 12,
                    color: item['completed'] ? Colors.black87 : Colors.grey,
                  ),
                ),
              ),
              if (item['date'] != null)
                Text(
                  _formatDate(item['date'] as DateTime),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildNextStepsInfo(BuildContext context) {
    final nextSteps = _getNextSteps();
    if (nextSteps.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.arrow_forward, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Prochaines étapes',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...nextSteps.map((step) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: TextStyle(color: Colors.blue.shade700)),
                Expanded(
                  child: Text(
                    step,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (request.status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'under_review':
        return Colors.blue;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'disbursed':
        return Colors.purple;
      case 'active':
        return Colors.teal;
      case 'completed':
        return Colors.green.shade700;
      case 'defaulted':
        return Colors.red.shade700;
      case 'suspended':
        return Colors.amber.shade700;
      case 'litigation':
        return Colors.deepOrange;
      case 'canceled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDisplayText() {
    switch (request.status.toLowerCase()) {
      case 'pending':
        return 'En attente d\'examen';
      case 'under_review':
        return 'En cours d\'examen';
      case 'approved':
        return 'Approuvée';
      case 'rejected':
        return 'Rejetée';
      case 'disbursed':
        return 'Fonds déboursés';
      case 'active':
        return 'Contrat actif';
      case 'completed':
        return 'Terminé';
      case 'defaulted':
        return 'En défaut';
      case 'suspended':
        return 'Suspendu';
      case 'litigation':
        return 'En contentieux';
      case 'canceled':
        return 'Annulé';
      default:
        return 'État inconnu';
    }
  }

  String _getStatusDescription() {
    switch (request.status.toLowerCase()) {
      case 'pending':
        return 'Votre demande a été soumise et est en attente d\'examen par l\'équipe de crédit.';
      case 'under_review':
        return 'Votre demande est actuellement examinée par nos analystes. Nous pourrions vous demander des informations complémentaires.';
      case 'approved':
        return 'Félicitations ! Votre demande a été approuvée. Un contrat va être créé prochainement.';
      case 'rejected':
        return 'Malheureusement, votre demande n\'a pas pu être approuvée. Consultez les notes pour plus de détails.';
      case 'disbursed':
        return 'Les fonds ont été déboursés. Le suivi des remboursements commence selon l\'échéancier établi.';
      case 'active':
        return 'Votre contrat est actif. Suivez vos échéances de remboursement dans la section appropriée.';
      case 'completed':
        return 'Votre contrat a été intégralement remboursé. Merci pour votre confiance !';
      case 'defaulted':
        return 'Le contrat présente des retards de paiement importants. Veuillez contacter votre conseiller.';
      case 'suspended':
        return 'Le contrat a été temporairement suspendu. Des discussions sont en cours pour une résolution.';
      case 'litigation':
        return 'Le dossier fait l\'objet d\'une procédure de contentieux.';
      case 'canceled':
        return 'La demande ou le contrat a été annulé.';
      default:
        return 'État non défini dans le système.';
    }
  }

  List<String> _getNextSteps() {
    switch (request.status.toLowerCase()) {
      case 'pending':
        return [
          'Votre dossier sera traité dans les prochains jours ouvrables',
          'Préparez d\'éventuels documents complémentaires',
        ];
      case 'under_review':
        return [
          'Restez disponible pour d\'éventuelles questions',
          'Surveillez vos notifications',
        ];
      case 'approved':
        return [
          'Attendez la création du contrat',
          'Préparez-vous à la signature',
        ];
      case 'disbursed':
        return [
          'Consultez votre échéancier de remboursement',
          'Programmez vos paiements',
        ];
      case 'active':
        return [
          'Respectez les échéances de paiement',
          'Consultez régulièrement votre solde',
        ];
      default:
        return [];
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
