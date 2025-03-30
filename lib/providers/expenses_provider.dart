import 'package:flutter/material.dart';
import '../models/expense.dart';
import '../services/database_service.dart';

class ExpensesProvider with ChangeNotifier {
  final DatabaseService _databaseService;
  List<Expense> _expenses = [];
  bool _isLoading = false;

  ExpensesProvider(this._databaseService);

  List<Expense> get expenses => _expenses;
  bool get isLoading => _isLoading;

  Future<void> loadExpensesForJob(String jobId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final expenses = await _databaseService.getExpensesForJob(jobId);
      _expenses = expenses;
    } catch (e) {
      debugPrint('Error loading expenses: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addExpense(Expense expense) async {
    try {
      await _databaseService.addExpense(expense);
      _expenses.add(expense);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding expense: $e');
      rethrow;
    }
  }

  Future<void> updateExpense(Expense expense) async {
    try {
      await _databaseService.updateExpense(expense);
      final index = _expenses.indexWhere((e) => e.id == expense.id);
      if (index != -1) {
        _expenses[index] = expense;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error updating expense: $e');
      rethrow;
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    try {
      await _databaseService.deleteExpense(expenseId);
      _expenses.removeWhere((e) => e.id == expenseId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting expense: $e');
      rethrow;
    }
  }

  double getTotalExpenses() {
    return _expenses.fold(0, (sum, expense) => sum + expense.amount);
  }

  List<Expense> getExpensesByUser(String userId) {
    return _expenses.where((e) => e.userId == userId).toList();
  }

  List<Expense> getExpensesByDateRange(DateTime start, DateTime end) {
    return _expenses
        .where(
          (e) =>
              e.date.isAfter(start.subtract(const Duration(days: 1))) &&
              e.date.isBefore(end.add(const Duration(days: 1))),
        )
        .toList();
  }
}
