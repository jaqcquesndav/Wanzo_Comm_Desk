import 'dart:io'; // Added for File operations

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:wanzo/features/expenses/bloc/expense_bloc.dart';
import 'package:wanzo/features/expenses/models/expense.dart';
import 'package:wanzo/core/shared_widgets/wanzo_app_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart'; // Pour le partage
// Pour XFile
import 'package:path_provider/path_provider.dart'; // Pour les répertoires temporaires
import 'package:flutter_cache_manager/flutter_cache_manager.dart'; // Pour la gestion du cache
import 'package:http/http.dart' as http; // Pour les téléchargements manuels
import 'package:permission_handler/permission_handler.dart'; // Pour les permissions

// Import pour PhotoView
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

class ExpenseDetailScreen extends StatefulWidget {
  final String expenseId;

  const ExpenseDetailScreen({super.key, required this.expenseId});

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  bool _isSharing = false; // To track sharing state and show loading indicator

  @override
  void initState() {
    super.initState();
    context.read<ExpenseBloc>().add(LoadExpenseById(widget.expenseId));
    _checkPermissions();
  }

  // Obtenir la couleur selon le statut de paiement
  Color _getStatusColor(ExpensePaymentStatus? status) {
    switch (status) {
      case ExpensePaymentStatus.paid:
        return Colors.green;
      case ExpensePaymentStatus.partial:
        return Colors.orange;
      case ExpensePaymentStatus.unpaid:
      case null:
        return Colors.red;
      case ExpensePaymentStatus.credit:
        return Colors.blue;
    }
  }

