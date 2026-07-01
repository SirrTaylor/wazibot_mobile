/// lib/features/products/presentation/screens/edit_product_screen.dart
/// Feature 5: Edit product — PATCH /products/{id}
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../shared/models/business_models.dart';
import '../../../../shared/providers/cached_providers.dart';

class EditProductScreen extends ConsumerStatefulWidget {
  final Product product;
  const EditProductScreen({super.key, required this.product});

  @override
  ConsumerState<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends ConsumerState<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _catCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p.name);
    _priceCtrl = TextEditingController(text: p.price.toString());
    _descCtrl = TextEditingController(text: p.description ?? '');
    _stockCtrl = TextEditingController(
        text: p.stock != null ? p.stock.toString() : '');
    _catCtrl = TextEditingController(text: p.category ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    _stockCtrl.dispose();
    _catCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      final body = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'price': double.parse(_priceCtrl.text.trim()),
        if (_descCtrl.text.isNotEmpty) 'description': _descCtrl.text.trim(),
        if (_stockCtrl.text.isNotEmpty) 'stock': int.parse(_stockCtrl.text.trim()),
        if (_catCtrl.text.isNotEmpty) 'category': _catCtrl.text.trim(),
      };
      await api.patch('/products/${widget.product.id}', data: body);
      await Haptics.success();
      ref.invalidate(cachedProductsProvider);
      if (mounted) context.pop();
    } catch (e) {
      await Haptics.error();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Product'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: WaziBotColors.primary))
                : const Text('Save',
                    style: TextStyle(color: WaziBotColors.primary,
                        fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _label(context, 'Product Name *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(hintText: 'e.g. Classic Burger'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name required' : null,
            ),
            const SizedBox(height: 14),

            _label(context, 'Price *'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _priceCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
              decoration: const InputDecoration(hintText: 'Optional description'),
            ),
            const SizedBox(height: 14),

            Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(context, 'Stock'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Optional'),
                      validator: (v) {
                        if (v != null &&
                            v.isNotEmpty &&
                            int.tryParse(v) == null) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(context, 'Category'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _catCtrl,
                      decoration: const InputDecoration(hintText: 'e.g. Food'),
                    ),
                  ],
                ),
              ),
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
                  : const Text('Save Changes'),
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
