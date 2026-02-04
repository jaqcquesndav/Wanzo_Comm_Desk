import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/payment_schedule.dart';
import '../services/payment_schedule_service.dart';

class PaymentScheduleWidget extends StatelessWidget {
  final List<PaymentSchedule> schedules;
  final Function(PaymentSchedule)? onPaymentTap;
  final bool showSummary;
  final String currency;

  const PaymentScheduleWidget({
    super.key,
    required this.schedules,
    this.onPaymentTap,
    this.showSummary = true,
    this.currency = 'CDF',
  });

  @override
  Widget build(BuildContext context) {
    if (schedules.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text('Aucun échéancier disponible'),
          ),
        ),
      );
    }

    // Mettre à jour les statuts en fonction des dates actuelles
    final updatedSchedules = PaymentScheduleService.updateScheduleStatuses(schedules);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSummary) _buildSummaryCard(context, updatedSchedules),
        if (showSummary) const SizedBox(height: 8),
        _buildScheduleList(context, updatedSchedules),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, List<PaymentSchedule> schedules) {
    final totalPaid = PaymentScheduleService.calculateTotalPaid(schedules);
    final totalRemaining = PaymentScheduleService.calculateTotalRemaining(schedules);
    final latePayments = PaymentScheduleService.getLatePayments(schedules);
    final defaultedPayments = PaymentScheduleService.getDefaultedPayments(schedules);
    final nextPayment = PaymentScheduleService.getNextDuePayment(schedules);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Résumé du remboursement',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    context,
                    'Total payé',
                    NumberFormat.currency(locale: 'fr_FR', symbol: currency)
                        .format(totalPaid),
                    Colors.green,
                    Icons.check_circle,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    context,
                    'Reste à payer',
                    NumberFormat.currency(locale: 'fr_FR', symbol: currency)
                        .format(totalRemaining),
                    Colors.blue,
                    Icons.schedule,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    context,
                    'En retard',
                    '${latePayments.length}',
                    Colors.orange,
                    Icons.warning,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    context,
                    'En défaut',
                    '${defaultedPayments.length}',
                    Colors.red,
                    Icons.error,
                  ),
                ),
              ],
            ),
            if (nextPayment != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getStatusColor(nextPayment.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getStatusColor(nextPayment.status).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.event,
                      color: _getStatusColor(nextPayment.status),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Prochaine échéance',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            DateFormat('dd/MM/yyyy').format(nextPayment.dueDate),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      NumberFormat.currency(locale: 'fr_FR', symbol: currency)
                          .format(nextPayment.remainingAmount),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(nextPayment.status),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
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
    );
  }

  Widget _buildScheduleList(BuildContext context, List<PaymentSchedule> schedules) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Détail des échéances',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: schedules.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final schedule = schedules[index];
              return _buildScheduleItem(context, schedule);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(BuildContext context, PaymentSchedule schedule) {
    final statusColor = _getStatusColor(schedule.status);
    final statusIcon = _getStatusIcon(schedule.status);
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        ),
        child: Icon(
          statusIcon,
          color: statusColor,
          size: 20,
        ),
      ),
      title: Row(
        children: [
          Text(
            'Échéance ${schedule.scheduleNumber}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              schedule.status.displayName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                'Échéance: ${DateFormat('dd/MM/yyyy').format(schedule.dueDate)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(Icons.account_balance_wallet, size: 14, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                'Montant: ${NumberFormat.currency(locale: 'fr_FR', symbol: currency).format(schedule.totalAmount)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          if (schedule.status == PaymentScheduleStatus.partial) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.payment, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Payé: ${NumberFormat.currency(locale: 'fr_FR', symbol: currency).format(schedule.paidAmount)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
          if (schedule.isLate && schedule.status != PaymentScheduleStatus.paid) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.red),
                const SizedBox(width: 4),
                Text(
                  'En retard de ${schedule.daysLate} jours',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
          if (schedule.paymentDate != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.check_circle, size: 14, color: Colors.green),
                const SizedBox(width: 4),
                Text(
                  'Payé le ${DateFormat('dd/MM/yyyy').format(schedule.paymentDate!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      trailing: schedule.status != PaymentScheduleStatus.paid
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  NumberFormat.currency(locale: 'fr_FR', symbol: currency)
                      .format(schedule.remainingAmount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                if (onPaymentTap != null)
                  TextButton(
                    onPressed: () => onPaymentTap!(schedule),
                    style: TextButton.styleFrom(
                      foregroundColor: statusColor,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 20),
                    ),
                    child: const Text('Payer', style: TextStyle(fontSize: 12)),
                  ),
              ],
            )
          : Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 32,
            ),
      onTap: onPaymentTap != null ? () => onPaymentTap!(schedule) : null,
    );
  }

  Color _getStatusColor(PaymentScheduleStatus status) {
    switch (status) {
      case PaymentScheduleStatus.pending:
        return Colors.orange;
      case PaymentScheduleStatus.paid:
        return Colors.green;
      case PaymentScheduleStatus.late:
        return Colors.deepOrange;
      case PaymentScheduleStatus.defaulted:
        return Colors.red;
      case PaymentScheduleStatus.partial:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(PaymentScheduleStatus status) {
    switch (status) {
      case PaymentScheduleStatus.pending:
        return Icons.schedule;
      case PaymentScheduleStatus.paid:
        return Icons.check_circle;
      case PaymentScheduleStatus.late:
        return Icons.warning;
      case PaymentScheduleStatus.defaulted:
        return Icons.error;
      case PaymentScheduleStatus.partial:
        return Icons.payment;
    }
  }
}
