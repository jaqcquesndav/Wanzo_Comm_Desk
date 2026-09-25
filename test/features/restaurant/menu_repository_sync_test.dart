import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:wanzo/core/exceptions/api_exceptions.dart';
import 'package:wanzo/features/restaurant/models/menu_course.dart';
import 'package:wanzo/features/restaurant/models/menu_item.dart';
import 'package:wanzo/features/restaurant/repositories/menu_repository.dart';
import 'package:wanzo/features/restaurant/services/restaurant_api_service.dart';

/// Serveur factice : il garde la carte en mémoire, et peut simuler l'absence
/// de réseau (les écritures sont alors mises en file, comme le fait ApiClient).
class _ServeurFactice extends RestaurantApiService {
  final Map<String, MenuItem> carte = {};
  bool horsLigne = false;

  @override
  Future<List<MenuItem>> getMenuItems() async {
    if (horsLigne) throw NetworkException('hors ligne', endpoint: 'menu');
    return carte.values.toList();
  }

  @override
  Future<void> upsertMenuItem(MenuItem item, int position) async {
    if (horsLigne) throw OfflineQueuedException(endpoint: 'menu');
    carte[item.id] = item;
  }

  @override
  Future<void> deleteMenuItem(String id) async {
    if (horsLigne) throw OfflineQueuedException(endpoint: 'menu');
    if (carte.remove(id) == null) {
      throw NotFoundException('absent', endpoint: 'menu');
    }
  }
}

MenuItem _plat(String id, String nom) =>
    MenuItem(id: id, name: nom, priceCdf: 1000, course: MenuCourse.plat);

void main() {
  late Directory dossier;
  late _ServeurFactice serveur;
  late MenuRepository repo;

  setUpAll(() {
    // Le client HTTP lit sa configuration au demarrage ; vide ici, le serveur
    // factice ne fait aucun appel reseau.
    dotenv.testLoad(fileInput: '');
  });

  setUp(() async {
    dossier = await Directory.systemTemp.createTemp('carte_');
    Hive.init(dossier.path);
    serveur = _ServeurFactice();
    repo = MenuRepository(api: serveur);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    await dossier.delete(recursive: true);
  });

  test('un plat ajouté part aussitôt au serveur', () async {
    await repo.upsert(_plat('a', 'Poulet mayo'));
    expect(serveur.carte.keys, contains('a'));
  });

  test('ajouté hors ligne, il part à la synchronisation suivante', () async {
    serveur.horsLigne = true;
    await repo.upsert(_plat('a', 'Poulet mayo'));
    expect(serveur.carte, isEmpty);

    serveur.horsLigne = false;
    final carte = await repo.loadAllSynced();
    expect(serveur.carte.keys, contains('a'));
    expect(carte.map((p) => p.id), contains('a'));
  });

  test('un plat supprimé ne revient pas, et disparaît du serveur', () async {
    await repo.upsert(_plat('a', 'Poulet mayo'));
    await repo.upsert(_plat('b', 'Liboke'));
    await repo.delete('a');

    expect(serveur.carte.keys, isNot(contains('a')));
    final carte = await repo.loadAllSynced();
    expect(carte.map((p) => p.id), ['b']);
  });

  test('supprimé hors ligne, il ne revient pas avant la confirmation', () async {
    await repo.upsert(_plat('a', 'Poulet mayo'));
    await repo.upsert(_plat('b', 'Liboke'));
    serveur.horsLigne = true;
    await repo.delete('a');

    serveur.horsLigne = false;
    final carte = await repo.loadAllSynced();
    expect(carte.map((p) => p.id), ['b']);
    expect(serveur.carte.keys, isNot(contains('a')));
  });

  test('installation neuve : la carte du serveur redescend', () async {
    serveur.carte['a'] = _plat('a', 'Poulet mayo');
    serveur.carte['b'] = _plat('b', 'Liboke');
    final carte = await repo.loadAllSynced();
    expect(carte.map((p) => p.id).toSet(), {'a', 'b'});
  });

  test('plats jamais publiés d\'une ancienne version : ils sont envoyés, '
      'pas effacés', () async {
    // Ancienne version : plats écrits en local seulement, jamais publiés.
    final ancienne = await Hive.openBox<String>('restaurant_menu_items');
    await ancienne.put(
        'x', '{"id":"x","name":"Pondu","priceCdf":500,"course":"plat"}');
    serveur.carte['vieux'] = _plat('vieux', 'Ancien plat publié');

    final carte = await repo.loadAllSynced();
    expect(serveur.carte.keys, contains('x'));
    expect(carte.map((p) => p.id).toSet(), {'x', 'vieux'});
  });

  test('une réponse vide du serveur n\'efface pas la carte locale', () async {
    await repo.upsert(_plat('a', 'Poulet mayo'));
    serveur.carte.clear(); // réponse vide accidentelle
    final carte = await repo.loadAllSynced();
    expect(carte.map((p) => p.id), contains('a'));
  });
}
