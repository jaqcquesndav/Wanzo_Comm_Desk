import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

/// Rognage de la photo de profil.
///
/// Le module de rognage (image_cropper) n'existe que sur Android, iOS et web :
/// sur le poste (Windows, Linux, macOS) son appel levait une exception non
/// interceptée et la photo choisie n'était jamais appliquée. Sur ordinateur,
/// l'image choisie est donc gardée telle quelle ; ailleurs, un échec du
/// rognage garde aussi l'image d'origine plutôt que de l'abandonner.
///
/// Renvoie null seulement si l'utilisateur annule le rognage.
Future<File?> cropProfileImage(
  String sourcePath, {
  required Color toolbarColor,
  CropAspectRatioPreset initAspectRatio = CropAspectRatioPreset.original,
}) async {
  if (isDesktopCropUnsupported) return File(sourcePath);
  try {
    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Rogner l\'image',
          toolbarColor: toolbarColor,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: initAspectRatio,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Rogner l\'image',
          minimumAspectRatio: 1.0,
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
        ),
      ],
    );
    return cropped == null ? null : File(cropped.path);
  } catch (e) {
    debugPrint('cropProfileImage: rognage indisponible, image gardée ($e)');
    return File(sourcePath);
  }
}

/// Vrai sur ordinateur, où le rognage n'est pas proposé.
bool get isDesktopCropUnsupported =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
