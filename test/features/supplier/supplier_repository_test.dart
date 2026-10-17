import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:wanzo/core/enums/business_unit_enums.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/features/supplier/models/supplier.dart';
import 'package:wanzo/features/supplier/repositories/supplier_repository.dart';
import 'package:wanzo/features/supplier/services/supplier_api_service.dart';

class _Appel {
  final String methode;
  final String chemin;
  final dynamic corps;
  final Map<Symbol, dynamic> options;
  _Appel(this.methode, this.chemin, this.corps, this.options);
}

class _ClientFactice implements ApiClient {
  final List<_Appel> appels = [];
  dynamic Function(_Appel appel) repondre = (_) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    const methodes = {
      #get: 'GET',
      #post: 'POST',
      #patch: 'PATCH',
      #put: 'PUT',
      #delete: 'DELETE',
    };
    final nom = invocation.memberName;
    if (!methodes.containsKey(nom)) return super.noSuchMethod(invocation);
    final appel = _Appel(
      methodes[nom]!,
      invocation.positionalArguments.first as String,
      invocation.namedArguments[#body],
      invocation.namedArguments,
    );
    appels.add(appel);
    return Future<dynamic>(() => repondre(appel));
  }
}

Supplier _fournisseur() => Supplier(
      id: '',
      name: 'Kivu Distribution SARL',
      phoneNumber: '+243990000001',
      email: '',
      address: '',
      contactPerson: 'Marie',
      createdAt: DateTime(2026, 10, 17),
    );

void main() {
  late Directory dossier;
  late _ClientFactice http;
  late SupplierRepository repo;

  setUpAll(() {
    if (!Hive.isAdapterRegistered(38)) Hive.registerAdapter(SupplierAdapter());
    if (!Hive.isAdapterRegistered(39)) {
      Hive.registerAdapter(SupplierCategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(71)) {
      Hive.registerAdapter(BusinessUnitTypeAdapter());
    }
  });

  setUp(() async {
    dossier = await Directory.systemTemp.createTemp('wanzo_fournisseur_');
    Hive.init(dossier.path);
    http = _ClientFactice();
    repo = SupplierRepository(apiService: SupplierApiServiceImpl(http));
    await repo.init();
  });

  tearDown(() async {
    await Hive.close();
    await dossier.delete(recursive: true);
  });

  test('création : pas de chaîne vide, pas de file hors ligne', () async {
    http.repondre = (a) => {
          'success': true,
          'data': {
            ...(a.corps as Map<String, dynamic>),
            'id': 'srv-1',
            'createdAt': '2026-10-17T10:00:00.000Z',
          },
        };
    final cree = await repo.addSupplier(_fournisseur());
    final post = http.appels.single;
    expect(post.chemin, 'suppliers');
    expect(post.options[#queueOffline], isFalse);
    final corps = post.corps as Map<String, dynamic>;
    expect(corps.containsKey('email'), isFalse, reason: '$corps');
    expect(corps.containsKey('address'), isFalse);
    expect(corps['contactPerson'], 'Marie');
    expect(cree.id, 'srv-1');
    expect(cree.syncStatus, 'synced');
  });

  test('refus du serveur : erreur lisible, rien de gardé', () async {
    http.repondre = (_) => throw BadRequestException(
          'phoneNumber must be a valid phone number',
        );
    await expectLater(
      repo.addSupplier(_fournisseur()),
      throwsA(isA<SupplierRefusedException>()),
    );
    expect(await repo.getSuppliers(), isEmpty);
  });

  test('hors ligne : gardé « pending » pour la synchronisation', () async {
    http.repondre = (_) => throw NetworkException('hors ligne');
    final local = await repo.addSupplier(_fournisseur());
    expect(local.syncStatus, 'pending');
    expect(Hive.box<Supplier>('suppliersBox').get(local.id)?.syncStatus,
        'pending');
  });

  test('suppression refusée (historique) : fiche conservée', () async {
    http.repondre = (_) => throw NetworkException('hors ligne');
    final local = await repo.addSupplier(_fournisseur());
    http.repondre = (_) => throw ConflictTestException();
    await expectLater(repo.deleteSupplier(local.id), throwsA(isA<Exception>()));
    expect(Hive.box<Supplier>('suppliersBox').get(local.id), isNotNull);
  });
}

/// Refus 409 du serveur (fournisseur avec historique).
class ConflictTestException extends ApiException {
  ConflictTestException()
      : super('Fournisseur lié à des dépenses', statusCode: 409);
}
