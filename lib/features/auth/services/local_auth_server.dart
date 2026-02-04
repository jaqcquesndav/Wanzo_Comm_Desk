import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Serveur HTTP local temporaire pour capturer le callback OAuth
///
/// Cette classe implémente le flux OAuth "Authorization Code" sécurisé pour
/// les applications desktop. Elle :
/// 1. Démarre un serveur HTTP local sur un port disponible
/// 2. Attend le callback d'Auth0 avec le code d'autorisation
/// 3. Retourne le code pour l'échanger contre des tokens
/// 4. Affiche une page de succès à l'utilisateur
///
/// C'est la méthode recommandée utilisée par VS Code, Slack, Spotify Desktop, etc.
class LocalAuthServer {
  HttpServer? _server;
  final Completer<AuthorizationResponse> _completer =
      Completer<AuthorizationResponse>();

  /// Port sur lequel le serveur écoute (0 = port automatique)
  int? _port;

  /// Timeout pour l'attente du callback (défaut: 5 minutes)
  final Duration timeout;

  LocalAuthServer({this.timeout = const Duration(minutes: 5)});

  /// Retourne l'URL de callback à utiliser pour Auth0
  String get callbackUrl => 'http://localhost:$_port/callback';

  /// Retourne le port utilisé par le serveur
  int? get port => _port;

  /// Démarre le serveur et attend le callback OAuth
  ///
  /// Retourne un [AuthorizationResponse] contenant le code d'autorisation
  /// ou une erreur si l'authentification a échoué.
  Future<AuthorizationResponse> startAndWaitForCallback() async {
    try {
      // Trouver un port disponible
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;

      debugPrint('LocalAuthServer: Started on port $_port');
      debugPrint('LocalAuthServer: Callback URL: $callbackUrl');

      // Configurer le timeout
      Timer? timeoutTimer;
      timeoutTimer = Timer(timeout, () {
        if (!_completer.isCompleted) {
          _completer.completeError(
            LocalAuthServerException(
              'Authentication timed out after ${timeout.inMinutes} minutes',
            ),
          );
          stop();
        }
      });

      // Écouter les requêtes
      _server!.listen((HttpRequest request) async {
        debugPrint('LocalAuthServer: Received request: ${request.uri.path}');

        if (request.uri.path == '/callback') {
          await _handleCallback(request);
          timeoutTimer?.cancel();
        } else if (request.uri.path == '/favicon.ico') {
          // Ignorer les requêtes favicon
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        } else {
          // Requête inconnue
          request.response.statusCode = HttpStatus.notFound;
          request.response.write('Not found');
          await request.response.close();
        }
      });

      return await _completer.future;
    } catch (e) {
      debugPrint('LocalAuthServer: Error starting server: $e');
      rethrow;
    }
  }

  /// Gère le callback OAuth
  Future<void> _handleCallback(HttpRequest request) async {
    final uri = request.uri;
    final queryParams = uri.queryParameters;

    debugPrint(
      'LocalAuthServer: Processing callback with params: ${queryParams.keys.toList()}',
    );

    // Vérifier s'il y a une erreur
    if (queryParams.containsKey('error')) {
      final error = queryParams['error']!;
      final errorDescription =
          queryParams['error_description'] ?? 'Unknown error';

      debugPrint('LocalAuthServer: OAuth error: $error - $errorDescription');

      // Afficher une page d'erreur
      await _sendErrorPage(request, error, errorDescription);

      if (!_completer.isCompleted) {
        _completer.complete(
          AuthorizationResponse.error(error, errorDescription),
        );
      }

      // Arrêter le serveur après un délai
      Future.delayed(const Duration(seconds: 2), stop);
      return;
    }

    // Récupérer le code d'autorisation
    final code = queryParams['code'];
    final state = queryParams['state'];

    if (code == null) {
      debugPrint('LocalAuthServer: No authorization code in callback');
      await _sendErrorPage(
        request,
        'missing_code',
        'No authorization code received',
      );

      if (!_completer.isCompleted) {
        _completer.complete(
          AuthorizationResponse.error(
            'missing_code',
            'No authorization code received',
          ),
        );
      }

      Future.delayed(const Duration(seconds: 2), stop);
      return;
    }

    debugPrint('LocalAuthServer: Received authorization code');

    // Afficher une page de succès
    await _sendSuccessPage(request);

    if (!_completer.isCompleted) {
      _completer.complete(AuthorizationResponse.success(code, state: state));
    }

    // Arrêter le serveur après un délai pour que la page s'affiche
    Future.delayed(const Duration(seconds: 2), stop);
  }

