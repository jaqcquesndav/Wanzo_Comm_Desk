import 'package:flutter/material.dart';
import '../models/financing_request.dart';
import '../models/payment_schedule.dart';
import '../services/payment_schedule_service.dart';

/// Types d'événements du cycle de vie des contrats
enum ContractLifecycleEvent {
  requestCreated,
  requestUnderReview,
  requestApproved,
  requestRejected,
  requestCanceled,
  fundsDisburse,
  contractActivated,
  paymentReceived,
  paymentLate,
  paymentDefaulted,
  contractSuspended,
  contractRestructured,
  contractCompleted,
  contractInLitigation,
}

extension ContractLifecycleEventExtension on ContractLifecycleEvent {
  String get displayName {
    switch (this) {
      case ContractLifecycleEvent.requestCreated:
        return 'Demande créée';
      case ContractLifecycleEvent.requestUnderReview:
        return 'Demande en examen';
      case ContractLifecycleEvent.requestApproved:
        return 'Demande approuvée';
      case ContractLifecycleEvent.requestRejected:
        return 'Demande rejetée';
      case ContractLifecycleEvent.requestCanceled:
        return 'Demande annulée';
      case ContractLifecycleEvent.fundsDisburse:
        return 'Fonds déboursés';
      case ContractLifecycleEvent.contractActivated:
        return 'Contrat activé';
      case ContractLifecycleEvent.paymentReceived:
        return 'Paiement reçu';
      case ContractLifecycleEvent.paymentLate:
        return 'Paiement en retard';
      case ContractLifecycleEvent.paymentDefaulted:
        return 'Paiement en défaut';
      case ContractLifecycleEvent.contractSuspended:
        return 'Contrat suspendu';
      case ContractLifecycleEvent.contractRestructured:
        return 'Contrat restructuré';
      case ContractLifecycleEvent.contractCompleted:
        return 'Contrat terminé';
      case ContractLifecycleEvent.contractInLitigation:
        return 'Contrat en contentieux';
    }
  }

  IconData get icon {
    switch (this) {
      case ContractLifecycleEvent.requestCreated:
        return Icons.description;
      case ContractLifecycleEvent.requestUnderReview:
        return Icons.hourglass_empty;
      case ContractLifecycleEvent.requestApproved:
        return Icons.check_circle;
      case ContractLifecycleEvent.requestRejected:
        return Icons.cancel;
      case ContractLifecycleEvent.requestCanceled:
        return Icons.close;
      case ContractLifecycleEvent.fundsDisburse:
        return Icons.attach_money;
      case ContractLifecycleEvent.contractActivated:
        return Icons.play_circle;
      case ContractLifecycleEvent.paymentReceived:
        return Icons.payment;
      case ContractLifecycleEvent.paymentLate:
        return Icons.warning;
      case ContractLifecycleEvent.paymentDefaulted:
        return Icons.error;
      case ContractLifecycleEvent.contractSuspended:
        return Icons.pause_circle;
      case ContractLifecycleEvent.contractRestructured:
        return Icons.build;
      case ContractLifecycleEvent.contractCompleted:
        return Icons.task_alt;
      case ContractLifecycleEvent.contractInLitigation:
        return Icons.gavel;
    }
  }

  Color get color {
    switch (this) {
      case ContractLifecycleEvent.requestCreated:
        return Colors.blue;
      case ContractLifecycleEvent.requestUnderReview:
        return Colors.orange;
      case ContractLifecycleEvent.requestApproved:
        return Colors.green;
      case ContractLifecycleEvent.requestRejected:
        return Colors.red;
      case ContractLifecycleEvent.requestCanceled:
        return Colors.grey;
      case ContractLifecycleEvent.fundsDisburse:
        return Colors.purple;
      case ContractLifecycleEvent.contractActivated:
        return Colors.green;
      case ContractLifecycleEvent.paymentReceived:
        return Colors.green;
      case ContractLifecycleEvent.paymentLate:
        return Colors.orange;
      case ContractLifecycleEvent.paymentDefaulted:
        return Colors.red;
      case ContractLifecycleEvent.contractSuspended:
        return Colors.orange;
      case ContractLifecycleEvent.contractRestructured:
        return Colors.blue;
      case ContractLifecycleEvent.contractCompleted:
        return Colors.green;
      case ContractLifecycleEvent.contractInLitigation:
        return Colors.red;
    }
  }
}

