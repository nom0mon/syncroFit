import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart' as camera;

import '../../../core/platform/camera_permission.dart';
import '../../../core/theme/theme.dart';
import '../providers/progress_log_provider.dart';

class ProgressLogCreateScreen extends ConsumerStatefulWidget {
  const ProgressLogCreateScreen({super.key});

  @override
  ConsumerState<ProgressLogCreateScreen> createState() => _ProgressLogCreateScreenState();
}

class _ProgressLogCreateScreenState extends ConsumerState<ProgressLogCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _weight = TextEditingController();
  final _picker = ImagePicker();
  XFile? _image;
  Uint8List? _imageBytes;
  bool _saving = false;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _recoverLostImage();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _weight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Log Progress')),
        body: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                TextFormField(
                  controller: _title,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Enter a title.' : null,
                ),
                TextFormField(
                  controller: _description,
                  maxLength: 1000,
                  minLines: 3,
                  maxLines: 6,
                  decoration: const InputDecoration(labelText: 'Description'),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Enter a description.' : null,
                ),
                TextFormField(
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Current weight', suffixText: 'kg'),
                  validator: (value) {
                    final weight = double.tryParse(value ?? '');
                    return weight == null || weight < 20 || weight > 500
                        ? 'Enter a weight from 20 to 500 kg.'
                        : null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _imageBytes == null
                        ? const Center(child: Text('Add one progress photo'))
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _saving ? null : () => _select(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : () => _select(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Camera'),
                    ),
                  ],
                ),
                if (_saving) ...[
                  const SizedBox(height: AppSpacing.md),
                  LinearProgressIndicator(value: _progress == 0 ? null : _progress),
                ],
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Progress Log'),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _select(ImageSource source) async {
    if (source == ImageSource.camera &&
        !kIsWeb &&
        defaultTargetPlatform != TargetPlatform.android) {
      _showMessage('Camera capture is unavailable on this platform. Choose a gallery photo instead.');
      return;
    }
    if (source == ImageSource.camera &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android) {
      const coordinator = CameraPermissionCoordinator(AndroidCameraPermissionGateway());
      if (!await coordinator.requestAtPointOfUse(context)) return;
    }
    XFile? image;
    try {
      image = source == ImageSource.camera && kIsWeb
          ? await _captureChromeCamera()
          : await _picker.pickImage(
              source: source,
              maxWidth: 4096,
              maxHeight: 4096,
              imageQuality: 90,
            );
    } catch (error) {
      _showMessage(_cameraOrPickerError(source, error));
      return;
    }
    if (image == null || !mounted) return;
    final bytes = await image.readAsBytes();
    final extension = image.name.split('.').last.toLowerCase();
    final mimeType = image.mimeType?.toLowerCase();
    final allowedByName = const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension);
    final allowedByMime = const {'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType);
    final detectedFormat = _detectImageFormat(bytes);
    if (!allowedByName && !allowedByMime && detectedFormat == null) {
      _showMessage('Choose a JPEG, PNG, or WebP image.');
      return;
    }
    if (bytes.length > 5 * 1024 * 1024) {
      _showMessage('Choose an image smaller than 5 MB.');
      return;
    }
    if (!allowedByName) {
      final format = detectedFormat ?? _formatForMimeType(mimeType)!;
      image = XFile.fromData(
        bytes,
        mimeType: format.mimeType,
        name: 'progress-photo-${DateTime.now().millisecondsSinceEpoch}.${format.extension}',
      );
    }
    setState(() {
      _image = image;
      _imageBytes = bytes;
    });
  }

  Future<XFile?> _captureChromeCamera() async {
    final cameras = await camera.availableCameras();
    if (cameras.isEmpty) throw StateError('No camera was detected by Chrome.');
    final preferred = cameras.where(
      (item) => item.lensDirection == camera.CameraLensDirection.front,
    );
    if (!mounted) return null;
    return showDialog<XFile>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CameraCaptureDialog(
        description: preferred.isEmpty ? cameras.first : preferred.first,
      ),
    );
  }

  String _cameraOrPickerError(ImageSource source, Object error) {
    final detail = error.toString().toLowerCase();
    if (source == ImageSource.camera &&
        (detail.contains('notallowed') || detail.contains('permission'))) {
      return 'Chrome blocked camera access. Allow Camera for this site, reload the page, and try again.';
    }
    if (source == ImageSource.camera &&
        (detail.contains('notfound') || detail.contains('no camera'))) {
      return 'Chrome could not find an available camera.';
    }
    if (detail.contains('missingplugin')) {
      return 'The media plugin was added after this app started. Stop and restart the Chrome app, then try again.';
    }
    return source == ImageSource.camera
        ? 'Chrome could not start the camera. Reload the page and try again.'
        : 'The gallery picker could not open. Reload the page and try again.';
  }

  Future<void> _recoverLostImage() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final response = await _picker.retrieveLostData();
    if (response.isEmpty || response.files == null || response.files!.isEmpty) return;
    final image = response.files!.first;
    final bytes = await image.readAsBytes();
    if (!mounted || bytes.length > 5 * 1024 * 1024) return;
    setState(() {
      _image = image;
      _imageBytes = bytes;
    });
  }

  void _showMessage(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_image == null || _imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a progress photo.')));
      return;
    }
    setState(() { _saving = true; _progress = 0; });
    final error = await ref.read(progressLogsProvider.notifier).create(
      title: _title.text.trim(),
      description: _description.text.trim(),
      weightKg: double.parse(_weight.text),
      imageBytes: _imageBytes!,
      imageFilename: _image!.name,
      onProgress: (sent, total) {
        if (mounted && total > 0) setState(() => _progress = sent / total);
      },
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (error == null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

({String extension, String mimeType})? _detectImageFormat(Uint8List bytes) {
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return (extension: 'jpg', mimeType: 'image/jpeg');
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47 &&
      bytes[4] == 0x0d &&
      bytes[5] == 0x0a &&
      bytes[6] == 0x1a &&
      bytes[7] == 0x0a) {
    return (extension: 'png', mimeType: 'image/png');
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return (extension: 'webp', mimeType: 'image/webp');
  }
  return null;
}

({String extension, String mimeType})? _formatForMimeType(String? mimeType) {
  return switch (mimeType) {
    'image/jpeg' => (extension: 'jpg', mimeType: 'image/jpeg'),
    'image/png' => (extension: 'png', mimeType: 'image/png'),
    'image/webp' => (extension: 'webp', mimeType: 'image/webp'),
    _ => null,
  };
}

class _CameraCaptureDialog extends StatefulWidget {
  const _CameraCaptureDialog({required this.description});

  final camera.CameraDescription description;

  @override
  State<_CameraCaptureDialog> createState() => _CameraCaptureDialogState();
}

class _CameraCaptureDialogState extends State<_CameraCaptureDialog> {
  late final camera.CameraController _controller;
  late final Future<void> _initialization;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _controller = camera.CameraController(
      widget.description,
      camera.ResolutionPreset.medium,
      enableAudio: false,
    );
    _initialization = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Take progress photo'),
      content: SizedBox(
        width: 520,
        child: FutureBuilder<void>(
          future: _initialization,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(child: Text('Chrome could not start the camera.')),
              );
            }
            if (snapshot.connectionState != ConnectionState.done ||
                !_controller.value.isInitialized) {
              return const AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: camera.CameraPreview(_controller),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _capturing ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _capturing ? null : _capture,
          icon: _capturing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.camera_alt),
          label: const Text('Capture'),
        ),
      ],
    );
  }

  Future<void> _capture() async {
    try {
      await _initialization;
      if (!mounted || !_controller.value.isInitialized) return;
      setState(() => _capturing = true);
      final captured = await _controller.takePicture();
      if (mounted) Navigator.pop(context, captured);
    } catch (error) {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not capture photo: $error')),
      );
    }
  }
}
