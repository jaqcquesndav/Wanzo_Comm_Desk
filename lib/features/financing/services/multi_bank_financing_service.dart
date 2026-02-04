import '../models/financing_request.dart';

/// Service pour la gestion multi-banques des contrats de financement
class MultiBankFinancingService {
  /// Obtenir tous les contrats actifs groupés par institution
  static Map<FinancialInstitution, List<FinancingRequest>> groupByInstitution(
    List<FinancingRequest> requests,
  ) {
    final Map<FinancialInstitution, List<FinancingRequest>> grouped = {};
    
    for (final request in requests) {
      if (!grouped.containsKey(request.institution)) {
        grouped[request.institution] = [];
      }
      grouped[request.institution]!.add(request);
    }
    
    return grouped;
  }

  /// Obtenir les statistiques par institution
  static Map<String, dynamic> getInstitutionStats(
    List<FinancingRequest> requests,
    FinancialInstitution institution,
  ) {
    final institutionRequests = requests
        .where((r) => r.institution == institution)
        .toList();

    final totalRequests = institutionRequests.length;
    final approvedRequests = institutionRequests
        .where((r) => r.status == 'approved' || 
                     r.status == 'disbursed' || 
                     r.status == 'repaying')
        .length;
    
    final totalAmount = institutionRequests
        .where((r) => r.status == 'approved' || 
                     r.status == 'disbursed' || 
                     r.status == 'repaying')
        .fold(0.0, (sum, r) => sum + r.amount);

    final activeContracts = institutionRequests
        .where((r) => r.status == 'disbursed' || r.status == 'repaying')
        .length;

    final completedContracts = institutionRequests
        .where((r) => r.status == 'fully_repaid' || r.status == 'completed')
        .length;

    return {
      'totalRequests': totalRequests,
      'approvedRequests': approvedRequests,
      'totalAmount': totalAmount,
      'activeContracts': activeContracts,
      'completedContracts': completedContracts,
      'approvalRate': totalRequests > 0 ? (approvedRequests / totalRequests * 100) : 0.0,
    };
  }

  /// Calculer le risque de crédit par institution
  static String calculateCreditRisk(
    List<FinancingRequest> requests,
    FinancialInstitution institution,
  ) {
    final institutionRequests = requests
        .where((r) => r.institution == institution)
        .toList();

    if (institutionRequests.isEmpty) return 'N/A';

    final activeContracts = institutionRequests
        .where((r) => r.status == 'disbursed' || r.status == 'repaying')
        .toList();

    if (activeContracts.isEmpty) return 'Faible';

    // Simuler le calcul de risque basé sur les retards de paiement
    int latePaymentsCount = 0;
    int totalPaymentsCount = 0;

    for (final contract in activeContracts) {
      final scheduledPayments = contract.scheduledPayments ?? [];
      final completedPayments = contract.completedPayments ?? [];
      
      totalPaymentsCount += scheduledPayments.length;
      
      // Compter les paiements en retard
      for (final scheduled in scheduledPayments) {
        final isCompleted = completedPayments.any((completed) =>
          completed.year == scheduled.year &&
          completed.month == scheduled.month &&
          completed.day == scheduled.day);
        
        if (!isCompleted && scheduled.isBefore(DateTime.now())) {
          latePaymentsCount++;
        }
      }
    }

    if (totalPaymentsCount == 0) return 'Faible';

    final latePaymentRate = latePaymentsCount / totalPaymentsCount;

    if (latePaymentRate >= 0.3) return 'Élevé';
    if (latePaymentRate >= 0.15) return 'Moyen';
    return 'Faible';
  }

  /// Obtenir les prochaines échéances pour toutes les institutions
  static Map<FinancialInstitution, List<Map<String, dynamic>>> getUpcomingPaymentsByInstitution(
    List<FinancingRequest> requests,
  ) {
    final Map<FinancialInstitution, List<Map<String, dynamic>>> upcomingPayments = {};
    
    for (final request in requests) {
      if (request.status != 'disbursed' && request.status != 'repaying') continue;
      
      final scheduledPayments = request.scheduledPayments ?? [];
      final completedPayments = request.completedPayments ?? [];
      final now = DateTime.now();
      final nextWeek = now.add(const Duration(days: 7));

      for (int i = 0; i < scheduledPayments.length; i++) {
        final dueDate = scheduledPayments[i];
        
        // Vérifier si le paiement n'est pas complété et est dans les 7 prochains jours
        final isCompleted = completedPayments.any((completed) =>
          completed.year == dueDate.year &&
          completed.month == dueDate.month &&
          completed.day == dueDate.day);
        
        if (!isCompleted && dueDate.isAfter(now) && dueDate.isBefore(nextWeek)) {
          if (!upcomingPayments.containsKey(request.institution)) {
            upcomingPayments[request.institution] = [];
          }
          
          upcomingPayments[request.institution]!.add({
            'request': request,
            'dueDate': dueDate,
            'amount': request.monthlyPayment ?? 0.0,
            'scheduleNumber': i + 1,
            'daysUntilDue': dueDate.difference(now).inDays,
          });
        }
      }
    }

    // Trier par date d'échéance
    for (final institution in upcomingPayments.keys) {
      upcomingPayments[institution]!.sort((a, b) => 
        (a['dueDate'] as DateTime).compareTo(b['dueDate'] as DateTime));
    }

    return upcomingPayments;
  }

