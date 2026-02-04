import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/financing_request.dart';
import '../services/multi_bank_financing_service.dart';

class MultiBankDashboardWidget extends StatelessWidget {
  final List<FinancingRequest> financingRequests;
  final Map<FinancialInstitution, double> institutionLimits;

  const MultiBankDashboardWidget({
    super.key,
    required this.financingRequests,
    this.institutionLimits = const {},
  });

  @override
  Widget build(BuildContext context) {
    final groupedRequests = MultiBankFinancingService.groupByInstitution(financingRequests);
    final upcomingPayments = MultiBankFinancingService.getUpcomingPaymentsByInstitution(financingRequests);
    final riskReport = MultiBankFinancingService.generateRiskDiversificationReport(financingRequests);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSummaryCards(context, riskReport),
        const SizedBox(height: 16),
        _buildInstitutionBreakdown(context, groupedRequests),
        const SizedBox(height: 16),
        _buildUpcomingPayments(context, upcomingPayments),
        const SizedBox(height: 16),
        _buildRiskDiversification(context, riskReport),
      ],
    );
  }

  Widget _buildSummaryCards(BuildContext context, Map<String, dynamic> riskReport) {
    final totalActiveAmount = riskReport['totalActiveAmount'] as double;
    final concentrationRisk = riskReport['concentrationRisk'] as String;
    final activeContracts = financingRequests
        .where((r) => r.status == 'disbursed' || r.status == 'repaying')
        .length;
    final totalInstitutions = MultiBankFinancingService.groupByInstitution(financingRequests).length;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            context,
            'Exposition totale',
            NumberFormat.currency(locale: 'fr_FR', symbol: 'CDF').format(totalActiveAmount),
            Icons.account_balance_wallet,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            context,
            'Contrats actifs',
            '$activeContracts',
            Icons.description,
            Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            context,
            'Institutions',
            '$totalInstitutions',
            Icons.business,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            context,
            'Risque',
            concentrationRisk,
            Icons.warning,
            _getRiskColor(concentrationRisk),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstitutionBreakdown(
    BuildContext context,
    Map<FinancialInstitution, List<FinancingRequest>> groupedRequests,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Répartition par institution',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (groupedRequests.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Aucun contrat actif'),
                ),
              )
            else
              ...groupedRequests.entries.map((entry) {
                final institution = entry.key;
                final requests = entry.value;
                final stats = MultiBankFinancingService.getInstitutionStats(
                  financingRequests,
                  institution,
                );
                final risk = MultiBankFinancingService.calculateCreditRisk(
                  financingRequests,
                  institution,
                );

                return _buildInstitutionCard(context, institution, requests, stats, risk);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildInstitutionCard(
    BuildContext context,
    FinancialInstitution institution,
    List<FinancingRequest> requests,
    Map<String, dynamic> stats,
    String risk,
  ) {
    final activeContracts = stats['activeContracts'] as int;
    final totalAmount = stats['totalAmount'] as double;
    final approvalRate = stats['approvalRate'] as double;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getInstitutionColor(institution).withValues(alpha: 0.1),
          child: Icon(
            Icons.account_balance,
            color: _getInstitutionColor(institution),
          ),
        ),
        title: Text(
          institution.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '$activeContracts contrat(s) • ${NumberFormat.currency(locale: 'fr_FR', symbol: 'CDF').format(totalAmount)}',
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: _getRiskColor(risk).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _getRiskColor(risk).withValues(alpha: 0.3)),
          ),
          child: Text(
            risk,
            style: TextStyle(
              color: _getRiskColor(risk),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Taux d\'approbation',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${approvalRate.toStringAsFixed(1)}%',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: approvalRate >= 80 ? Colors.green : 
                                 approvalRate >= 60 ? Colors.orange : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contrats terminés',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${stats['completedContracts']}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                if (institutionLimits.containsKey(institution))
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Capacité restante',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          NumberFormat.compact(locale: 'fr_FR').format(
                            (institutionLimits[institution] ?? 0) - totalAmount,
                          ),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingPayments(
    BuildContext context,
    Map<FinancialInstitution, List<Map<String, dynamic>>> upcomingPayments,
  ) {
    final totalUpcoming = upcomingPayments.values
        .fold(0, (sum, payments) => sum + payments.length);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Prochaines échéances (7 jours)',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalUpcoming',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (upcomingPayments.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Aucune échéance dans les 7 prochains jours'),
                ),
              )
            else
              ...upcomingPayments.entries.map((entry) {
                final institution = entry.key;
                final payments = entry.value;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.account_balance,
                            color: _getInstitutionColor(institution),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            institution.displayName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...payments.map((payment) {
                      final request = payment['request'] as FinancingRequest;
                      final dueDate = payment['dueDate'] as DateTime;
                      final amount = payment['amount'] as double;
                      final daysUntil = payment['daysUntilDue'] as int;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 4, left: 16),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(4),
                          border: const Border(
                            left: BorderSide(
                              color: Colors.orange,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${request.type.displayName} - Échéance ${payment['scheduleNumber']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Dans $daysUntil jour(s) • ${DateFormat('dd/MM/yyyy').format(dueDate)}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              NumberFormat.currency(locale: 'fr_FR', symbol: request.currency)
                                  .format(amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildRiskDiversification(BuildContext context, Map<String, dynamic> riskReport) {
    final isDiversified = riskReport['isDiversified'] as bool;
    final concentrationRisk = riskReport['concentrationRisk'] as String;
    final recommendations = riskReport['recommendations'] as List<String>;
    final breakdown = riskReport['institutionBreakdown'] as List<Map<String, dynamic>>;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isDiversified ? Icons.check_circle : Icons.warning,
                  color: isDiversified ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Diversification des risques',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getRiskColor(concentrationRisk).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    concentrationRisk,
                    style: TextStyle(
                      color: _getRiskColor(concentrationRisk),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (breakdown.isNotEmpty) ...[
              Text(
                'Répartition par institution:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...breakdown.map((item) {
                final institution = item['institution'] as FinancialInstitution;
                final percentage = item['percentage'] as double;
                final amount = item['amount'] as double;

                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getInstitutionColor(institution),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(institution.displayName),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        NumberFormat.compact(locale: 'fr_FR').format(amount),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
            ],
            Text(
              'Recommandations:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            ...recommendations.map((recommendation) => Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(child: Text(recommendation)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Color _getRiskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'faible':
        return Colors.green;
      case 'moyen':
        return Colors.orange;
      case 'élevé':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getInstitutionColor(FinancialInstitution institution) {
    switch (institution) {
      case FinancialInstitution.bonneMoisson:
        return Colors.green;
      case FinancialInstitution.tid:
        return Colors.blue;
      case FinancialInstitution.smico:
        return Colors.orange;
      case FinancialInstitution.tmb:
        return Colors.purple;
      case FinancialInstitution.equitybcdc:
        return Colors.red;
      case FinancialInstitution.wanzoPass:
        return Colors.teal;
    }
  }
}
