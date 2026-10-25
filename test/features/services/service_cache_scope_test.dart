import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:wanzo/features/services/models/service_item.dart';
import 'package:wanzo/features/services/repositories/service_repository.dart';

ServiceItem _s(String id, String? metier) =>
    ServiceItem(id: id, name: id, priceTiers: const [], metier: metier);

void main() {
  setUpAll(() => Hive.init('${Directory.systemTemp.path}/wanzo_desk_test_services'));

  test('la relecture d un metier ne vide que sa portion, jamais sur reponse vide', () async {
    final repo = ServiceRepository();
    for (final s in await repo.loadAll()) {
      await repo.delete(s.id);
    }
    await repo.upsert(_s('garage-1', 'garage'));
    await repo.upsert(_s('couture-1', 'couture'));

    bool garage(ServiceItem s) => s.metier == 'garage';

    // Réponse vide : rien n'est purgé.
    await repo.replaceFromServer(const [], inScope: garage);
    expect((await repo.loadAll()).map((s) => s.id), containsAll(['garage-1', 'couture-1']));

    // Relecture du garage : la couture reste intacte.
    await repo.replaceFromServer([_s('garage-2', 'garage')], inScope: garage);
    final ids = (await repo.loadAll()).map((s) => s.id).toSet();
    expect(ids, containsAll(['garage-2', 'couture-1']));
    expect(ids, isNot(contains('garage-1')));
  });
}
