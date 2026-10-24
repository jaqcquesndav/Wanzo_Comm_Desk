import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:wanzo/core/enums/business_unit_enums.dart';
import 'package:wanzo/core/models/operation_payment.dart';
import 'package:wanzo/core/models/payment_method_code.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/shared_widgets/payment_details_fields.dart';
import 'package:wanzo/core/utils/document_issuer.dart';
import 'package:wanzo/core/utils/hive_setup.dart';
import 'package:wanzo/core/widgets/operator_logo.dart';
import 'package:wanzo/features/sales/models/sale.dart';
import 'package:wanzo/features/sales/models/sale_item.dart';
import 'package:wanzo/features/sales/repositories/sales_repository.dart';
import 'package:wanzo/features/sales/services/sale_dto.dart';

/// Défauts corrigés (audit du 24 oct. 2026) :
/// - addSale reconstruisait la vente champ par champ et perdait l'échéance, la
///   référence de paiement, la TVA, le HT, la remise et l'unité d'affaires ;
/// - le moyen de paiement partait en libellé traduit (« Espèces ») ;
/// - Mobile Money sans opérateur ni référence, crédit sans échéance ;
/// - la réimpression prenait l'unité COURANTE de l'utilisateur.
void main() {
  Sale vente({String method = 'Espèces'}) => Sale(
        id: '',
        date: DateTime(2026, 10, 24, 9),
        dueDate: DateTime(2026, 11, 23),
        customerId: 'c1',
        customerName: 'Awa',
        customerPhoneNumber: '+243995656451',
        items: const [
          SaleItem(
            productId: 'p1',
            productName: 'Riz',
            quantity: 2,
            unitPrice: 5000,
            totalPrice: 10000,
            unitPriceInCdf: 5000,
            totalPriceInCdf: 10000,
          ),
        ],
        totalAmountInCdf: 9000,
        amountHT: 7758.62,
        taxAmount: 1241.38,
        paidAmountInCdf: 0,
        paymentMethod: method,
        paymentReference: 'MP241024.1200.A1',
        status: SaleStatus.pending,
        discountPercentage: 10,
        businessUnitId: 'bu-gombe',
        businessUnitCode: 'POS-GOMBE',
        businessUnitType: BusinessUnitType.pos,
        notes: 'note',
      );

  group('addSale propage toute la vente', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('sales_add');
      Hive.init(dir.path);
      await initializeHiveAdapters();
    });
    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('échéance, référence, TVA, HT, remise et unité conservées', () async {
      final repo = SalesRepository();
      await repo.init();
      final saved = await repo.addSale(vente());
      expect(saved.id, isNotEmpty);
      expect(saved.localId, saved.id);
      expect(saved.syncStatus, 'pending');
      expect(saved.dueDate, DateTime(2026, 11, 23));
      expect(saved.paymentReference, 'MP241024.1200.A1');
      expect(saved.taxAmount, 1241.38);
      expect(saved.amountHT, 7758.62);
      expect(saved.discountPercentage, 10);
      expect(saved.businessUnitId, 'bu-gombe');
      expect(saved.businessUnitCode, 'POS-GOMBE');
      expect(saved.customerPhoneNumber, '+243995656451');
      final relu = await repo.getSaleById(saved.id);
      expect(relu?.businessUnitId, 'bu-gombe');
      expect(relu?.dueDate, DateTime(2026, 11, 23));
    });
  });

  group('moyens de paiement en code canonique', () {
    test('anciens libellés normalisés', () {
      expect(paymentMethodCode('Espèces'), 'cash');
      expect(paymentMethodCode('Espèce'), 'cash');
      expect(paymentMethodCode('Crédit'), 'credit');
      expect(paymentMethodCode('Mobile Money'), 'mobile_money');
      expect(paymentMethodCode('Carte bancaire'), 'card');
      expect(paymentMethodCode('Virement bancaire'), 'bank_transfer');
      expect(paymentMethodCode('Chèque'), 'check');
      expect(paymentMethodCode('N/A'), 'cash');
      expect(paymentMethodCode('mobile_money'), 'mobile_money');
      expect(paymentMethodLabel('credit'), 'Crédit');
      expect(paymentMethodLabel('cash'), 'Espèces');
    });

    test('le corps de vente porte le code et les totaux', () {
      final dto = saleToApiDto(vente(method: 'Crédit'), sourceMode: 'retail');
      expect(dto['paymentMethod'], 'credit');
      expect(dto['discountPercentage'], 10);
      expect(dto['totalAmountInCdf'], 9000);
      expect(dto['taxAmount'], 1241.38);
      expect(dto['amountHT'], 7758.62);
      expect(dto['dueDate'], startsWith('2026-11-23'));
      expect(dto['paymentReference'], 'MP241024.1200.A1');
      expect(dto['businessUnitId'], 'bu-gombe');
    });

    test('un règlement part en code', () {
      final draft = PaymentDraft(
        amount: 10,
        currencyCode: 'CDF',
        method: 'Espèces',
        paidAt: DateTime(2026, 10, 24),
      );
      expect(draft.toRequestBody()['method'], 'cash');
    });

    test('Mobile Money exige opérateur et référence, crédit une échéance', () {
      expect(
        paymentDetailsError(method: 'mobile_money', reference: 'X'),
        isNotNull,
      );
      expect(
        paymentDetailsError(
          method: 'mobile_money',
          operator: OperatorBrand.mpesa,
          reference: '  ',
        ),
        isNotNull,
      );
      expect(
        paymentDetailsError(
          method: 'mobile_money',
          operator: OperatorBrand.afrimoney,
          reference: 'REF1',
        ),
        isNull,
      );
      expect(paymentDetailsError(method: 'credit'), isNotNull);
      expect(
        paymentDetailsError(method: 'credit', dueDate: DateTime(2026, 11, 1)),
        isNull,
      );
      expect(paymentDetailsError(method: 'cash'), isNull);
      final d = defaultCreditDueDate(DateTime(2026, 10, 24, 15));
      expect(d, DateTime(2026, 11, 23));
    });
  });

  group('réimpression : unité de la vente', () {
    const courant = BusinessContext(
      companyId: 'co',
      companyName: 'Goutte',
      businessUnitId: 'bu-courante',
      businessUnitName: 'Limete',
      businessUnitAddress: 'Av. Limete',
      scope: 'unit',
    );

    test('même unité : contexte courant', () {
      expect(issuerContextForUnit(courant, 'bu-courante'), same(courant));
      expect(issuerContextForUnit(courant, null), same(courant));
    });

    test('autre unité connue : ses nom et adresse', () {
      final ctx = issuerContextForUnit(
        courant,
        'bu-gombe',
        lookup: (id) => const IssuerUnit(name: 'Gombe', address: 'Bd du 30 Juin'),
      );
      expect(ctx?.businessUnitName, 'Gombe');
      expect(ctx?.businessUnitAddress, 'Bd du 30 Juin');
      final issuer = DocumentIssuer.resolve(companyName: 'Goutte', context: ctx);
      expect(issuer.unitName, 'Gombe');
      expect(issuer.address, 'Bd du 30 Juin');
    });

    test('autre unité inconnue : entreprise, jamais l\'unité courante', () {
      final ctx = issuerContextForUnit(courant, 'bu-inconnue');
      final issuer = DocumentIssuer.resolve(
        companyName: 'Goutte',
        companyAddress: 'Siège',
        context: ctx,
      );
      expect(issuer.unitName, isEmpty);
      expect(issuer.address, 'Siège');
    });
  });
}
