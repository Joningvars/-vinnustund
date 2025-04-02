import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/models/expense.dart';
import 'package:timagatt/providers/expenses_provider.dart';
import 'package:timagatt/providers/settings_provider.dart';
import 'package:timagatt/models/job.dart';

class EditExpenseScreen extends StatefulWidget {
  final Job job;
  final Expense expense;

  const EditExpenseScreen({Key? key, required this.job, required this.expense})
    : super(key: key);

  @override
  _EditExpenseScreenState createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.expense.amount.toString(),
    );
    _descriptionController = TextEditingController(
      text: widget.expense.description,
    );
    _selectedDate = widget.expense.date;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _updateExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final amount = double.parse(_amountController.text);
      final updatedExpense = widget.expense.copyWith(
        amount: amount,
        description: _descriptionController.text,
        date: _selectedDate,
      );

      await Provider.of<ExpensesProvider>(
        context,
        listen: false,
      ).updateExpense(updatedExpense);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Provider.of<SettingsProvider>(
                context,
                listen: false,
              ).translate('expenseUpdated'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating expense: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text(settingsProvider.translate('editExpense'))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: settingsProvider.translate('amount'),
                prefixText: 'kr ',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return settingsProvider.translate('amount') + ' is required';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: settingsProvider.translate('description'),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text(settingsProvider.translate('date')),
              subtitle: Text(
                '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDate(context),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _updateExpense,
              child:
                  _isLoading
                      ? const CircularProgressIndicator()
                      : Text(settingsProvider.translate('save')),
            ),
          ],
        ),
      ),
    );
  }
}
