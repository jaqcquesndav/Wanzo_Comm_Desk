import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service de partage multi-plateforme
/// Gère les différences entre mobile et desktop pour le partage de fichiers
class PlatformShareService {
  static PlatformShareService? _instance;

  PlatformShareService._();

  static PlatformShareService get instance {
    _instance ??= PlatformShareService._();
    return _instance!;
  }

  /// Vérifie si le partage de fichiers est supporté sur la plateforme courante
  bool get isFileShareSupported {
    if (kIsWeb) return false;
    // Windows supporte le partage de fichiers via share_plus 11+
    // Linux ne le supporte pas
    if (Platform.isLinux) return false;
    return true;
  }

  /// Vérifie si l'impression est supportée sur la plateforme courante
  bool get isPrintingSupported {
    if (kIsWeb) return true; // Web supporte l'impression
    return true; // Toutes les plateformes desktop/mobile supportent l'impression
  }

  /// Partage un fichier PDF avec gestion des erreurs de plateforme
  ///
  /// [filePath] - Chemin du fichier PDF à partager
  /// [subject] - Sujet pour le partage (utilisé dans les emails)
  /// [text] - Texte accompagnant le partage
  /// [context] - Context pour afficher les dialogues de fallback
  Future<ShareResult> sharePdfFile({
    required String filePath,
    required String subject,
    required String text,
    required BuildContext context,
  }) async {
    try {
      // Vérifier que le fichier existe
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Le fichier n\'existe pas: $filePath');
      }

      if (kIsWeb) {
        // Web: Utiliser Printing.sharePdf
        await Printing.sharePdf(
          bytes: await file.readAsBytes(),
          filename: file.path.split(Platform.pathSeparator).last,
        );
        return const ShareResult(
          'Partagé via impression',
          ShareResultStatus.success,
        );
      }

      if (Platform.isLinux) {
        // Linux ne supporte pas le partage de fichiers, proposer alternatives
        return await _handleLinuxShare(filePath, subject, text, context);
      }

      // Autres plateformes: utiliser share_plus
      final xFile = XFile(filePath);
      final result = await SharePlus.instance.share(
        ShareParams(files: [xFile], text: text, subject: subject),
      );
      return result;
    } on MissingPluginException catch (e) {
      debugPrint('[PlatformShareService] MissingPluginException: $e');
      // Fallback: proposer d'enregistrer ou d'imprimer
      return await _handleMissingPluginFallback(
        filePath,
        subject,
        text,
        context,
      );
    } on PlatformException catch (e) {
      debugPrint('[PlatformShareService] PlatformException: $e');
      return await _handleMissingPluginFallback(
        filePath,
        subject,
        text,
        context,
      );
    } catch (e) {
      debugPrint('[PlatformShareService] Error during share: $e');
      rethrow;
    }
  }

  /// Imprime un fichier PDF avec gestion des erreurs de plateforme
  Future<void> printPdfFile({
    required String filePath,
    required String documentName,
  }) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Le fichier n\'existe pas: $filePath');
      }

      await Printing.layoutPdf(
        onLayout: (format) async => file.readAsBytes(),
        name: documentName,
      );
    } on MissingPluginException catch (e) {
      debugPrint(
        '[PlatformShareService] MissingPluginException pour impression: $e',
      );
      rethrow;
    } catch (e) {
      debugPrint('[PlatformShareService] Error during print: $e');
      rethrow;
    }
  }

  /// Gère le partage sur Linux (qui ne supporte pas le partage de fichiers)
  Future<ShareResult> _handleLinuxShare(
    String filePath,
    String subject,
    String text,
    BuildContext context,
  ) async {
    // Sur Linux, proposer d'ouvrir le fichier ou de copier le chemin
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Partager le document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Le partage de fichiers n\'est pas disponible sur Linux. '
              'Choisissez une alternative:',
            ),
            const SizedBox(height: 16),
            Text(
              'Fichier: ${filePath.split(Platform.pathSeparator).last}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('copy'),
            child: const Text('Copier le chemin'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('open'),
            child: const Text('Ouvrir le dossier'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('print'),
            child: const Text('Imprimer'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );

    switch (result) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: filePath));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chemin copié dans le presse-papier')),
          );
        }
        return const ShareResult('Chemin copié', ShareResultStatus.success);
      case 'open':
        final directory = File(filePath).parent.path;
        await launchUrl(Uri.parse('file://$directory'));
        return const ShareResult('Dossier ouvert', ShareResultStatus.success);
      case 'print':
        await printPdfFile(filePath: filePath, documentName: subject);
        return const ShareResult('Imprimé', ShareResultStatus.success);
      default:
        return const ShareResult('Annulé', ShareResultStatus.dismissed);
    }
  }

  /// Gère le fallback quand le plugin n'est pas disponible
  Future<ShareResult> _handleMissingPluginFallback(
    String filePath,
    String subject,
    String text,
    BuildContext context,
  ) async {
    // Proposer des alternatives
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Partage non disponible'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Le partage direct n\'est pas disponible sur cette plateforme. '
              'Choisissez une alternative:',
            ),
            const SizedBox(height: 16),
            Text(
              'Document: ${filePath.split(Platform.pathSeparator).last}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('save'),
            child: const Text('Enregistrer dans Documents'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('print'),
            child: const Text('Imprimer'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('copy'),
            child: const Text('Copier le chemin'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancel'),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );

    switch (result) {
      case 'save':
        try {
          final documentsDir = await getApplicationDocumentsDirectory();
          final fileName = filePath.split(Platform.pathSeparator).last;
          final newPath =
              '${documentsDir.path}${Platform.pathSeparator}$fileName';
          await File(filePath).copy(newPath);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Document enregistré: $newPath')),
            );
          }
          return const ShareResult('Enregistré', ShareResultStatus.success);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Erreur: $e')));
          }
          return const ShareResult('Erreur', ShareResultStatus.unavailable);
        }
      case 'print':
        try {
          await printPdfFile(filePath: filePath, documentName: subject);
          return const ShareResult('Imprimé', ShareResultStatus.success);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Erreur d\'impression: $e')));
          }
          return const ShareResult('Erreur', ShareResultStatus.unavailable);
        }
      case 'copy':
        await Clipboard.setData(ClipboardData(text: filePath));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Chemin copié dans le presse-papier')),
          );
        }
        return const ShareResult('Chemin copié', ShareResultStatus.success);
      default:
        return const ShareResult('Annulé', ShareResultStatus.dismissed);
    }
  }

  /// Partage simple de texte (fonctionne sur toutes les plateformes)
  Future<ShareResult> shareText({required String text, String? subject}) async {
    try {
      return await SharePlus.instance.share(
        ShareParams(text: text, subject: subject),
      );
    } on MissingPluginException {
      // Fallback: copier dans le presse-papier
      await Clipboard.setData(ClipboardData(text: text));
      return const ShareResult('Copié', ShareResultStatus.success);
    }
  }
}
