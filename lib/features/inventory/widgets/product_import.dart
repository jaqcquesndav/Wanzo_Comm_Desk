import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/enums/currency_enum.dart';
import '../../../core/services/currency_service.dart';
import '../bloc/inventory_bloc.dart';
import '../bloc/inventory_event.dart';
import '../models/product.dart';
import '../repositories/inventory_repository.dart';

/// Colonnes du modèle d'import, dans l'ordre. Seuls « Nom » et « Prix de
/// vente » sont obligatoires.
const _modele = [
  'Nom',
  'Catégorie',
  'Prix d\'achat',
  'Prix de vente',
  'Devise',
  'Quantité',
  'Unité',
  'Code-barres',
  'Seuil d\'alerte',
  'Description',
];

/// Import d'articles depuis un fichier Excel (.xlsx) ou CSV.
///
/// Chaque ligne devient un article créé exactement comme par le formulaire
/// (même conversion en CDF au taux central, même synchronisation). Un article
/// déjà présent (même nom) est ignoré pour ne pas créer de doublon. Un aperçu
/// liste ce qui sera créé et ce qui est écarté, avec la raison.
Future<void> importerProduits(BuildContext context) async {
  final choix = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['xlsx', 'csv'],
    withData: true,
  );
  final fichier = choix?.files.single;
  if (fichier == null || fichier.bytes == null || !context.mounted) return;

  List<List<String>> lignes;
  try {
    lignes = (fichier.extension ?? '').toLowerCase() == 'xlsx'
        ? _lireXlsx(fichier.bytes!)
        : _lireCsv(fichier.bytes!);
  } catch (e) {
    _message(context, 'Fichier illisible : $e');
    return;
  }
  if (lignes.length < 2) {
    _message(context, 'Le fichier ne contient aucun article (une ligne d\'en-tête puis une ligne par article).');
    return;
  }

  final repo = context.read<InventoryRepository>();
  final devises = context.read<CurrencyService>();
  final existants = repo.getAllProducts().map((p) => _cle(p.name)).toSet();
  final analyse = _analyser(lignes, existants, devises);
  if (!context.mounted) return;

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Importer des articles'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${analyse.produits.length} article(s) prêt(s) à être créé(s).'),
            if (analyse.ecarts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('${analyse.ecarts.length} ligne(s) écartée(s) :',
                  style: Theme.of(ctx).textTheme.titleSmall),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final e in analyse.ecarts)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(e, style: Theme.of(ctx).textTheme.bodySmall),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
        FilledButton(
          onPressed: analyse.produits.isEmpty ? null : () => Navigator.pop(ctx, true),
          child: Text('Créer ${analyse.produits.length} article(s)'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  var crees = 0;
  final echecs = <String>[];
  for (final p in analyse.produits) {
    try {
      await repo.addProduct(p);
      crees++;
    } catch (e) {
      echecs.add(p.name);
    }
  }
  if (!context.mounted) return;
  context.read<InventoryBloc>().add(const LoadProducts());
  _message(
    context,
    echecs.isEmpty
        ? '$crees article(s) importé(s).'
        : '$crees article(s) importé(s), échec pour : ${echecs.join(', ')}.',
  );
}

/// Enregistre le modèle CSV à remplir (en-têtes et une ligne d'exemple).
Future<void> telechargerModeleImport(BuildContext context) async {
  final contenu = const ListToCsvConverter().convert([
    _modele,
    ['Clavier sans fil', 'Électronique', '25', '40', 'USD', '5', 'pièce', '', '2', 'Avec souris'],
  ]);
  final octets = Uint8List.fromList(utf8.encode('﻿$contenu'));
  final chemin = await FilePicker.platform.saveFile(
    dialogTitle: 'Enregistrer le modèle d\'import',
    fileName: 'modele_import_articles.csv',
    bytes: octets,
  );
  if (!context.mounted || chemin == null) return;
  _message(context, 'Modèle enregistré. Remplissez-le dans Excel puis importez-le.');
}

class _Analyse {
  final List<Product> produits = [];
  final List<String> ecarts = [];
}

_Analyse _analyser(List<List<String>> lignes, Set<String> existants, CurrencyService devises) {
  final a = _Analyse();
  final entete = lignes.first.map(_cle).toList();
  int col(List<String> noms) => entete.indexWhere((h) => noms.contains(h));
  final iNom = col(['nom', 'name', 'article', 'produit', 'designation']);
  final iCat = col(['categorie', 'category']);
  final iAchat = col(['prix d\'achat', 'prix achat', 'cout', 'cout d\'achat', 'cost']);
  final iVente = col(['prix de vente', 'prix vente', 'prix', 'price']);
  final iDevise = col(['devise', 'monnaie', 'currency']);
  final iQte = col(['quantite', 'stock', 'qte', 'quantity']);
  final iUnite = col(['unite', 'unit']);
  final iCode = col(['code-barres', 'code barres', 'codebarre', 'barcode', 'code']);
  final iSeuil = col(['seuil d\'alerte', 'seuil', 'alerte']);
  final iDesc = col(['description']);
  if (iNom < 0 || iVente < 0) {
    a.ecarts.add('Colonnes « Nom » et « Prix de vente » introuvables. Utilisez le modèle.');
    return a;
  }

  String cellule(List<String> l, int i) => i >= 0 && i < l.length ? l[i].trim() : '';
  double? nombre(String s) =>
      s.isEmpty ? null : double.tryParse(s.replaceAll(RegExp(r'[\s  ]'), '').replaceAll(',', '.'));

  final vus = <String>{};
  final maintenant = DateTime.now();
  for (var n = 1; n < lignes.length; n++) {
    final l = lignes[n];
    if (l.every((c) => c.trim().isEmpty)) continue;
    final ref = 'Ligne ${n + 1}';
    final nom = cellule(l, iNom);
    if (nom.isEmpty) {
      a.ecarts.add('$ref : nom manquant.');
      continue;
    }
    final cle = _cle(nom);
    if (existants.contains(cle)) {
      a.ecarts.add('$ref : « $nom » existe déjà.');
      continue;
    }
    if (!vus.add(cle)) {
      a.ecarts.add('$ref : « $nom » apparaît deux fois dans le fichier.');
      continue;
    }
    final vente = nombre(cellule(l, iVente));
    if (vente == null || vente <= 0) {
      a.ecarts.add('$ref : prix de vente manquant ou invalide.');
      continue;
    }
    final achat = nombre(cellule(l, iAchat)) ?? 0;
    final quantite = nombre(cellule(l, iQte)) ?? 0;
    if (achat < 0 || quantite < 0) {
      a.ecarts.add('$ref : montant ou quantité négatif.');
      continue;
    }
    final codeDevise = cellule(l, iDevise).toUpperCase();
    final devise = codeDevise.isEmpty
        ? Currency.CDF
        : Currency.values.where((c) => c.code == codeDevise).firstOrNull;
    if (devise == null) {
      a.ecarts.add('$ref : devise « $codeDevise » inconnue (CDF, USD…).');
      continue;
    }
    final taux = devises.getRateToCdf(devise);
    if (devise != Currency.CDF && !(taux > 0)) {
      a.ecarts.add('$ref : aucun taux $codeDevise défini dans les paramètres.');
      continue;
    }
    a.produits.add(Product(
      id: const Uuid().v4(),
      name: nom,
      description: cellule(l, iDesc),
      barcode: cellule(l, iCode),
      category: _categorie(cellule(l, iCat)),
      costPriceInCdf: devises.convertToCdf(achat, devise),
      sellingPriceInCdf: devises.convertToCdf(vente, devise),
      stockQuantity: quantite,
      unit: _unite(cellule(l, iUnite)),
      alertThreshold: nombre(cellule(l, iSeuil)) ?? 5,
      createdAt: maintenant,
      updatedAt: maintenant,
      inputCurrencyCode: devise.code,
      inputExchangeRate: taux,
      costPriceInInputCurrency: achat,
      sellingPriceInInputCurrency: vente,
    ));
  }
  return a;
}

/// Clé de comparaison : minuscules, sans accents ni espaces superflus.
String _cle(String s) {
  const avec = 'àâäáãéèêëíìîïóòôöõúùûüçñ';
  const sans = 'aaaaaeeeeiiiiooooouuuucn';
  final b = StringBuffer();
  for (final r in s.toLowerCase().trim().runes) {
    final c = String.fromCharCode(r);
    final i = avec.indexOf(c);
    b.write(i >= 0 ? sans[i] : c);
  }
  return b.toString().replaceAll(RegExp(r'\s+'), ' ');
}

ProductCategory _categorie(String s) {
  final c = _cle(s);
  if (c.isEmpty) return ProductCategory.other;
  for (final p in ProductCategory.values) {
    if (_cle(p.displayName) == c || p.name == c) return p;
  }
  return ProductCategory.other;
}

ProductUnit _unite(String s) {
  switch (_cle(s)) {
    case 'kg':
    case 'kilo':
    case 'kilogramme':
      return ProductUnit.kg;
    case 'g':
    case 'gramme':
      return ProductUnit.g;
    case 'l':
    case 'litre':
      return ProductUnit.l;
    case 'ml':
    case 'millilitre':
      return ProductUnit.ml;
    case 'paquet':
    case 'package':
      return ProductUnit.package;
    case 'boite':
    case 'box':
      return ProductUnit.box;
    case '':
    case 'piece':
    case 'pieces':
    case 'pce':
    case 'pc':
      return ProductUnit.piece;
    default:
      return ProductUnit.other;
  }
}

List<List<String>> _lireCsv(Uint8List octets) {
  var texte = utf8.decode(octets, allowMalformed: true);
  if (texte.startsWith('﻿')) texte = texte.substring(1);
  // Excel en français enregistre souvent avec « ; ».
  final premiere = texte.split('\n').first;
  final sep = ';'.allMatches(premiere).length > ','.allMatches(premiere).length ? ';' : ',';
  return CsvToListConverter(fieldDelimiter: sep, eol: '\n', shouldParseNumbers: false)
      .convert(texte.replaceAll('\r\n', '\n'))
      .map((l) => l.map((c) => '$c').toList())
      .toList();
}

List<List<String>> _lireXlsx(Uint8List octets) {
  final classeur = Excel.decodeBytes(octets);
  final feuille = classeur.tables.values.first;
  return feuille.rows
      .map((l) => l.map((c) {
            final v = c?.value;
            if (v == null) return '';
            if (v is TextCellValue) return v.value.toString();
            if (v is IntCellValue) return '${v.value}';
            if (v is DoubleCellValue) return '${v.value}';
            return v.toString();
          }).toList())
      .toList();
}

void _message(BuildContext context, String texte) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texte)));
}
