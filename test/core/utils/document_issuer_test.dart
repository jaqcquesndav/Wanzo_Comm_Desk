import 'package:flutter_test/flutter_test.dart';
import 'package:wanzo/core/services/business_context_service.dart';
import 'package:wanzo/core/utils/document_issuer.dart';

void main() {
  const siege = (
    name: 'GOUTTE SARL',
    address: 'Av. Karisimbi 24, Q. Les Volcans, Com. Goma',
    phone: '0995656451',
  );

  DocumentIssuer issuer({BusinessContext? ctx, String? address, String? phone}) =>
      DocumentIssuer.resolve(
        companyName: siege.name,
        companyAddress: address ?? siege.address,
        companyPhone: phone ?? siege.phone,
        companyRccm: 'CD/GOM/RCCM/24-B-00123',
        companyIdNat: '19-H5300-N12345K',
        companyTaxId: 'A1234567B',
        context: ctx,
      );

  group('En-tête au siège', () {
    test('raison sociale, adresse, téléphone avec indicatif puis RCCM, Id. Nat., NIF', () {
      final i = issuer();
      expect(i.name, 'GOUTTE SARL');
      expect(i.detailLines, [
        'Av. Karisimbi 24, Q. Les Volcans, Com. Goma',
        'Tél. +243 995 656 451',
        'RCCM : CD/GOM/RCCM/24-B-00123',
        'Id. Nat. : 19-H5300-N12345K',
        'NIF : A1234567B',
      ]);
    });

    test('niveau entreprise : aucune ligne d\'unité', () {
      final i = issuer(
        ctx: const BusinessContext(
          businessUnitId: 'racine',
          businessUnitName: 'Magasin principal',
          scope: 'company',
        ),
      );
      expect(i.unitName, isEmpty);
    });
  });

  group('Unité d\'affaires (quel que soit son type ou son activité)', () {
    test('BU d\'activité sans adresse propre : nom de la BU, coordonnées du siège', () {
      final i = issuer(
        ctx: const BusinessContext(
          businessUnitId: 'resto',
          businessUnitName: 'Restaurant Le Jardin',
          scope: 'unit',
        ),
      );
      expect(i.name, 'GOUTTE SARL');
      expect(i.unitName, 'Restaurant Le Jardin');
      expect(i.address, siege.address);
      expect(i.phone, '+243 995 656 451');
    });

    test('BU avec un téléphone propre seulement : son téléphone, adresse du siège', () {
      final i = issuer(
        ctx: const BusinessContext(
          businessUnitId: 'conciergerie',
          businessUnitName: 'Conciergerie',
          businessUnitPhone: '+243 812 345 678',
          scope: 'unit',
        ),
      );
      expect(i.phone, '+243 812 345 678');
      expect(i.address, siege.address);
    });

    test('BU enfant d\'une BU : coordonnées résolues sur la parente par le serveur', () {
      // /auth/me renvoie documentAddress = adresse de la BU parente.
      final i = issuer(
        ctx: const BusinessContext(
          businessUnitId: 'pv-kivu',
          businessUnitName: 'Point de vente Kivu',
          businessUnitAddress: 'Rue Kinshasa 20, Butembo',
          scope: 'unit',
        ),
      );
      expect(i.unitName, 'Point de vente Kivu');
      expect(i.address, 'Rue Kinshasa 20, Butembo');
      expect(i.phone, '+243 995 656 451');
      // Identifiants légaux : ceux de l'entreprise.
      expect(i.rccm, 'CD/GOM/RCCM/24-B-00123');
    });

    test('nom de BU identique à la raison sociale : pas répété', () {
      final i = issuer(
        ctx: const BusinessContext(
          businessUnitId: 'u',
          businessUnitName: 'goutte sarl',
          scope: 'unit',
        ),
      );
      expect(i.unitName, isEmpty);
    });

    test('BU personne morale : ses propres identifiants', () {
      final i = issuer(
        ctx: const BusinessContext(
          businessUnitId: 'coop',
          businessUnitName: 'Coopérant SARL',
          businessUnitIsLegalEntity: true,
          businessUnitRccm: 'RCCM-COOP',
          scope: 'unit',
        ),
      );
      expect(i.name, 'Coopérant SARL');
      expect(i.rccm, 'RCCM-COOP');
      expect(i.taxId, 'A1234567B'); // repli entreprise
    });
  });

  group('Champs vides : rien d\'affiché', () {
    test('ni « null », ni valeur d\'attente, ni libellé GPS', () {
      final i = DocumentIssuer.resolve(
        companyName: 'X',
        companyAddress: 'Position GPS en temps réel (précision: 20m)',
        companyPhone: '+243 000 000 000',
      );
      expect(i.detailLines, isEmpty);
      expect(cleanAddress('null'), '');
      expect(cleanAddress('{"city":"Kinshasa","province":"Kinshasa"}'), 'Kinshasa');
      expect(cleanAddress('Rue kin nº148\nen face de CBCA'), 'Rue kin nº148, en face de CBCA');
    });
  });

  group('Téléphone avec indicatif', () {
    test('formes courantes', () {
      expect(formatPhone('0812345678'), '+243 812 345 678');
      expect(formatPhone('+2439957483'), '+2439957483'); // incomplet : tel quel
      expect(formatPhone('+243 0997483000'), '+243 997 483 000');
      expect(formatPhone('0979588462 / 0812345678'), '+243 979 588 462 / +243 812 345 678');
      expect(formatPhone('+250788123456'), '+250788123456');
      expect(formatPhone(null), '');
    });
  });

  group('Ticket 58 mm et 80 mm', () {
    const longue =
        'VILLE DE BUTEMBO, COMM. MUSUSA, Q. VUNGI, RUE KINSHASA, N° 14, en face de la CBCA';

    for (final width in [32, 48]) {
      test('adresse longue repliée sans couper un mot ($width car.)', () {
        final lines = wrapWords(longue, width);
        expect(lines.every((l) => l.length <= width), isTrue);
        final mots = longue.split(RegExp(r'[ ]+'));
        final rendus = lines.join(' ').split(RegExp(r'[ ]+'));
        expect(rendus, mots);
      });
    }

    test('adresse sans espace : coupe aux virgules', () {
      final lines = wrapWords('Butembo,com.Mususa,Rue Kinshasa, Bâtiment MUKEMBA nº20', 32);
      expect(lines.first, 'Butembo,com.Mususa,Rue Kinshasa,');
      expect(lines.every((l) => l.length <= 32), isTrue);
    });

    test('lignes du ticket : raison sociale en majuscules puis détails', () {
      final lines = issuer().ticketLines(32);
      expect(lines.first, 'GOUTTE SARL');
      expect(lines, contains('Tél. +243 995 656 451'));
      expect(lines.every((l) => l.length <= 32), isTrue);
    });
  });
}
