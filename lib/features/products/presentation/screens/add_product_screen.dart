/// lib/features/products/presentation/screens/add_product_screen.dart
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/providers/cached_providers.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});
  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _catCtrl = TextEditingController();
  File? _imageFile;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _stockCtrl.dispose();
    _catCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);

      // Upload image first if selected
      String? imageUrl;
      if (_imageFile != null) {
        final formData = FormData.fromMap({
          'image': await MultipartFile.fromFile(_imageFile!.path),
        });
        final imgResp = await api.post('/products/upload-image', data: formData);
        imageUrl = (imgResp.data as Map<String, dynamic>)['url'] as String?;
      }

      await api.post('/products', data: {
        'name': _nameCtrl.text.trim(),
        'price': double.parse(_priceCtrl.text.trim()),
        if (_descCtrl.text.isNotEmpty) 'description': _descCtrl.text.trim(),
        if (_stockCtrl.text.isNotEmpty) 'stock': int.parse(_stockCtrl.text.trim()),
        if (_catCtrl.text.isNotEmpty) 'category': _catCtrl.text.trim(),
        if (imageUrl != null) 'image_url': imageUrl,
      });

      ref.invalidate(cachedProductsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(apiErrorMessage(e)),
          backgroundColor: WaziBotColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Add Product')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Image picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: theme.colorScheme.outline,
                      style: BorderStyle.solid),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_imageFile!, fit: BoxFit.cover,
                            width: double.infinity))
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 40,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text('Tap to add photo',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ]),
              ),
            ),
            const SizedBox(height: 20),

            _label(context, 'Product Name *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(hintText: 'e.g. Classic Burger'),
              validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
            ),
            const SizedBox(height: 14),

            _label(context, 'Price (USD) *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  hintText: '0.00', prefixText: r'$ '),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Price required';
                if (double.tryParse(v.trim()) == null) return 'Invalid price';
                return null;
              },
            ),
            const SizedBox(height: 14),

            _label(context, 'Description'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Short product description'),
            ),
            const SizedBox(height: 14),

            Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(context, 'Stock'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _stockCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Optional'),
                    validator: (v) {
                      if (v != null && v.isNotEmpty && int.tryParse(v) == null) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ],
              )),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(context, 'Category'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _catCtrl,
                    decoration: const InputDecoration(hintText: 'e.g. Food'),
                  ),
                ],
              )),
            ]),
            const SizedBox(height: 28),

            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Text('Add Product'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant),
      );
}

// Placeholder for Dio FormData — real import in pubspec
class FormData {
  final Map<String, dynamic> fields;
  FormData.fromMap(this.fields);
}

class MultipartFile {
  static Future<MultipartFile> fromFile(String path) async => MultipartFile();
}
