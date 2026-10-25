import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/theme/app_colors.dart';
import '../models/inventory_item.dart';

class StockAdjustmentData {
  const StockAdjustmentData({
    required this.movementType,
    required this.quantity,
    required this.reason,
  });

  final String movementType;
  final String quantity;
  final String reason;
}

class StockAdjustmentDialog extends StatefulWidget {
  const StockAdjustmentDialog({
    super.key,
    required this.item,
  });

  final InventoryItem item;

  @override
  State<StockAdjustmentDialog> createState() =>
      _StockAdjustmentDialogState();
}

class _StockAdjustmentDialogState
    extends State<StockAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();

  final _quantityController = TextEditingController();
  final _reasonController = TextEditingController();

  String _movementType = 'adjustment_in';

  static const _movementTypes = <String, String>{
    'adjustment_in': 'Increase stock',
    'adjustment_out': 'Decrease stock',
    'damaged': 'Damaged goods',
    'returned': 'Customer return',
  };

  static final _quantityInputPattern =
      RegExp(r'^\d*(?:\.\d{0,3})?$');

  @override
  void dispose() {
    _quantityController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  String get _helpText {
    switch (_movementType) {
      case 'adjustment_in':
        return 'Adds to the recorded stock quantity.';
      case 'adjustment_out':
        return 'Removes stock from the available quantity.';
      case 'damaged':
        return 'Removes damaged goods from available stock.';
      case 'returned':
        return 'Adds returned goods back into stock.';
      default:
        return '';
    }
  }

  String? _validateQuantity(String? value) {
    final input = value?.trim() ?? '';

    if (input.isEmpty) {
      return 'Enter the quantity.';
    }

    if (!RegExp(r'^\d+(?:\.\d{1,3})?$')
        .hasMatch(input)) {
      return 'Enter a valid quantity with up to 3 decimals.';
    }

    final quantity = double.tryParse(input);

    if (quantity == null ||
        !quantity.isFinite ||
        quantity <= 0) {
      return 'Quantity must be greater than zero.';
    }

    if (_movementType == 'adjustment_out' ||
        _movementType == 'damaged') {
      if (quantity > widget.item.quantity) {
        return 'Quantity exceeds available stock.';
      }
    }

    return null;
  }

  String? _validateReason(String? value) {
    final reason = value?.trim() ?? '';

    if (reason.isEmpty) {
      return 'Enter a reason for this adjustment.';
    }

    if (reason.length > 500) {
      return 'Maximum 500 characters.';
    }

    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      StockAdjustmentData(
        movementType: _movementType,
        quantity: _quantityController.text.trim(),
        reason: _reasonController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return AlertDialog(
      title: const Text('Adjust stock'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  item.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Available: ${item.quantity.toStringAsFixed(3)} '
                  '${item.unit}',
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: _movementType,
                  decoration: const InputDecoration(
                    labelText: 'Adjustment type',
                  ),
                  items: _movementTypes.entries
                      .map(
                        (entry) => DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      _movementType = value;
                    });

                    _formKey.currentState?.validate();
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  _helpText,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _quantityController,
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    TextInputFormatter.withFunction(
                      (oldValue, newValue) {
                        if (_quantityInputPattern
                            .hasMatch(newValue.text)) {
                          return newValue;
                        }

                        return oldValue;
                      },
                    ),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    hintText: 'e.g. 2 or 1.500',
                    suffixText: item.unit,
                  ),
                  validator: _validateQuantity,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _reasonController,
                  maxLength: 500,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Reason (required)',
                    hintText: 'e.g. Stock count correction',
                  ),
                  validator: _validateReason,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Record adjustment'),
        ),
      ],
    );
  }
}