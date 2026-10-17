import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:wanzo/core/enums/business_unit_enums.dart';
import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/core/services/api_client.dart';
import 'package:wanzo/features/customer/bloc/customer_bloc.dart';
import 'package:wanzo/features/customer/bloc/customer_event.dart';
import 'package:wanzo/features/customer/bloc/customer_state.dart';
import 'package:wanzo/features/customer/models/customer.dart';
import 'package:wanzo/features/customer/repositories/customer_repository.dart';
import 'package:wanzo/features/customer/services/customer_api_service.dart';

/// Un appel HTTP enregistré par le client factice.
class _Appel {
  final String methode;
  final String chemin;
  final dynamic corps;
  final Map<Symbol, dynamic> options;
  _Appel(this.methode, this.chemin, this.corps, this.options);
}

/// Client HTTP factice : enregistre chaque appel et répond selon [repondre].
/// Passe par noSuchMethod pour ne pas dépendre de la signature exacte
/// (paramètres nommés) des méthodes d'ApiClient.
class _ClientFactice implements ApiClient {
  final List<_Appel> appels = [];
  dynamic Function(_Appel appel) repondre = (_) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final nom = invocation.memberName;
    const methodes = {#get: 'GET', #post: 'POST', #patch: 'PATCH', #put: 'PUT', #delete: 'DELETE'};
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

Map<String, dynamic> _clientServeur(Map<String, dynamic> corps, {String id = 'srv-1'}) => {
      ...corps,
      'id': id,
      'createdAt': '2026-10-17T10:00:00.000Z',
      'totalPurchases': 0,
      'category': 'regular',
    };

Customer _personneMorale() => Customer(
      id: '',
      name: 'Kivu Distribution SARL',
      phoneNumber: '+243 990 000 001',
      email: '',
      address: '',
      notes: null,
      createdAt: DateTime(2026, 10, 17),
      totalPurchases: 1250000,
      customerType: CustomerType.company.apiValue,
      taxId: 'CD/KIN/RCCM/24-B-01234',
      profilePicture: r'C:\Users\poste\Pictures\logo.png',
      contacts: const [
        CustomerContact(name: 'Marie Kabila', role: 'Comptable', phone: '+243 811 111 111', email: ''),
        CustomerContact(name: ''),
      ],
    );

void main() {
  late Directory dossier;
  late _ClientFactice http;
  late CustomerRepository repo;

  setUpAll(() {
    if (!Hive.isAdapterRegistered(35)) Hive.registerAdapter(CustomerAdapter());
    if (!Hive.isAdapterRegistered(36)) Hive.registerAdapter(CustomerCategoryAdapter());
    if (!Hive.isAdapterRegistered(205)) Hive.registerAdapter(CustomerContactAdapter());
  });

  setUp(() async {
    dossier = await Directory.systemTemp.createTemp('clients_api_');
    Hive.init(dossier.path);
    http = _ClientFactice();
    repo = CustomerRepository(apiService: CustomerApiService(apiClient: http));
    await repo.init();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    await dossier.delete(recursive: true);
  });

  group('Création d\'un client personne morale', () {
    test('corps envoyé : nature, NIF, contacts, sans chaîne vide ni photo locale', () async {
      http.repondre = (a) => {'data': _clientServeur(a.corps as Map<String, dynamic>)};

      final cree = await repo.addCustomer(_personneMorale());

      final post = http.appels.single;
      expect(post.methode, 'POST');
      expect(post.chemin, 'customers');
      // Le client a sa propre reprise hors ligne : pas de file HTTP en double.
      expect(post.options[#queueOffline], isFalse);

      final corps = post.corps as Map<String, dynamic>;
      expect(corps['fullName'], 'Kivu Distribution SARL');
      expect(corps['customerType'], 'company');
      expect(corps['taxId'], 'CD/KIN/RCCM/24-B-01234');
      // @IsOptional ne saute pas '' : jamais de chaîne vide envoyée.
      expect(corps.containsKey('email'), isFalse);
      expect(corps.containsKey('address'), isFalse);
      expect(corps.containsKey('notes'), isFalse);
      // Photo locale (chemin disque) : le DTO exige une URL.
      expect(corps.containsKey('profilePicture'), isFalse);
      // Cumul d'achats tenu par le serveur.
      expect(corps.containsKey('totalPurchases'), isFalse);
      // Contact sans nom retiré, email vide du contact omis.
      expect(corps['contacts'], [
        {'name': 'Marie Kabila', 'role': 'Comptable', 'phone': '+243 811 111 111'},
      ]);

      // Réponse lue : id serveur, contacts relus, photo locale conservée.
      expect(cree.id, 'srv-1');
      expect(cree.type, CustomerType.company);
      expect(cree.contacts.single.name, 'Marie Kabila');
      expect(cree.profilePicture, r'C:\Users\poste\Pictures\logo.png');
      expect(cree.syncStatus, 'synced');
    });

    test('refus du serveur (400) : erreur remontée, rien enregistré en local', () async {
      http.repondre = (_) => throw BadRequestException('fullName must be a string', endpoint: 'customers');

      await expectLater(
        repo.addCustomer(_personneMorale()),
        throwsA(isA<Exception>().having((e) => '$e', 'message', contains('fullName'))),
      );
      expect(await repo.getCustomers(forceLocal: true), isEmpty);
    });

    test('hors ligne : conservé en « pending » pour la synchro', () async {
      http.repondre = (_) => throw NetworkException('hors ligne', endpoint: 'customers');

      final local = await repo.addCustomer(_personneMorale());

      expect(local.syncStatus, 'pending');
      final enCache = await repo.getCustomers(forceLocal: true);
      expect(enCache.single.name, 'Kivu Distribution SARL');
    });
  });

  group('Unité d\'affaires', () {
    test('businessUnitType envoyé en minuscules (enum du DTO)', () {
      final corps = _personneMorale()
          .copyWith(businessUnitType: BusinessUnitType.pos, businessUnitCode: 'POS-001')
          .toApiJson();
      expect(corps['businessUnitType'], 'pos');
      expect(corps['businessUnitCode'], 'POS-001');
    });
  });

  group('Modification', () {
    test('PATCH, email effacé envoyé vide, cumul jamais renvoyé', () async {
      http.repondre = (a) {
        if (a.methode == 'POST') return {'data': _clientServeur(a.corps as Map<String, dynamic>)};
        return {'data': _clientServeur(a.corps as Map<String, dynamic>, id: 'srv-1')};
      };
      final cree = await repo.addCustomer(_personneMorale().copyWith(email: 'compta@kivu.cd'));

      await repo.updateCustomer(cree.copyWith(email: '', totalPurchases: 99));

      final patch = http.appels.last;
      expect(patch.methode, 'PATCH');
      expect(patch.chemin, 'customers/srv-1');
      final corps = patch.corps as Map<String, dynamic>;
      expect(corps['email'], '');
      expect(corps.containsKey('totalPurchases'), isFalse);
    });
  });

  group('Suppression', () {
    Future<Customer> enregistrer() async {
      http.repondre = (a) => {'data': _clientServeur(a.corps as Map<String, dynamic>)};
      return repo.addCustomer(_personneMorale());
    }

    test('refusée par le serveur (historique) : erreur affichée, fiche gardée', () async {
      final client = await enregistrer();
      http.repondre = (a) {
        if (a.methode == 'DELETE') {
          throw ServerException(
            'Ce client a 3 vente(s) : il ne peut pas être supprimé, son historique serait perdu.',
            statusCode: 409,
            endpoint: a.chemin,
          );
        }
        return null;
      };

      await expectLater(
        repo.deleteCustomer(client.id),
        throwsA(isA<Exception>().having((e) => '$e', 'message', contains('3 vente(s)'))),
      );
      final delete = http.appels.last;
      expect(delete.methode, 'DELETE');
      // Jamais mise en file pour être rejouée à l'insu de l'utilisateur.
      expect(delete.options[#queueOffline], isFalse);
      expect((await repo.getCustomers(forceLocal: true)).map((c) => c.id), contains(client.id));
    });

    test('bloc : le refus est affiché puis la liste revient', () async {
      final client = await enregistrer();
      http.repondre = (a) {
        if (a.methode == 'DELETE') {
          throw ServerException('Ce client a 1 vente(s).', statusCode: 409, endpoint: a.chemin);
        }
        // Liste : le serveur renvoie toujours la fiche.
        return {
          'data': {
            'customers': [_clientServeur({'fullName': client.name, 'phoneNumber': client.phoneNumber})],
            'total': 1,
          },
        };
      };
      final bloc = CustomerBloc(customerRepository: repo);
      final etats = <CustomerState>[];
      final abonnement = bloc.stream.listen(etats.add);

      bloc.add(DeleteCustomer(client.id));
      await bloc.stream
          .firstWhere((s) => s is CustomersLoaded)
          .timeout(const Duration(seconds: 10));

      expect(
        etats.whereType<CustomerError>().single.message,
        contains('1 vente(s)'),
      );
      expect(etats.last, isA<CustomersLoaded>());
      expect((etats.last as CustomersLoaded).customers.map((c) => c.id), contains(client.id));
      await abonnement.cancel();
      await bloc.close();
    });

    test('fiche jamais envoyée (créée hors ligne) : supprimée sans appel', () async {
      http.repondre = (_) => throw NetworkException('hors ligne', endpoint: 'customers');
      final local = await repo.addCustomer(_personneMorale());
      final avant = http.appels.length;

      await repo.deleteCustomer(local.id);

      expect(http.appels.length, avant);
      expect(await repo.getCustomers(forceLocal: true), isEmpty);
    });
  });

  group('Liste', () {
    test('toutes les pages sont lues (le serveur en sert 10 par défaut)', () async {
      http.repondre = (a) {
        final page = int.parse((a.options[#queryParameters] as Map)['page'] as String);
        final taille = page == 1 ? 200 : 5;
        return {
          'data': {
            'customers': [
              for (var i = 0; i < taille; i++)
                _clientServeur({'fullName': 'Client $page-$i', 'phoneNumber': ''}, id: 'c-$page-$i'),
            ],
          },
        };
      };

      final clients = await repo.getCustomers();

      expect(clients.length, 205);
      expect(http.appels.length, 2);
      expect((http.appels.first.options[#queryParameters] as Map)['limit'], '200');
    });
  });
}