  /// Calculer la capacité d'emprunt restante par institution
  static Map<FinancialInstitution, double> calculateRemainingBorrowingCapacity(
    List<FinancingRequest> requests,
    Map<FinancialInstitution, double> institutionLimits,
  ) {
    final Map<FinancialInstitution, double> remainingCapacity = {};
    
    for (final institution in FinancialInstitution.values) {
      final institutionLimit = institutionLimits[institution] ?? 0.0;
      
      final currentExposure = requests
          .where((r) => r.institution == institution && 
                       (r.status == 'approved' || 
                        r.status == 'disbursed' || 
                        r.status == 'repaying'))
          .fold(0.0, (sum, r) => sum + r.amount);
      
      remainingCapacity[institution] = institutionLimit - currentExposure;
    }
    
    return remainingCapacity;
  }

  /// Recommander la meilleure institution pour une nouvelle demande
  static Map<String, dynamic> recommendBestInstitution(
    List<FinancingRequest> requests,
    double requestedAmount,
    FinancingType financingType,
    Map<FinancialInstitution, double> institutionLimits,
  ) {
    final recommendations = <Map<String, dynamic>>[];
    
    for (final institution in FinancialInstitution.values) {
      final stats = getInstitutionStats(requests, institution);
      final risk = calculateCreditRisk(requests, institution);
      final remainingCapacity = calculateRemainingBorrowingCapacity(
        requests, 
        institutionLimits,
      )[institution] ?? 0.0;
      
      // Vérifier si l'institution peut financer le montant demandé
      if (remainingCapacity < requestedAmount) continue;
      
      // Calculer un score de recommandation
      double score = 0.0;
      
      // Facteur d'approbation (30%)
      final approvalRate = stats['approvalRate'] as double;
      score += (approvalRate / 100) * 0.3;
      
      // Facteur de risque (25%)
      switch (risk) {
        case 'Faible':
          score += 0.25;
          break;
        case 'Moyen':
          score += 0.15;
          break;
        case 'Élevé':
          score += 0.05;
          break;
      }
      
      // Facteur de capacité restante (25%)
      final capacityFactor = remainingCapacity / (institutionLimits[institution] ?? 1);
      score += capacityFactor * 0.25;
      
      // Facteur d'expérience (20%)
      final totalContracts = stats['totalRequests'] as int;
      final experienceFactor = totalContracts > 0 ? (totalContracts / 10).clamp(0.0, 1.0) : 0.0;
      score += experienceFactor * 0.2;
      
      recommendations.add({
        'institution': institution,
        'score': score,
        'approvalRate': approvalRate,
        'risk': risk,
        'remainingCapacity': remainingCapacity,
        'activeContracts': stats['activeContracts'],
        'reason': _getRecommendationReason(score, approvalRate, risk, remainingCapacity),
      });
    }
    
    // Trier par score décroissant
    recommendations.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    
    return {
      'recommendations': recommendations,
      'bestOption': recommendations.isNotEmpty ? recommendations.first : null,
      'hasViableOptions': recommendations.isNotEmpty,
    };
  }

  static String _getRecommendationReason(
    double score,
    double approvalRate,
    String risk,
    double remainingCapacity,
  ) {
    if (score >= 0.8) {
      return 'Excellent historique et capacité élevée';
    } else if (score >= 0.6) {
      return 'Bon partenaire avec risque maîtrisé';
    } else if (score >= 0.4) {
      return 'Option viable avec quelques réserves';
    } else {
      return 'Risque élevé ou capacité limitée';
    }
  }

  /// Générer un rapport de diversification des risques
  static Map<String, dynamic> generateRiskDiversificationReport(
    List<FinancingRequest> requests,
  ) {
    final totalActiveAmount = requests
        .where((r) => r.status == 'disbursed' || r.status == 'repaying')
        .fold(0.0, (sum, r) => sum + r.amount);

    if (totalActiveAmount == 0) {
      return {
        'isDiversified': true,
        'concentrationRisk': 'Faible',
        'recommendations': ['Aucun contrat actif'],
        'institutionBreakdown': <Map<String, dynamic>>[],
      };
    }

    final institutionBreakdown = <Map<String, dynamic>>[];
    double maxConcentration = 0.0;
    FinancialInstitution? mostExposedInstitution;

    for (final institution in FinancialInstitution.values) {
      final institutionAmount = requests
          .where((r) => r.institution == institution && 
                       (r.status == 'disbursed' || r.status == 'repaying'))
          .fold(0.0, (sum, r) => sum + r.amount);

      if (institutionAmount > 0) {
        final concentration = institutionAmount / totalActiveAmount;
        
        institutionBreakdown.add({
          'institution': institution,
          'amount': institutionAmount,
          'percentage': concentration * 100,
          'contractCount': requests
              .where((r) => r.institution == institution && 
                           (r.status == 'disbursed' || r.status == 'repaying'))
              .length,
        });

        if (concentration > maxConcentration) {
          maxConcentration = concentration;
          mostExposedInstitution = institution;
        }
      }
    }

    // Évaluer le risque de concentration
    String concentrationRisk;
    List<String> recommendations = [];

    if (maxConcentration >= 0.7) {
      concentrationRisk = 'Élevé';
      recommendations.add('Diversifier vers d\'autres institutions');
      recommendations.add('Réduire l\'exposition à ${mostExposedInstitution?.displayName}');
    } else if (maxConcentration >= 0.5) {
      concentrationRisk = 'Moyen';
      recommendations.add('Considérer une diversification progressive');
    } else {
      concentrationRisk = 'Faible';
      recommendations.add('Bonne diversification maintenue');
    }

    return {
      'isDiversified': maxConcentration < 0.5,
      'concentrationRisk': concentrationRisk,
      'maxConcentration': maxConcentration * 100,
      'mostExposedInstitution': mostExposedInstitution,
      'recommendations': recommendations,
      'institutionBreakdown': institutionBreakdown,
      'totalActiveAmount': totalActiveAmount,
    };
  }
}
