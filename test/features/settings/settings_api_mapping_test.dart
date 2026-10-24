import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/features/settings/models/settings.dart';
import 'package:wanzo/features/settings/repositories/settings_repository.dart';

/// Profil entreprise reçu de GET settings-user-profile/application-settings.
void main() {
  test('adresse, téléphone et identifiants légaux mappés depuis l\'API', () {
    final s = SettingsRepository.mapApiOnto(const Settings(), {
      'companyName': 'GOUTTE SARL',
      'companyAddress': 'Av. Karisimbi 24, Q. Les Volcans, Com. Goma',
      'contactPhone': '+243 995 656 451',
      'registrationNumber': 'CD/GOM/RCCM/24-B-00123',
      'nationalId': '19-H5300-N12345K',
      'taxId': 'A1234567B',
    });
    expect(s.companyAddress, 'Av. Karisimbi 24, Q. Les Volcans, Com. Goma');
    expect(s.companyPhone, '+243 995 656 451');
    expect(s.rccmNumber, 'CD/GOM/RCCM/24-B-00123');
    expect(s.idNatNumber, '19-H5300-N12345K');
    expect(s.taxIdentificationNumber, 'A1234567B');
  });

  test('valeur d\'attente ou champ absent : le dernier profil connu reste', () {
    const local = Settings(
      companyAddress: 'Rue Kinshasa 20, Butembo',
      companyPhone: '0812345678',
    );
    final s = SettingsRepository.mapApiOnto(local, {
      'contactPhone': '+243 000 000 000',
    });
    expect(s.companyPhone, '0812345678');
    expect(s.companyAddress, 'Rue Kinshasa 20, Butembo');
  });

  test('adresse multiligne ou objet sérialisé : une ligne lisible', () {
    final s = SettingsRepository.mapApiOnto(const Settings(), {
      'companyAddress': '{"city":"Butembo","province":"Nord-Kivu"}',
    });
    expect(s.companyAddress, 'Butembo, Nord-Kivu');
    final t = SettingsRepository.mapApiOnto(const Settings(), {
      'companyAddress': {'street': 'Av. du Lac 3'},
    });
    expect(t.companyAddress, 'Av. du Lac 3');
  });

  test('modification dans Wanzo Land : la nouvelle adresse remplace l\'ancienne', () {
    const local = Settings(companyAddress: 'Ancienne adresse');
    final s = SettingsRepository.mapApiOnto(local, {
      'companyAddress': 'Nouvelle adresse, Goma',
    });
    expect(s.companyAddress, 'Nouvelle adresse, Goma');
  });
}
