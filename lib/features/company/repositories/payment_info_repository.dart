import 'package:flutter/foundation.dart';
import '../models/payment_info.dart';
import '../models/bank_account_info.dart';
import '../models/mobile_money_account.dart';
import '../services/company_api_service.dart';

class PaymentInfoRepository {
  final CompanyApiService _apiService;

  PaymentInfoRepository({required CompanyApiService apiService})
    : _apiService = apiService;

  /// Récupère les informations de paiement d'une entreprise
  Future<PaymentInfo?> getPaymentInfo(String companyId) async {
    try {
      final response = await _apiService.getPaymentInfo(companyId);
      if (response.success && response.data != null) {
        return PaymentInfo.fromJson(response.data!);
      }
      debugPrint("Failed to fetch payment info: ${response.message}");
      return null;
    } catch (e) {
      debugPrint("Error fetching payment info: $e");
      return null;
    }
  }

  /// Met à jour les informations de paiement
  Future<PaymentInfo?> updatePaymentInfo(
    String companyId,
    PaymentInfo paymentInfo,
  ) async {
    try {
      final response = await _apiService.updatePaymentInfo(
        companyId,
        paymentInfo.toJson(),
      );
      if (response.success && response.data != null) {
        return PaymentInfo.fromJson(response.data!);
      }
      debugPrint("Failed to update payment info: ${response.message}");
      return null;
    } catch (e) {
      debugPrint("Error updating payment info: $e");
      return null;
    }
  }

  /// Ajoute un compte bancaire
  Future<BankAccountInfo?> addBankAccount(
    String companyId,
    Map<String, dynamic> bankAccountData,
  ) async {
    try {
      final response = await _apiService.addBankAccount(
        companyId,
        bankAccountData,
      );
      if (response.success && response.data != null) {
        return BankAccountInfo.fromJson(response.data!);
      }
      debugPrint("Failed to add bank account: ${response.message}");
      return null;
    } catch (e) {
      debugPrint("Error adding bank account: $e");
      return null;
    }
  }

  /// Ajoute un compte Mobile Money
  Future<MobileMoneyAccount?> addMobileMoneyAccount(
    String companyId,
    Map<String, dynamic> mobileMoneyAccountData,
  ) async {
    try {
      final response = await _apiService.addMobileMoneyAccount(
        companyId,
        mobileMoneyAccountData,
      );
      if (response.success && response.data != null) {
        return MobileMoneyAccount.fromJson(response.data!);
      }
      debugPrint("Failed to add mobile money account: ${response.message}");
      return null;
    } catch (e) {
      debugPrint("Error adding mobile money account: $e");
      return null;
    }
  }

  /// Vérifie un compte Mobile Money
  Future<bool> verifyMobileMoneyAccount(
    String companyId,
    String phoneNumber,
    String verificationCode,
  ) async {
    try {
      final response = await _apiService.verifyMobileMoneyAccount(
        companyId,
        phoneNumber,
        verificationCode,
      );
      return response.success;
    } catch (e) {
      debugPrint("Error verifying mobile money account: $e");
      return false;
    }
  }

  /// Supprime un compte bancaire
  Future<bool> deleteBankAccount(String companyId, String accountNumber) async {
    try {
      final response = await _apiService.deleteBankAccount(
        companyId,
        accountNumber,
      );
      return response.success;
    } catch (e) {
      debugPrint("Error deleting bank account: $e");
      return false;
    }
  }

  /// Supprime un compte Mobile Money
  Future<bool> deleteMobileMoneyAccount(
    String companyId,
    String phoneNumber,
  ) async {
    try {
      final response = await _apiService.deleteMobileMoneyAccount(
        companyId,
        phoneNumber,
      );
      return response.success;
    } catch (e) {
      debugPrint("Error deleting mobile money account: $e");
      return false;
    }
  }

  /// Définit un compte bancaire par défaut
  Future<PaymentInfo?> setDefaultBankAccount(
    String companyId,
    String accountNumber,
  ) async {
    try {
      final response = await _apiService.setDefaultBankAccount(
        companyId,
        accountNumber,
      );
      if (response.success && response.data != null) {
        return PaymentInfo.fromJson(response.data!);
      }
      debugPrint("Failed to set default bank account: ${response.message}");
      return null;
    } catch (e) {
      debugPrint("Error setting default bank account: $e");
      return null;
    }
  }

  /// Définit un compte Mobile Money par défaut
  Future<PaymentInfo?> setDefaultMobileMoneyAccount(
    String companyId,
    String phoneNumber,
  ) async {
    try {
      final response = await _apiService.setDefaultMobileMoneyAccount(
        companyId,
        phoneNumber,
      );
      if (response.success && response.data != null) {
        return PaymentInfo.fromJson(response.data!);
      }
      debugPrint(
        "Failed to set default mobile money account: ${response.message}",
      );
      return null;
    } catch (e) {
      debugPrint("Error setting default mobile money account: $e");
      return null;
    }
  }
}
