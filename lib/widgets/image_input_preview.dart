import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImageInputPreview extends StatelessWidget {
  const ImageInputPreview({
    required this.selectedImagePath,
    required this.onImageSelected,
    required this.onImageRemoved,
    this.enabled = true,
    super.key,
  });

  final String? selectedImagePath;
  final ValueChanged<String> onImageSelected;
  final VoidCallback onImageRemoved;
  final bool enabled;

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        onImageSelected(pickedFile.path);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showImageSourceSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_rounded),
                  title: const Text('Take a photo'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(context, ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: const Text('Choose from gallery'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(context, ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (selectedImagePath != null && selectedImagePath!.isNotEmpty) {
      final file = File(selectedImagePath!);
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: file.existsSync()
                  ? Image.file(
                      file,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Center(
                            child: Text('Failed to load image preview'),
                          ),
                    )
                  : const Center(child: Text('Image file not found')),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.black87,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 18,
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                tooltip: 'Remove image',
                onPressed: enabled ? onImageRemoved : null,
              ),
            ),
          ),
        ],
      );
    }

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: enabled ? () => _showImageSourceSheet(context) : null,
      icon: const Icon(Icons.add_a_photo_outlined),
      label: const Text('Attach Image for Vision Analysis'),
    );
  }
}
