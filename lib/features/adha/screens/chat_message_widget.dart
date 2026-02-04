import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/adha_message.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/vs2015.dart'; // Thème sombre pour code
import 'package:flutter/services.dart'; // Added for Clipboard
import 'package:url_launcher/url_launcher.dart';

/// Types de contenu pour le parsing mixte
enum _ContentType { code, latexBlock, image }

/// Match de contenu pour le parsing
class _ContentMatch {
  final int start;
  final int end;
  final _ContentType type;
  final String content;
  final String? language;
  final String? alt;

  _ContentMatch({
    required this.start,
    required this.end,
    required this.type,
    required this.content,
    this.language,
    this.alt,
  });
}

/// Widget pour afficher un message dans la conversation avec Adha
class ChatMessageWidget extends StatelessWidget {
  /// Le message à afficher
  final AdhaMessage message;
  final Function(AdhaMessage)? onEditMessage; // Callback for edit action
  final Function(AdhaMessage)? onRetryMessage; // Callback for retry action

  const ChatMessageWidget({
    super.key,
    required this.message,
    this.onEditMessage, // Initialize in constructor
    this.onRetryMessage, // Initialize in constructor
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUserMessage;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        isUser
            ? Colors.transparent
            : (isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF7F7F8));
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return Container(
      width: double.infinity,
      color: bgColor,
      padding: EdgeInsets.only(
        left: isUser ? 48 : 16,
        right: isUser ? 16 : 48,
        top: 16,
        bottom: 16,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children:
            isUser
                ? [
                  // Message utilisateur : contenu à gauche, avatar à droite
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Nom de l'expéditeur
                        Text(
                          'Vous',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Contenu du message
                        _buildMessageContent(context, textColor),
                        const SizedBox(height: 8),
                        // Actions et timestamp
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (onEditMessage != null) ...[
                              _buildEditAction(context),
                              const SizedBox(width: 16),
                            ],
                            Text(
                              _formatTimestamp(message.timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: textColor.withAlpha((0.5 * 255).round()),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildAvatar(isUser, isDark),
                ]
                : [
                  // Message ADHA : avatar à gauche, contenu à droite
                  _buildAvatar(isUser, isDark),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nom de l'expéditeur
                        Text(
                          'ADHA',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Contenu du message
                        _buildMessageContent(context, textColor),
                        const SizedBox(height: 8),
                        // Actions et timestamp
                        Row(
                          children: [
                            Text(
                              _formatTimestamp(message.timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: textColor.withAlpha((0.5 * 255).round()),
                              ),
                            ),
                            const SizedBox(width: 16),
                            _buildFeedbackActions(context),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
      ),
    );
  }

  /// Construit le contenu du message en fonction de son type
  Widget _buildMessageContent(BuildContext context, Color textColor) {
    // Détection automatique du type de contenu pour les messages ADHA
    if (!message.isUserMessage) {
      // Vérifier si le contenu contient des blocs de code
      if (_containsCodeBlocks(message.content)) {
        return _buildMixedContent(context, textColor);
      }
      // Vérifier si le contenu contient du LaTeX
      if (_containsLatex(message.content)) {
        return _buildMixedContent(context, textColor);
      }
      // Vérifier si le contenu contient des images base64
      if (_containsImages(message.content)) {
        return _buildMixedContent(context, textColor);
      }
    }

    switch (message.type) {
      case AdhaMessageType.text:
        return _buildTextMessage(context, textColor);
      case AdhaMessageType.code:
        return _buildMixedContent(context, textColor);
      case AdhaMessageType.latex:
        return _buildMixedContent(context, textColor);
      case AdhaMessageType.graph:
        return _buildGraphMessage(context);
      case AdhaMessageType.media:
        return _buildMediaMessage(context);
    }
  }

  /// Vérifie si le contenu contient des blocs de code markdown
  bool _containsCodeBlocks(String content) {
    return RegExp(r'```[\s\S]*?```').hasMatch(content);
  }

  /// Vérifie si le contenu contient du LaTeX
  bool _containsLatex(String content) {
    return content.contains(r'$$') ||
        content.contains(r'\[') ||
        content.contains(r'\(') ||
        RegExp(r'\$[^$]+\$').hasMatch(content);
  }

  /// Vérifie si le contenu contient des images
  bool _containsImages(String content) {
    return content.contains('![') ||
        content.contains('data:image') ||
        content.contains('<img');
  }

  /// Construit un contenu mixte (texte + code + LaTeX + images)
  /// Style inspiré de ChatGPT avec blocs de code labellisés
  Widget _buildMixedContent(BuildContext context, Color textColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Widget> widgets = [];

    // Pattern pour détecter les blocs de code avec langage
    final codePattern = RegExp(r'```(\w+)?\n?([\s\S]*?)```', multiLine: true);
    // Pattern pour détecter le LaTeX en bloc
    final latexBlockPattern = RegExp(r'\$\$([\s\S]*?)\$\$', multiLine: true);
    // Pattern pour détecter les images markdown
    final imagePattern = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)');

    int lastIndex = 0;

    // Trouver tous les matches et les trier par position
    final List<_ContentMatch> matches = [];

    for (final match in codePattern.allMatches(message.content)) {
      matches.add(
        _ContentMatch(
          start: match.start,
          end: match.end,
          type: _ContentType.code,
          language: match.group(1) ?? 'plaintext',
          content: match.group(2) ?? '',
        ),
      );
    }

    for (final match in latexBlockPattern.allMatches(message.content)) {
      // Éviter les doublons avec les blocs de code
      if (!matches.any((m) => m.start <= match.start && m.end >= match.end)) {
        matches.add(
          _ContentMatch(
            start: match.start,
            end: match.end,
            type: _ContentType.latexBlock,
            content: match.group(1) ?? '',
          ),
        );
      }
    }

    for (final match in imagePattern.allMatches(message.content)) {
      if (!matches.any((m) => m.start <= match.start && m.end >= match.end)) {
        matches.add(
          _ContentMatch(
            start: match.start,
            end: match.end,
            type: _ContentType.image,
            content: match.group(2) ?? '',
            alt: match.group(1),
          ),
        );
      }
    }

    // Trier par position
    matches.sort((a, b) => a.start.compareTo(b.start));

    // Construire les widgets
    for (final match in matches) {
      // Ajouter le texte avant ce match
      if (match.start > lastIndex) {
        final textBefore =
            message.content.substring(lastIndex, match.start).trim();
        if (textBefore.isNotEmpty) {
          widgets.add(_buildTextSegment(context, textBefore, textColor));
        }
      }

      // Ajouter le widget pour ce match
      switch (match.type) {
        case _ContentType.code:
          widgets.add(const SizedBox(height: 12));
          widgets.add(
            _buildCodeBlock(
              context,
              match.content,
              match.language ?? 'plaintext',
              isDark,
            ),
          );
          widgets.add(const SizedBox(height: 12));
        case _ContentType.latexBlock:
          widgets.add(const SizedBox(height: 12));
          widgets.add(_buildLatexBlock(context, match.content, isDark));
          widgets.add(const SizedBox(height: 12));
        case _ContentType.image:
          widgets.add(const SizedBox(height: 12));
          widgets.add(_buildImageBlock(context, match.content, match.alt));
          widgets.add(const SizedBox(height: 12));
      }

      lastIndex = match.end;
    }

    // Ajouter le texte restant
    if (lastIndex < message.content.length) {
      final textAfter = message.content.substring(lastIndex).trim();
      if (textAfter.isNotEmpty) {
        widgets.add(_buildTextSegment(context, textAfter, textColor));
      }
    }

    // Si aucun widget spécial n'a été trouvé, afficher comme texte simple
    if (widgets.isEmpty) {
      return _buildTextMessage(context, textColor);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Construit un segment de texte avec markdown
  Widget _buildTextSegment(BuildContext context, String text, Color textColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MarkdownBody(
      data: text,
      selectable: true,
      onTapLink: (text, href, title) {
        if (href != null) {
          launchUrl(Uri.parse(href));
        }
      },
      styleSheet: _buildMarkdownStyleSheet(context, textColor, isDark),
      shrinkWrap: true,
    );
  }

  /// Construit un bloc de code avec header de langage (style ChatGPT)
  Widget _buildCodeBlock(
    BuildContext context,
    String code,
    String language,
    bool isDark,
  ) {
    final displayLanguage = _getDisplayLanguage(language);
    final headerColor =
        isDark ? const Color(0xFF343541) : const Color(0xFFE8E8E8);
    final codeColor =
        isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F7F8);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header avec le nom du langage et bouton copier
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(7),
                topRight: Radius.circular(7),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  displayLanguage,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code.trim()));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Code copié'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.content_copy,
                        size: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Copier',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Code avec coloration syntaxique
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: codeColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(7),
                bottomRight: Radius.circular(7),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: HighlightView(
                code.trim(),
                language: _mapLanguageForHighlight(language),
                theme: isDark ? vs2015Theme : githubTheme,
                padding: EdgeInsets.zero,
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Construit un bloc LaTeX
  Widget _buildLatexBlock(BuildContext context, String formula, bool isDark) {
    // Pour le moment, affichage simple du LaTeX
    // TODO: Intégrer flutter_math_fork pour un rendu LaTeX complet
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SelectableText(
          formula.trim(),
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 16,
            color: isDark ? Colors.white : Colors.black87,
            height: 1.6,
          ),
        ),
      ),
    );
  }

  /// Construit un bloc image
  Widget _buildImageBlock(BuildContext context, String src, String? alt) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Vérifier si c'est une image base64
    if (src.startsWith('data:image')) {
      final parts = src.split(',');
      if (parts.length == 2) {
        try {
          final bytes = base64Decode(parts[1]);
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return _buildImageError(context, alt);
              },
            ),
          );
        } catch (e) {
          return _buildImageError(context, alt);
        }
      }
    }

    // Image URL standard
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        src,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildImageError(context, alt);
        },
      ),
    );
  }

  /// Widget d'erreur pour les images
  Widget _buildImageError(BuildContext context, String? alt) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
              size: 32,
            ),
            if (alt != null && alt.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                alt,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Retourne le nom d'affichage du langage
  String _getDisplayLanguage(String language) {
    final languageMap = {
      'js': 'JavaScript',
      'javascript': 'JavaScript',
      'ts': 'TypeScript',
      'typescript': 'TypeScript',
      'py': 'Python',
      'python': 'Python',
      'dart': 'Dart',
      'java': 'Java',
      'kotlin': 'Kotlin',
      'swift': 'Swift',
      'go': 'Go',
      'rust': 'Rust',
      'cpp': 'C++',
      'c++': 'C++',
      'c': 'C',
      'csharp': 'C#',
      'cs': 'C#',
      'php': 'PHP',
      'ruby': 'Ruby',
      'sql': 'SQL',
      'html': 'HTML',
      'css': 'CSS',
      'scss': 'SCSS',
      'json': 'JSON',
      'yaml': 'YAML',
      'xml': 'XML',
      'bash': 'Bash',
      'shell': 'Shell',
      'sh': 'Shell',
      'plaintext': 'Text',
      'text': 'Text',
      'markdown': 'Markdown',
      'md': 'Markdown',
    };
    return languageMap[language.toLowerCase()] ?? language.toUpperCase();
  }

  /// Mappe le langage pour flutter_highlight
  String _mapLanguageForHighlight(String language) {
    final langMap = {
      'js': 'javascript',
      'ts': 'typescript',
      'py': 'python',
      'sh': 'bash',
      'cs': 'csharp',
      'c++': 'cpp',
    };
    return langMap[language.toLowerCase()] ?? language.toLowerCase();
  }

  /// Construit le style sheet pour le markdown
  MarkdownStyleSheet _buildMarkdownStyleSheet(
    BuildContext context,
    Color textColor,
    bool isDark,
  ) {
    return MarkdownStyleSheet(
      p: TextStyle(color: textColor, fontSize: 15, height: 1.6),
      strong: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      em: TextStyle(color: textColor, fontStyle: FontStyle.italic),
      h1: TextStyle(
        color: textColor,
        fontSize: 24,
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
      h2: TextStyle(
        color: textColor,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        height: 1.4,
      ),
      h3: TextStyle(
        color: textColor,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      code: TextStyle(
        color: isDark ? const Color(0xFFE06C75) : const Color(0xFFC41A16),
        backgroundColor:
            isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF4F4F4),
        fontFamily: 'monospace',
        fontSize: 14,
      ),
      codeblockDecoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(8),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockquote: TextStyle(
        color: textColor.withAlpha((0.8 * 255).round()),
        fontSize: 15,
        height: 1.5,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
            width: 3.0,
          ),
        ),
      ),
      blockquotePadding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
      listBullet: TextStyle(color: textColor, fontSize: 15),
      tableHead: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      tableBody: TextStyle(color: textColor),
      tableBorder: TableBorder.all(
        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        width: 1,
      ),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            width: 1,
          ),
        ),
      ),
    );
  }

  /// Construit un message texte simple avec markdown
  Widget _buildTextMessage(BuildContext context, Color textColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return MarkdownBody(
      data: message.content,
      selectable: true,
      onTapLink: (text, href, title) {
        if (href != null) {
          launchUrl(Uri.parse(href));
        }
      },
      styleSheet: _buildMarkdownStyleSheet(context, textColor, isDark),
      shrinkWrap: true,
    );
  }

  /// Construit un message avec un graphique
  Widget _buildGraphMessage(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Afficher le contenu mixte (code Python + texte)
        _buildMixedContent(context, textColor),
        const SizedBox(height: 12),
        // Placeholder pour le graphique
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bar_chart,
                  size: 48,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(height: 8),
                Text(
                  "Graphique généré",
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Visualisation basée sur les données",
                  style: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Construit un message avec un contenu multimédia (images, audio)
  Widget _buildMediaMessage(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Essayer de détecter et afficher les images dans le contenu
    if (_containsImages(message.content)) {
      return _buildMixedContent(
        context,
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
      );
    }

    // Vérifier si le contextInfo contient des pièces jointes
    if (message.contextInfo != null &&
        message.contextInfo!['attachments'] != null) {
      final attachments = message.contextInfo!['attachments'] as List<dynamic>;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final attachment in attachments)
            _buildAttachmentPreview(
              context,
              attachment as Map<String, dynamic>,
            ),
          if (message.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildTextMessage(
              context,
              Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
            ),
          ],
        ],
      );
    }

    // Fallback
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.attach_file,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Contenu multimédia",
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Construit la prévisualisation d'une pièce jointe
  Widget _buildAttachmentPreview(
    BuildContext context,
    Map<String, dynamic> attachment,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = attachment['name'] as String? ?? 'Fichier';
    final mimeType = attachment['mimeType'] as String? ?? '';

    IconData icon;
    if (mimeType.startsWith('image/')) {
      icon = Icons.image;
    } else if (mimeType.contains('pdf')) {
      icon = Icons.picture_as_pdf;
    } else if (mimeType.contains('word') || mimeType.contains('document')) {
      icon = Icons.description;
    } else if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) {
      icon = Icons.table_chart;
    } else {
      icon = Icons.insert_drive_file;
    }

    // Si c'est une image avec contenu base64, l'afficher
    if (mimeType.startsWith('image/') && attachment['content'] != null) {
      try {
        final bytes = base64Decode(attachment['content'] as String);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              fit: BoxFit.contain,
              errorBuilder:
                  (_, __, ___) => _buildFileChip(context, icon, name, isDark),
            ),
          ),
        );
      } catch (e) {
        // Fallback au chip de fichier
      }
    }

    return _buildFileChip(context, icon, name, isDark);
  }

  /// Construit un chip de fichier
  Widget _buildFileChip(
    BuildContext context,
    IconData icon,
    String name,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Construit l'avatar pour le message
  Widget _buildAvatar(bool isUser, bool isDark) {
    if (isUser) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[700] : Colors.grey[400],
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(Icons.person, size: 18, color: Colors.white),
      );
    }
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
    );
  }

  /// Construit l'action d'édition pour les messages de l'utilisateur
  Widget _buildEditAction(BuildContext context) {
    return _buildActionButton(
      icon: Icons.edit_outlined,
      tooltip: 'Modifier',
      color: Theme.of(
        context,
      ).textTheme.bodySmall?.color?.withAlpha((0.5 * 255).round()),
      onPressed: () {
        if (onEditMessage != null) {
          onEditMessage!(message);
        }
      },
    );
  }

  /// Construit les actions de feedback pour les messages d'Adha
  Widget _buildFeedbackActions(BuildContext context) {
    final iconColor = Theme.of(
      context,
    ).textTheme.bodySmall?.color?.withAlpha((0.5 * 255).round());
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton(
          icon: Icons.content_copy_outlined,
          tooltip: 'Copier',
          color: iconColor,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: message.content));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Copié'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
        _buildActionButton(
          icon: Icons.thumb_up_outlined,
          tooltip: 'Utile',
          color: iconColor,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Merci pour votre feedback'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
        _buildActionButton(
          icon: Icons.thumb_down_outlined,
          tooltip: 'Pas utile',
          color: iconColor,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Merci pour votre feedback'),
                duration: Duration(seconds: 1),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required Color? color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 16),
        color: color,
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }

  /// Formatte l'horodatage du message
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    if (messageDate == today) {
      // Aujourd'hui, affiche seulement l'heure
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      // Hier
      return 'Hier, ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      // Date complète
      return '${timestamp.day.toString().padLeft(2, '0')}/${timestamp.month.toString().padLeft(2, '0')}/${timestamp.year}, ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}
