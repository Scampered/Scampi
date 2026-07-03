import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_typography.dart';

/// Take-a-photo / choose-from-gallery control for the AI import screens.
/// Shows a thumbnail + remove button once a photo is picked.
class AiPhotoPicker extends StatelessWidget {
  const AiPhotoPicker({super.key, required this.image, required this.onChanged});

  final File? image;
  final ValueChanged<File?> onChanged;

  Future<void> _pick(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) onChanged(File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    if (image != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: ScampiRadius.mdBorder,
            child: Image.file(image!, height: 200, width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: ScampiSpacing.xxs),
          TextButton.icon(
            onPressed: () => onChanged(null),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Remove photo'),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pick(ImageSource.camera),
            icon: const Icon(Icons.photo_camera_rounded),
            label: const Text('Take Photo'),
          ),
        ),
        const SizedBox(width: ScampiSpacing.xs),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pick(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_rounded),
            label: const Text('Choose Photo'),
          ),
        ),
      ],
    );
  }
}

/// Opens the Android/iOS share sheet with the photo attached and the
/// prompt as the share text, letting the user pick ChatGPT, Gemini,
/// Claude, or whatever else is installed. Far more reliable than trying to
/// deep-link into a specific app by URL — it works regardless of whether
/// that app has verified web app-links on this device, and it's the only
/// way to hand off an image without a live API integration.
Future<void> shareAiPhoto(File image, String prompt) async {
  await Share.shareXFiles([XFile(image.path)], text: prompt);
}

/// Same idea as [shareAiPhoto] but for a text-only description (no
/// photo) — used when the user just types what they ate instead of
/// snapping a picture.
Future<void> shareAiText(String prompt) async {
  await Share.share(prompt);
}
