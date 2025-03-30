import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/job.dart';
import '../models/time_entry.dart';
import '../models/expense.dart';
import '../providers/jobs_provider.dart';
import '../providers/time_entries_provider.dart';
import '../providers/expenses_provider.dart';
import '../services/database_service.dart';
import '../widgets/time_entry_card.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/common/styled_dropdown.dart';

class JobOverviewScreen extends StatefulWidget {
  final Job job;

  const JobOverviewScreen({Key? key, required this.job}) : super(key: key);

  @override
  State<JobOverviewScreen> createState() => _JobOverviewScreenState();
}

class _JobOverviewScreenState extends State<JobOverviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<TimeEntry> _entries = [];
  List<Expense> _expenses = [];
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedUserId;
  List<String> _userIds = [];
  List<String> _userNames = [];

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Add listener to track tab changes
    _tabController.addListener(() {
      setState(() {}); // Force rebuild when tab changes
    });

    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final databaseService = Provider.of<DatabaseService>(
        context,
        listen: false,
      );
      final entries = await databaseService.getTimeEntriesForJob(widget.job.id);
      final expenses = await databaseService.getExpensesForJob(widget.job.id);

      setState(() {
        _entries = entries;
        _expenses = expenses;
        _userIds = entries.map((e) => e.userId).toSet().toList();
        _userNames =
            entries.map((e) => e.userName ?? 'Unknown').toSet().toList();
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<TimeEntry> _getFilteredEntries() {
    var filtered = _entries;

    if (_startDate != null) {
      filtered = filtered.where((e) => e.date.isAfter(_startDate!)).toList();
    }
    if (_endDate != null) {
      filtered = filtered.where((e) => e.date.isBefore(_endDate!)).toList();
    }
    if (_selectedUserId != null) {
      filtered = filtered.where((e) => e.userId == _selectedUserId).toList();
    }

    return filtered;
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
        end: _endDate ?? DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: DatePickerThemeData(
              backgroundColor: const Color(0xFF1E1E1E),
              headerBackgroundColor: Colors.blue,
              headerForegroundColor: Colors.white,
              dayStyle: const TextStyle(color: Colors.white),
              yearStyle: const TextStyle(color: Colors.white),
              todayBackgroundColor: MaterialStateProperty.all(
                Colors.blue.withOpacity(0.2),
              ),
              todayForegroundColor: MaterialStateProperty.all(Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            dialogBackgroundColor: const Color(0xFF1E1E1E),
            dialogTheme: DialogTheme(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _addExpense() async {
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(
      context,
      listen: false,
    );
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header with icon
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.receipt_long_outlined,
                              color: Colors.blue.shade700,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Title
                          Text(
                            timeEntriesProvider.translate('addExpense'),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),

                          // Subtitle
                          Text(
                            timeEntriesProvider.translate(
                              'enterExpenseDetails',
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // Description field
                          TextField(
                            controller: descriptionController,
                            decoration: InputDecoration(
                              hintText: timeEntriesProvider.translate(
                                'description',
                              ),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),

                          // Amount field
                          TextField(
                            controller: amountController,
                            decoration: InputDecoration(
                              hintText: timeEntriesProvider.translate('amount'),
                              prefixText: 'kr ',
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),

                          // Date picker
                          OutlinedButton.icon(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() => selectedDate = date);
                              }
                            },
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(
                              DateFormat.yMMMd().format(selectedDate),
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(
                                  timeEntriesProvider.translate('cancel'),
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  timeEntriesProvider.translate('add'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    );

    if (result == true) {
      final description = descriptionController.text;
      final amount = double.tryParse(amountController.text) ?? 0.0;

      if (description.isNotEmpty && amount > 0) {
        // Get the user's display name from Firestore if not available
        String userName = currentUser.displayName ?? 'Unknown';
        if (userName == 'Unknown') {
          final userDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .get();
          if (userDoc.exists && userDoc.data()?['name'] != null) {
            userName = userDoc.data()?['name'];
          }
        }

        final expense = Expense(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          jobId: widget.job.id,
          description: description,
          amount: amount,
          date: selectedDate,
          userId: currentUser.uid,
          userName: userName,
        );

        try {
          await Provider.of<ExpensesProvider>(
            context,
            listen: false,
          ).addExpense(expense);

          // Refresh the expenses list
          final databaseService = Provider.of<DatabaseService>(
            context,
            listen: false,
          );
          final updatedExpenses = await databaseService.getExpensesForJob(
            widget.job.id,
          );

          if (mounted) {
            setState(() {
              _expenses = updatedExpenses;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(timeEntriesProvider.translate('expenseAdded')),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  timeEntriesProvider.translate('errorSavingEntry'),
                ),
              ),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.job.name,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
      ),
      floatingActionButton:
          _tabController.index == 1
              ? FloatingActionButton(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                onPressed: _addExpense,
                child: const Icon(Icons.add),
              )
              : null,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(
                        text: Provider.of<TimeEntriesProvider>(
                          context,
                        ).translate('timeEntries'),
                      ),
                      Tab(
                        text: Provider.of<TimeEntriesProvider>(
                          context,
                        ).translate('expenses'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [_buildTimeEntriesTab(), _buildExpensesTab()],
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildTimeEntriesTab() {
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(context);
    final filteredEntries = _getFilteredEntries();

    // Calculate total hours for filtered entries
    double totalHours = 0;
    for (var entry in filteredEntries) {
      totalHours +=
          entry.duration.inHours + (entry.duration.inMinutes % 60) / 60;
    }

    return Column(
      children: [
        // Filters row
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectDateRange,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _startDate != null && _endDate != null
                              ? '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d').format(_endDate!)}'
                              : timeEntriesProvider.translate(
                                'selectDateRange',
                              ),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_userIds.isNotEmpty)
                Expanded(
                  child: StyledDropdown<String?>(
                    value: _selectedUserId,
                    onChanged: (String? value) {
                      setState(() {
                        _selectedUserId = value;
                      });
                    },
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(timeEntriesProvider.translate('allUsers')),
                      ),
                      ..._userIds.asMap().entries.map((entry) {
                        return DropdownMenuItem<String?>(
                          value: entry.value,
                          child: Text(_userNames[entry.key]),
                        );
                      }),
                    ],
                    hint: timeEntriesProvider.translate('filterByUser'),
                  ),
                ),
            ],
          ),
        ),

        // Total hours summary
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                timeEntriesProvider.translate('totalHours') + ':',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              Text(
                '${totalHours.toStringAsFixed(1)} ${timeEntriesProvider.translate('hours')}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Time entries list
        Expanded(
          child:
              filteredEntries.isEmpty
                  ? Center(
                    child: Text(
                      timeEntriesProvider.translate('noEntries'),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredEntries.length,
                    itemBuilder: (context, index) {
                      final entry = filteredEntries[index];
                      final showDateHeader =
                          index == 0 ||
                          !isSameDay(
                            filteredEntries[index - 1].date,
                            entry.date,
                          );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showDateHeader) ...[
                            const SizedBox(height: 16),
                            Text(
                              DateFormat.yMMMd().format(entry.date),
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          TimeEntryCard(entry: entry),
                        ],
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildExpensesTab() {
    final expensesProvider = Provider.of<ExpensesProvider>(context);
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(context);
    final filteredExpenses =
        _expenses.where((e) {
          if (_startDate != null && e.date.isBefore(_startDate!)) return false;
          if (_endDate != null && e.date.isAfter(_endDate!)) return false;
          if (_selectedUserId != null && e.userId != _selectedUserId)
            return false;
          return true;
        }).toList();

    // Format number with thousand separator
    String formatAmount(double amount) {
      final formatter = NumberFormat('#,##0', 'is_IS');
      return '${formatter.format(amount)} kr';
    }

    return Column(
      children: [
        // Filters row
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectDateRange,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _startDate != null && _endDate != null
                              ? '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d').format(_endDate!)}'
                              : timeEntriesProvider.translate(
                                'selectDateRange',
                              ),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_userIds.isNotEmpty)
                Expanded(
                  child: StyledDropdown<String?>(
                    value: _selectedUserId,
                    onChanged: (String? value) {
                      setState(() {
                        _selectedUserId = value;
                      });
                    },
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(timeEntriesProvider.translate('allUsers')),
                      ),
                      ..._userIds.asMap().entries.map((entry) {
                        return DropdownMenuItem<String?>(
                          value: entry.value,
                          child: Text(_userNames[entry.key]),
                        );
                      }),
                    ],
                    hint: timeEntriesProvider.translate('filterByUser'),
                  ),
                ),
            ],
          ),
        ),

        // Total expenses summary
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                timeEntriesProvider.translate('totalExpenses') + ':',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
              Text(
                formatAmount(
                  filteredExpenses.fold(0.0, (sum, e) => sum + e.amount),
                ),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Expenses list
        Expanded(
          child:
              filteredExpenses.isEmpty
                  ? Center(
                    child: Text(
                      timeEntriesProvider.translate('noExpenses'),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredExpenses.length,
                    itemBuilder: (context, index) {
                      final expense = filteredExpenses[index];
                      final showDateHeader =
                          index == 0 ||
                          !isSameDay(
                            filteredExpenses[index - 1].date,
                            expense.date,
                          );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showDateHeader) ...[
                            const SizedBox(height: 16),
                            Text(
                              DateFormat.yMMMd().format(expense.date),
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 0,
                            color: Theme.of(context).cardTheme.color,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListTile(
                              title: Text(
                                expense.description,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              subtitle: Text(
                                '${expense.userName ?? 'Unknown'}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                              trailing: Text(
                                formatAmount(expense.amount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              onTap: () => _editExpense(expense),
                              onLongPress: () => _deleteExpense(expense),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Future<void> _deleteExpense(Expense expense) async {
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(
      context,
      listen: false,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade700,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    timeEntriesProvider.translate('deleteExpense'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    timeEntriesProvider.translate('deleteExpenseConfirm'),
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          timeEntriesProvider.translate('cancel'),
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(timeEntriesProvider.translate('delete')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
    );

    if (confirmed == true) {
      try {
        await Provider.of<ExpensesProvider>(
          context,
          listen: false,
        ).deleteExpense(expense.id);

        // Refresh the expenses list
        final databaseService = Provider.of<DatabaseService>(
          context,
          listen: false,
        );
        final updatedExpenses = await databaseService.getExpensesForJob(
          widget.job.id,
        );

        if (mounted) {
          setState(() {
            _expenses = updatedExpenses;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(timeEntriesProvider.translate('expenseDeleted')),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                timeEntriesProvider.translate('errorDeletingExpense'),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _editExpense(Expense expense) async {
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(
      context,
      listen: false,
    );
    final TextEditingController descriptionController = TextEditingController(
      text: expense.description,
    );
    final TextEditingController amountController = TextEditingController(
      text: expense.amount.toString(),
    );
    DateTime selectedDate = expense.date;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  child: SingleChildScrollView(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header with icon
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.edit_outlined,
                              color: Colors.blue.shade700,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Title
                          Text(
                            timeEntriesProvider.translate('editExpense'),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),

                          // Subtitle
                          Text(
                            timeEntriesProvider.translate('editExpenseDetails'),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // Description field
                          TextField(
                            controller: descriptionController,
                            decoration: InputDecoration(
                              hintText: timeEntriesProvider.translate(
                                'description',
                              ),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 16),

                          // Amount field
                          TextField(
                            controller: amountController,
                            decoration: InputDecoration(
                              hintText: timeEntriesProvider.translate('amount'),
                              prefixText: 'kr ',
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),

                          // Date picker
                          OutlinedButton.icon(
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() => selectedDate = date);
                              }
                            },
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(
                              DateFormat.yMMMd().format(selectedDate),
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(
                                  timeEntriesProvider.translate('cancel'),
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  timeEntriesProvider.translate('save'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    );

    if (result == true) {
      final description = descriptionController.text;
      final amount = double.tryParse(amountController.text) ?? 0.0;

      if (description.isNotEmpty && amount > 0) {
        final updatedExpense = Expense(
          id: expense.id,
          jobId: expense.jobId,
          description: description,
          amount: amount,
          date: selectedDate,
          userId: expense.userId,
          userName: expense.userName,
        );

        try {
          await Provider.of<ExpensesProvider>(
            context,
            listen: false,
          ).updateExpense(updatedExpense);

          // Refresh the expenses list
          final databaseService = Provider.of<DatabaseService>(
            context,
            listen: false,
          );
          final updatedExpenses = await databaseService.getExpensesForJob(
            widget.job.id,
          );

          if (mounted) {
            setState(() {
              _expenses = updatedExpenses;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(timeEntriesProvider.translate('expenseUpdated')),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  timeEntriesProvider.translate('errorUpdatingExpense'),
                ),
              ),
            );
          }
        }
      }
    }
  }
}
