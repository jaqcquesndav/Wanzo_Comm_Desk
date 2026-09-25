import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/features/salon/models/salon_service.dart';
import 'package:wanzo/features/salon/repositories/salon_service_repository.dart';
import 'package:wanzo/features/salon/services/salon_api_service.dart';

/// Serveur factice des prestations, avec simulation d'absence de réseau.
class _ServeurFactice extends SalonApiService {
  final Map<String, SalonService> carte = {};
  bool horsLigne = false;

  @override
  Future<List<SalonService>> getServices() async {
    if (horsLigne) throw NetworkException('hors ligne', endpoint: 'salon');
    return carte.values.toList();
  }

  @override
  Future<void> bulkUpsertServices(List<SalonService> services) async {
    if (horsLigne) throw OfflineQueuedException(endpoint: 'salon');
    for (final s in services) {
      carte[s.id] = s;
    }
  }

  @override
  Future<void> deleteService(String id) async {
    if (horsLigne) throw OfflineQueuedException(endpoint: 'salon');
    if (carte.remove(id) == null) {
      throw NotFoundException('absent', endpoint: 'salon');
    }
  }
}

SalonService _presta(String id, String nom) => SalonService(
    id: id, name: nom, category: SalonServiceCategory.homme, priceCdf: 5000);

void main() {
  late Directory dossier;
  late _ServeurFactice serveur;
  late SalonServiceRepository repo;

  setUpAll(() => dotenv.testLoad(fileInput: ''));

  setUp(() async {
    dossier = await Directory.systemTemp.createTemp('salon_');
    Hive.init(dossier.path);
    serveur = _ServeurFactice();
    repo = SalonServiceRepository(api: serveur);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    await dossier.delete(recursive: true);
  });

  test('une prestation ajoutée part aussitôt au serveur', () async {
    await repo.upsert(_presta('a', 'Coupe'));
    expect(serveur.carte.keys, contains('a'));
  });

  test('non publiée, elle survit au chargement suivant '
      '(l\'ancien remplacement intégral l\'effaçait)', () async {
    serveur.carte['vieux'] = _presta('vieux', 'Tresses');
    serveur.horsLigne = true;
    await repo.upsert(_presta('neuf', 'Défrisage'));
    serveur.horsLigne = false;

    final carte = await repo.loadAllSynced();
    expect(carte.map((s) => s.id).toSet(), {'vieux', 'neuf'});
    expect(serveur.carte.keys, contains('neuf'));
  });

  test('une prestation supprimée ne revient pas', () async {
    await repo.upsert(_presta('a', 'Coupe'));
    await repo.upsert(_presta('b', 'Barbe'));
    serveur.horsLigne = true;
    await repo.delete('a');
    serveur.horsLigne = false;

    final carte = await repo.loadAllSynced();
    expect(carte.map((s) => s.id), ['b']);
    expect(serveur.carte.keys, isNot(contains('a')));
  });

  test('installation neuve : la carte du serveur redescend', () async {
    serveur.carte['a'] = _presta('a', 'Coupe');
    final carte = await repo.loadAllSynced();
    expect(carte.map((s) => s.id), ['a']);
  });
}