  /// Envoie une page HTML de succès
  Future<void> _sendSuccessPage(HttpRequest request) async {
    const html = '''
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Wanzo - Connexion réussie</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            background: white;
            padding: 3rem;
            border-radius: 1rem;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
            text-align: center;
            max-width: 400px;
        }
        .icon {
            width: 80px;
            height: 80px;
            background: #10b981;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 1.5rem;
        }
        .icon svg {
            width: 40px;
            height: 40px;
            fill: white;
        }
        h1 {
            color: #1f2937;
            font-size: 1.5rem;
            margin-bottom: 0.5rem;
        }
        p {
            color: #6b7280;
            margin-bottom: 1.5rem;
        }
        .close-hint {
            font-size: 0.875rem;
            color: #9ca3af;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">
            <svg viewBox="0 0 24 24"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>
        </div>
        <h1>Connexion réussie !</h1>
        <p>Vous êtes maintenant connecté à Wanzo.</p>
        <p class="close-hint">Vous pouvez fermer cette fenêtre et retourner à l'application.</p>
    </div>
    <script>
        // Tenter de fermer automatiquement après 3 secondes
        setTimeout(() => { window.close(); }, 3000);
    </script>
</body>
</html>
''';

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.html;
    request.response.write(html);
    await request.response.close();
  }

  /// Envoie une page HTML d'erreur
  Future<void> _sendErrorPage(
    HttpRequest request,
    String error,
    String description,
  ) async {
    final html = '''
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Wanzo - Erreur de connexion</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #ef4444 0%, #dc2626 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .container {
            background: white;
            padding: 3rem;
            border-radius: 1rem;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
            text-align: center;
            max-width: 400px;
        }
        .icon {
            width: 80px;
            height: 80px;
            background: #ef4444;
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 1.5rem;
        }
        .icon svg {
            width: 40px;
            height: 40px;
            fill: white;
        }
        h1 {
            color: #1f2937;
            font-size: 1.5rem;
            margin-bottom: 0.5rem;
        }
        p {
            color: #6b7280;
            margin-bottom: 1rem;
        }
        .error-code {
            font-family: monospace;
            background: #f3f4f6;
            padding: 0.5rem 1rem;
            border-radius: 0.25rem;
            font-size: 0.875rem;
            color: #ef4444;
        }
        .close-hint {
            font-size: 0.875rem;
            color: #9ca3af;
            margin-top: 1.5rem;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">
            <svg viewBox="0 0 24 24"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>
        </div>
        <h1>Erreur de connexion</h1>
        <p>${_escapeHtml(description)}</p>
        <div class="error-code">$error</div>
        <p class="close-hint">Veuillez fermer cette fenêtre et réessayer.</p>
    </div>
</body>
</html>
''';

    request.response.statusCode = HttpStatus.ok;
    request.response.headers.contentType = ContentType.html;
    request.response.write(html);
    await request.response.close();
  }

  /// Échappe les caractères HTML dangereux
  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#039;');
  }

  /// Arrête le serveur
  Future<void> stop() async {
    if (_server != null) {
      debugPrint('LocalAuthServer: Stopping server');
      await _server!.close(force: true);
      _server = null;
      _port = null;
    }
  }
}

/// Réponse d'autorisation OAuth
class AuthorizationResponse {
  /// Code d'autorisation (si succès)
  final String? code;

  /// State parameter (si fourni)
  final String? state;

  /// Code d'erreur (si échec)
  final String? error;

  /// Description de l'erreur (si échec)
  final String? errorDescription;

  /// Indique si l'autorisation a réussi
  bool get isSuccess => code != null && error == null;

  /// Indique si l'utilisateur a annulé
  bool get isCancelled => error == 'access_denied' || error == 'user_cancelled';

  AuthorizationResponse._({
    this.code,
    this.state,
    this.error,
    this.errorDescription,
  });

  /// Crée une réponse de succès
  factory AuthorizationResponse.success(String code, {String? state}) {
    return AuthorizationResponse._(code: code, state: state);
  }

  /// Crée une réponse d'erreur
  factory AuthorizationResponse.error(String error, String description) {
    return AuthorizationResponse._(error: error, errorDescription: description);
  }

  @override
  String toString() {
    if (isSuccess) {
      return 'AuthorizationResponse.success(code: ${code?.substring(0, 10)}...)';
    } else {
      return 'AuthorizationResponse.error($error: $errorDescription)';
    }
  }
}

/// Exception pour les erreurs du serveur d'authentification local
class LocalAuthServerException implements Exception {
  final String message;

  LocalAuthServerException(this.message);

  @override
  String toString() => 'LocalAuthServerException: $message';
}