  // Afficher le dialogue pour enregistrer un paiement partiel
  void _showPartialPaymentDialog(BuildContext context, Expense expense) {
    final remainingAmount = expense.remainingAmount;
    final TextEditingController amountController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Enregistrer un paiement'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Montant restant: ${NumberFormat.currency(symbol: '${expense.effectiveCurrencyCode} ', decimalDigits: 2).format(remainingAmount)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Montant payé',
                      prefixText: '${expense.effectiveCurrencyCode} ',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer un montant';
                      }
                      final amount = double.tryParse(value);
                      if (amount == null || amount <= 0) {
                        return 'Montant invalide';
                      }
                      if (amount > remainingAmount) {
                        return 'Le montant dépasse le reste à payer';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    final paidAmount = double.parse(amountController.text);
                    final newTotalPaid =
                        (expense.paidAmount ?? 0.0) + paidAmount;
                    final newStatus =
                        newTotalPaid >= expense.amount
                            ? ExpensePaymentStatus.paid
                            : ExpensePaymentStatus.partial;

                    final updatedExpense = expense.copyWith(
                      paidAmount: newTotalPaid,
                      paymentStatus: newStatus,
                    );

                    context.read<ExpenseBloc>().add(
                      UpdateExpense(updatedExpense),
                    );
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Paiement enregistré')),
                    );
                  }
                },
                child: const Text('Enregistrer'),
              ),
            ],
          ),
    );
  }

  // Vérifier et demander les permissions nécessaires au démarrage
  Future<void> _checkPermissions() async {
    // Vérifier les permissions de stockage
    final storageStatus = await Permission.storage.status;
    if (!storageStatus.isGranted) {
      // Ne pas demander immédiatement, attendre l'action de l'utilisateur
      // La permission sera demandée lors de la première utilisation
    }
  }

  // Partager une pièce jointe
  Future<void> _shareAttachment(BuildContext context, String url) async {
    if (_isSharing) return;

    setState(() {
      _isSharing = true;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Préparation du partage...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final File imageToShare = await _getFileForSharing(url);
      final xFile = XFile(imageToShare.path);

      // Extraire le nom du fichier pour le message de partage
      String fileName = 'pièce_jointe';
      try {
        final uri = Uri.parse(url);
        if (uri.pathSegments.isNotEmpty) {
          String lastSegment = uri.pathSegments.last;
          if (lastSegment.isNotEmpty) {
            fileName = lastSegment;
          }
        }
      } catch (_) {
        // En cas d'échec d'analyse, conserver le nom par défaut
      }

      final result = await SharePlus.instance.share(
        ShareParams(
          text: 'Pièce jointe: $fileName',
          subject: 'Dépense Wanzo',
          files: [xFile],
        ),
      );

      // Vérifier si le partage a été effectué ou annulé
      if (result.raw.isEmpty) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Partage annulé')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Erreur de partage: ${e.toString()}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  // Récupérer un fichier pour le partage ou le téléchargement
  Future<File> _getFileForSharing(String url) async {
    try {
      // Essayer d'obtenir le fichier depuis le cache
      final fileInfo = await DefaultCacheManager().getFileFromCache(url);

      if (fileInfo != null && await fileInfo.file.exists()) {
        return fileInfo.file;
      } else {
        // Si pas dans le cache ou fichier inexistant, télécharger
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 30)); // Ajouter un timeout

        if (response.statusCode == 200) {
          final tempDir = await getTemporaryDirectory();
          // Extraire le nom de fichier de l'URL ou en générer un
          String fileName = 'shared_image.jpg'; // Nom par défaut
          try {
            final uri = Uri.parse(url);
            if (uri.pathSegments.isNotEmpty) {
              String lastSegment = uri.pathSegments.last;
              if (lastSegment.isNotEmpty && lastSegment.contains('.')) {
                fileName = lastSegment;
              } else if (lastSegment.isNotEmpty) {
                fileName = '$lastSegment.jpg'; // Ajouter extension par défaut
              }
            }
          } catch (_) {
            // Si l'analyse URI échoue ou si le chemin est inhabituel, s'en tenir à la valeur par défaut
          }

          // Générer un nom de fichier unique avec timestamp pour éviter les conflits
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final uniqueFileName = '${timestamp}_$fileName';

          final File file = File('${tempDir.path}/$uniqueFileName');
          await file.writeAsBytes(response.bodyBytes);

          if (await file.exists()) {
            return file;
          } else {
            throw Exception(
              "Le fichier téléchargé n'existe pas après l'écriture.",
            );
          }
        } else {
          throw Exception(
            'Échec du téléchargement de l\'image (status: ${response.statusCode})',
          );
        }
      }
    } catch (e) {
      // En cas d'échec de téléchargement, essayer une deuxième méthode
      try {
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'backup_image_$timestamp.jpg';

        final response = await http
            .get(
              Uri.parse(url),
              headers: {'User-Agent': 'Mozilla/5.0'}, // Ajouter un User-Agent
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          final File file = File('${tempDir.path}/$fileName');
          await file.writeAsBytes(response.bodyBytes);
          return file;
        }
      } catch (_) {
        // Ignorer les erreurs de la seconde tentative
      }

      // Si toutes les tentatives échouent, propager l'erreur originale
      rethrow;
    }
  }

  // Sauvegarder une pièce jointe
  Future<void> _saveAttachment(BuildContext context, String url) async {
    if (_isSharing) return; // Prévenir les téléchargements multiples

    setState(() {
      _isSharing = true;
    });

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Téléchargement en cours...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      // Vérifier les permissions de stockage
      final status = await Permission.storage.status;
      if (!status.isGranted) {
        final result = await Permission.storage.request();
        if (!result.isGranted) {
          throw Exception("Permission de stockage refusée");
        }
      }

      // Utilise la méthode existante pour récupérer le fichier
      final File downloadedFile = await _getFileForSharing(url);

      // Déterminer le nom du fichier
      String fileName = 'piece_jointe.jpg';
      try {
        final uri = Uri.parse(url);
        if (uri.pathSegments.isNotEmpty) {
          String lastSegment = uri.pathSegments.last;
          if (lastSegment.isNotEmpty && lastSegment.contains('.')) {
            fileName = lastSegment;
          } else if (lastSegment.isNotEmpty) {
            fileName = '$lastSegment.jpg';
          }
        }
      } catch (_) {
        // En cas d'échec d'analyse, conserver le nom par défaut
      }

      // Obtenir le répertoire de téléchargement
      Directory? directory;

      try {
        directory = await getExternalStorageDirectory();
      } catch (e) {
        // Fallback si le répertoire de stockage externe n'est pas disponible
        directory = await getApplicationDocumentsDirectory();
      }

      // Créer un nouveau fichier dans le répertoire de téléchargement
      final savedFile = File('${directory?.path}/$fileName');
      await downloadedFile.copy(savedFile.path);

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Fichier sauvegardé dans ${savedFile.path}'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {
                // Ne rien faire, juste fermer la notification
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Erreur de téléchargement: ${e.toString()}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
  }

  void _openFullScreenImageViewer(
    BuildContext context,
    final List<String> imageUrls,
    final int initialIndex,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Fermer',
                ),
                title: Text(
                  'Pièce jointe ${initialIndex + 1}/${imageUrls.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                actions: [
                  // Bouton de partage
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: () {
                      _shareAttachment(context, imageUrls[initialIndex]);
                    },
                    tooltip: 'Partager',
                  ),
                  // Bouton de téléchargement
                  IconButton(
                    icon: const Icon(Icons.save_alt, color: Colors.white),
                    onPressed: () {
                      _saveAttachment(context, imageUrls[initialIndex]);
                    },
                    tooltip: 'Télécharger',
                  ),
                  // Menu d'options supplémentaires
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onSelected: (value) {
                      // Gérer les actions supplémentaires ici
                      switch (value) {
                        case 'rotate':
                          // Cette fonctionnalité nécessiterait un état pour suivre la rotation
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Fonctionnalité de rotation à implémenter',
                              ),
                            ),
                          );
                          break;
                        case 'info':
                          // Afficher des informations sur l'image
                          _showAttachmentInfo(context, imageUrls[initialIndex]);
                          break;
                      }
                    },
                    itemBuilder:
                        (BuildContext context) => <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'rotate',
                            child: Row(
                              children: [
                                Icon(Icons.rotate_right),
                                SizedBox(width: 8),
                                Text('Pivoter'),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'info',
                            child: Row(
                              children: [
                                Icon(Icons.info_outline),
                                SizedBox(width: 8),
                                Text('Informations'),
                              ],
                            ),
                          ),
                        ],
                  ),
                ],
              ),
              body: PhotoViewGallery.builder(
                itemCount: imageUrls.length,
                builder: (context, index) {
                  return PhotoViewGalleryPageOptions(
                    imageProvider: CachedNetworkImageProvider(imageUrls[index]),
                    initialScale: PhotoViewComputedScale.contained,
                    heroAttributes: PhotoViewHeroAttributes(
                      tag: imageUrls[index],
                    ),
                    minScale: PhotoViewComputedScale.contained * 0.8,
                    maxScale: PhotoViewComputedScale.covered * 2,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.black,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red[400],
                                size: 50,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                "Impossible de charger l'image",
                                style: TextStyle(color: Colors.white),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                                child: const Text('Retour'),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                scrollPhysics: const BouncingScrollPhysics(),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                pageController: PageController(initialPage: initialIndex),
                loadingBuilder: (context, event) {
                  double? progress;
                  if (event != null && event.expectedTotalBytes != null) {
                    progress =
                        event.cumulativeBytesLoaded / event.expectedTotalBytes!;
                  }
                  return Center(
                    child: SizedBox(
                      width: 50.0,
                      height: 50.0,
                      child: CircularProgressIndicator(
                        value: progress,
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
                onPageChanged: (index) {
                  // Possibilité d'ajouter un état pour suivre l'index actuel
                },
              ),
            ),
      ),
    );
  }

  // Afficher les informations sur une pièce jointe
  void _showAttachmentInfo(BuildContext context, String url) {
    // Extraire le nom du fichier
    String fileName = 'Inconnu';
    try {
      final uri = Uri.parse(url);
      if (uri.pathSegments.isNotEmpty) {
        fileName = uri.pathSegments.last;
      }
    } catch (_) {
      // Utiliser la valeur par défaut en cas d'erreur
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Informations sur la pièce jointe'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nom du fichier:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(fileName),
                const SizedBox(height: 12),
                const Text(
                  'URL:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  url,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _saveAttachment(context, url);
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.save_alt, size: 16),
                      SizedBox(width: 8),
                      Text('Télécharger'),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: 'FCFA',
    );

    return Scaffold(
      appBar: WanzoAppBar(
        title: 'Détails de la Dépense',
        onBackPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/operations');
          }
        },
      ),
      body: Stack(
        children: [
          BlocBuilder<ExpenseBloc, ExpenseState>(
            builder: (context, state) {
              if (state is ExpenseLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is ExpenseLoaded) {
                final expense = state.expense;
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // Carte principale avec les détails
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Icône pour la catégorie
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).primaryColor.withAlpha(25),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _getCategoryIcon(expense.category),
                                      color: Theme.of(context).primaryColor,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Détails principaux
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          expense.motif,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat(
                                            'dd MMMM yyyy',
                                            'fr_FR',
                                          ).format(expense.date),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.copyWith(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Montant avec devise
                                        Text(
                                          currencyFormat.format(expense.amount),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 32),
                              // Informations détaillées
                              _buildDetailItem(
                                context,
                                'Catégorie',
                                expense.category.displayName,
                                Icons.category,
                              ),
                              _buildDetailItem(
                                context,
                                'Méthode de paiement',
                                expense.paymentMethod ?? 'Non spécifiée',
                                Icons.payment,
                              ),
                              if (expense.beneficiary != null &&
                                  expense.beneficiary!.isNotEmpty)
                                _buildDetailItem(
                                  context,
                                  'Bénéficiaire',
                                  expense.beneficiary!,
                                  Icons.person,
                                ),
                              if (expense.notes != null &&
                                  expense.notes!.isNotEmpty)
                                _buildDetailItem(
                                  context,
                                  'Notes',
                                  expense.notes!,
                                  Icons.note,
                                ),

                              const Divider(height: 32),

                              // Section État du paiement
                              Row(
                                children: [
                                  Icon(
                                    Icons.payment,
                                    size: 20,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'État du paiement',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(
                                        expense.paymentStatus,
                                      ).withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: _getStatusColor(
                                          expense.paymentStatus,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      expense.paymentStatusText,
                                      style: TextStyle(
                                        color: _getStatusColor(
                                          expense.paymentStatus,
                                        ),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Montants détaillés
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Montant total:',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                        Text(
                                          currencyFormat.format(expense.amount),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text(
                                          'Montant payé:',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                        Text(
                                          currencyFormat.format(
                                            expense.paidAmount ?? 0.0,
                                          ),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (expense.remainingAmount > 0) ...[
                                      const Divider(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Reste à payer:',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            currencyFormat.format(
                                              expense.remainingAmount,
                                            ),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Boutons d'action pour le paiement
                              if (expense.paymentStatus !=
                                  ExpensePaymentStatus.paid) ...[
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    if (expense.remainingAmount > 0) ...[
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed:
                                              () => _showPartialPaymentDialog(
                                                context,
                                                expense,
                                              ),
                                          icon: const Icon(Icons.payments),
                                          label: const Text('Paiement partiel'),
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          final Expense updatedExpense = expense
                                              .copyWith(
                                                paymentStatus:
                                                    ExpensePaymentStatus.paid,
                                                paidAmount: expense.amount,
                                              );
                                          context.read<ExpenseBloc>().add(
                                            UpdateExpense(updatedExpense),
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Dépense marquée comme payée',
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.check_circle),
                                        label: const Text('Marquer comme Payé'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Section des pièces jointes
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.attach_file,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pièces Jointes',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildAttachments(
                                context,
                                expense.attachmentUrls ?? [],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } else if (state is ExpenseError) {
                return Center(child: Text('Erreur: ${state.message}'));
              }
              return const Center(child: Text('Veuillez charger une dépense.'));
            },
          ),
          if (_isSharing)
            Container(
              color: Colors.black.withAlpha(128), // 0.5 * 255 = 128
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text(
                      'Traitement en cours...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Méthode pour obtenir l'icône correspondant à la catégorie
  IconData _getCategoryIcon(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.rent:
        return Icons.home;
      case ExpenseCategory.utilities:
        return Icons.electrical_services;
      case ExpenseCategory.supplies:
        return Icons.shopping_basket;
      case ExpenseCategory.salaries:
        return Icons.people;
      case ExpenseCategory.marketing:
        return Icons.campaign;
      case ExpenseCategory.transport:
        return Icons.directions_car;
      case ExpenseCategory.maintenance:
        return Icons.build;
      case ExpenseCategory.inventory:
        return Icons.inventory_2;
      case ExpenseCategory.equipment:
        return Icons.construction;
      case ExpenseCategory.taxes:
        return Icons.receipt_long;
      case ExpenseCategory.insurance:
        return Icons.security;
      case ExpenseCategory.loan:
        return Icons.account_balance;
      case ExpenseCategory.office:
        return Icons.business_center;
      case ExpenseCategory.training:
        return Icons.school;
      case ExpenseCategory.travel:
        return Icons.flight;
      case ExpenseCategory.software:
        return Icons.computer;
      case ExpenseCategory.advertising:
        return Icons.ads_click;
      case ExpenseCategory.legal:
        return Icons.gavel;
      case ExpenseCategory.manufacturing:
        return Icons.precision_manufacturing;
      case ExpenseCategory.consulting:
        return Icons.support_agent;
      case ExpenseCategory.research:
        return Icons.science;
      case ExpenseCategory.fuel:
        return Icons.local_gas_station;
      case ExpenseCategory.entertainment:
        return Icons.card_giftcard;
      case ExpenseCategory.communication:
        return Icons.phone_in_talk;
      case ExpenseCategory.other:
        return Icons.more_horiz;
    }
  }

  // Méthode pour créer un élément détaillé
  Widget _buildDetailItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachments(BuildContext context, List<String> attachmentUrls) {
    if (attachmentUrls.isEmpty) {
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        color: Colors.grey[100],
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, color: Colors.grey, size: 20),
              SizedBox(width: 8),
              Text(
                'Aucune pièce jointe disponible',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Utiliser GridView.builder pour les pièces jointes
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount:
            MediaQuery.of(context).size.width > 600
                ? 3
                : 2, // Adaptif selon la largeur
        childAspectRatio: 1.0,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: attachmentUrls.length,
      itemBuilder: (context, index) {
        final url = attachmentUrls[index];
        return Hero(
          tag: url,
          child: Card(
            clipBehavior: Clip.antiAlias,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Image principale
                GestureDetector(
                  onTap: () {
                    _openFullScreenImageViewer(context, attachmentUrls, index);
                  },
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder:
                        (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    errorWidget: (context, url, error) {
                      // Si l'URL commence par "uploads/", c'est probablement une simulation locale
                      if (url.startsWith('uploads/')) {
                        return Container(
                          color: Colors.grey[300],
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  color: Colors.grey[600],
                                  size: 40,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Simulé',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return Container(
                        color: Colors.grey[300],
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error,
                                color: Colors.red[400],
                                size: 32,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Erreur de chargement',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Superposition des boutons d'action
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withAlpha(179), // 0.7 * 255 = ~179
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.8],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Bouton de partage
                        IconButton(
                          icon: const Icon(
                            Icons.share,
                            color: Colors.white,
                            size: 20,
                          ),
                          tooltip: 'Partager',
                          onPressed: () => _shareAttachment(context, url),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),

                        // Bouton de sauvegarde
                        IconButton(
                          icon: const Icon(
                            Icons.save_alt,
                            color: Colors.white,
                            size: 20,
                          ),
                          tooltip: 'Sauvegarder',
                          onPressed: () => _saveAttachment(context, url),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),

                        // Bouton d'agrandissement
                        IconButton(
                          icon: const Icon(
                            Icons.fullscreen,
                            color: Colors.white,
                            size: 20,
                          ),
                          tooltip: 'Agrandir',
                          onPressed:
                              () => _openFullScreenImageViewer(
                                context,
                                attachmentUrls,
                                index,
                              ),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