/// Service pour gérer les alertes et notifications du cycle de vie
class ContractLifecycleNotificationService {
  /// Afficher une notification pour un événement du cycle de vie
  static void showLifecycleNotification(
    BuildContext context,
    ContractLifecycleEvent event,
    FinancingRequest request, {
    String? customMessage,
    VoidCallback? onTap,
  }) {
    final message = customMessage ?? _getDefaultMessage(event, request);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              event.icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    event.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: event.color,
        duration: const Duration(seconds: 4),
        action: onTap != null
            ? SnackBarAction(
                label: 'Voir',
                textColor: Colors.white,
                onPressed: onTap,
              )
            : null,
      ),
    );
  }

  /// Vérifier et afficher les alertes pour les paiements en retard
  static void checkAndShowLatePaymentAlerts(
    BuildContext context,
    List<PaymentSchedule> schedules,
    FinancingRequest request,
  ) {
    final latePayments = PaymentScheduleService.getLatePayments(schedules);
    final defaultedPayments = PaymentScheduleService.getDefaultedPayments(schedules);

    if (defaultedPayments.isNotEmpty) {
      _showLatePaymentDialog(
        context,
        'Paiements en défaut',
        'Ce contrat a ${defaultedPayments.length} paiement(s) en défaut. '
        'Veuillez régulariser la situation rapidement.',
        Colors.red,
        Icons.error,
        defaultedPayments,
        request,
      );
    } else if (latePayments.isNotEmpty) {
      _showLatePaymentDialog(
        context,
        'Paiements en retard',
        'Ce contrat a ${latePayments.length} paiement(s) en retard. '
        'Veuillez effectuer les paiements pour éviter les pénalités.',
        Colors.orange,
        Icons.warning,
        latePayments,
        request,
      );
    }
  }

  /// Obtenir les prochaines échéances (dans les 7 prochains jours)
  static List<PaymentSchedule> getUpcomingPayments(List<PaymentSchedule> schedules) {
    final now = DateTime.now();
    final sevenDaysFromNow = now.add(const Duration(days: 7));
    
    return schedules
        .where((schedule) => 
          schedule.status != PaymentScheduleStatus.paid &&
          schedule.dueDate.isAfter(now) &&
          schedule.dueDate.isBefore(sevenDaysFromNow))
        .toList();
  }

  /// Afficher une alerte pour les prochaines échéances
  static void showUpcomingPaymentAlert(
    BuildContext context,
    List<PaymentSchedule> upcomingPayments,
    FinancingRequest request,
  ) {
    if (upcomingPayments.isEmpty) return;

    final nextPayment = upcomingPayments.first;
    final daysUntilDue = nextPayment.dueDate.difference(DateTime.now()).inDays;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: Icon(
            Icons.schedule,
            color: Colors.blue,
            size: 48,
          ),
          title: const Text('Échéance à venir'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vous avez une échéance dans $daysUntilDue jour(s) :',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Contrat: ${request.type.displayName}'),
                    Text('Institution: ${request.institution.displayName}'),
                    Text('Échéance ${nextPayment.scheduleNumber}'),
                    Text('Date: ${_formatDate(nextPayment.dueDate)}'),
                    Text('Montant: ${_formatCurrency(nextPayment.totalAmount, request.currency)}'),
                  ],
                ),
              ),
              if (upcomingPayments.length > 1) ...[
                const SizedBox(height: 8),
                Text(
                  'Et ${upcomingPayments.length - 1} autre(s) échéance(s) dans les 7 prochains jours.',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Plus tard'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Ici on pourrait naviguer vers l'écran de paiement
              },
              child: const Text('Voir détails'),
            ),
          ],
        );
      },
    );
  }

  /// Afficher le statut du cycle de vie du contrat
  static Widget buildLifecycleStatusBadge(String status) {
    ContractLifecycleEvent? event;
    
    switch (status.toLowerCase()) {
      case 'pending':
        event = ContractLifecycleEvent.requestCreated;
        break;
      case 'under_review':
        event = ContractLifecycleEvent.requestUnderReview;
        break;
      case 'approved':
        event = ContractLifecycleEvent.requestApproved;
        break;
      case 'rejected':
        event = ContractLifecycleEvent.requestRejected;
        break;
      case 'canceled':
      case 'cancelled':
        event = ContractLifecycleEvent.requestCanceled;
        break;
      case 'disbursed':
        event = ContractLifecycleEvent.fundsDisburse;
        break;
      case 'active':
      case 'repaying':
        event = ContractLifecycleEvent.contractActivated;
        break;
      case 'suspended':
        event = ContractLifecycleEvent.contractSuspended;
        break;
      case 'completed':
      case 'fully_repaid':
        event = ContractLifecycleEvent.contractCompleted;
        break;
      case 'litigation':
        event = ContractLifecycleEvent.contractInLitigation;
        break;
      case 'defaulted':
        event = ContractLifecycleEvent.paymentDefaulted;
        break;
    }

    if (event == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.help_outline, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              status,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: event.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: event.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(event.icon, size: 16, color: event.color),
          const SizedBox(width: 4),
          Text(
            event.displayName,
            style: TextStyle(
              color: event.color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static void _showLatePaymentDialog(
    BuildContext context,
    String title,
    String message,
    Color color,
    IconData icon,
    List<PaymentSchedule> payments,
    FinancingRequest request,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          icon: Icon(icon, color: color, size: 48),
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 16),
              const Text(
                'Paiements concernés:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...payments.take(3).map((payment) => Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Échéance ${payment.scheduleNumber}'),
                    Text(_formatCurrency(payment.remainingAmount, request.currency)),
                  ],
                ),
              )),
              if (payments.length > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '... et ${payments.length - 3} autre(s)',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Ici on pourrait naviguer vers l'écran de paiement
              },
              style: ElevatedButton.styleFrom(backgroundColor: color),
              child: const Text('Payer maintenant'),
            ),
          ],
        );
      },
    );
  }

  static String _getDefaultMessage(ContractLifecycleEvent event, FinancingRequest request) {
    switch (event) {
      case ContractLifecycleEvent.requestCreated:
        return 'Votre demande de ${request.type.displayName} a été créée avec succès.';
      case ContractLifecycleEvent.requestUnderReview:
        return 'Votre demande est maintenant en cours d\'examen par ${request.institution.displayName}.';
      case ContractLifecycleEvent.requestApproved:
        return 'Félicitations ! Votre demande a été approuvée.';
      case ContractLifecycleEvent.requestRejected:
        return 'Votre demande a été rejetée. Consultez les détails pour plus d\'informations.';
      case ContractLifecycleEvent.fundsDisburse:
        return 'Les fonds ont été déboursés. Votre contrat est maintenant actif.';
      case ContractLifecycleEvent.paymentReceived:
        return 'Paiement reçu avec succès.';
      case ContractLifecycleEvent.contractCompleted:
        return 'Félicitations ! Votre contrat est entièrement remboursé.';
      default:
        return 'Statut du contrat mis à jour.';
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String _formatCurrency(double amount, String currency) {
    return '${amount.toStringAsFixed(0)} $currency';
  }
}
