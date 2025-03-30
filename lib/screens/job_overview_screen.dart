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
  bool _isEditing = false;
  List<TimeEntry> _entriesToDelete = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _addExpense() async {
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController amountController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              Provider.of<TimeEntriesProvider>(context).translate('addExpense'),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: Provider.of<TimeEntriesProvider>(
                      context,
                    ).translate('description'),
                  ),
                ),
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: Provider.of<TimeEntriesProvider>(
                      context,
                    ).translate('amount'),
                  ),
                  keyboardType: TextInputType.number,
                ),
                ListTile(
                  title: Text(
                    Provider.of<TimeEntriesProvider>(context).translate('date'),
                  ),
                  subtitle: Text(DateFormat.yMMMd().format(selectedDate)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      selectedDate = date;
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  Provider.of<TimeEntriesProvider>(context).translate('cancel'),
                ),
              ),
              TextButton(
                onPressed: () async {
                  if (descriptionController.text.isNotEmpty &&
                      amountController.text.isNotEmpty) {
                    final currentUser = FirebaseAuth.instance.currentUser;
                    final expense = Expense(
                      id: const Uuid().v4(),
                      jobId: widget.job.id,
                      description: descriptionController.text,
                      amount: double.parse(amountController.text),
                      date: selectedDate,
                      userId: currentUser?.uid ?? '',
                      userName: currentUser?.displayName ?? 'Unknown',
                    );

                    try {
                      await Provider.of<ExpensesProvider>(
                        context,
                        listen: false,
                      ).addExpense(expense);
                      Navigator.pop(context);
                      _loadData();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            Provider.of<TimeEntriesProvider>(
                              context,
                            ).translate('errorSavingEntry'),
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: Text(
                  Provider.of<TimeEntriesProvider>(context).translate('add'),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.job.name),
        actions: [
          if (widget.job.creatorId == FirebaseAuth.instance.currentUser?.uid)
            IconButton(
              icon: Icon(_isEditing ? Icons.check : Icons.edit),
              onPressed: () {
                setState(() {
                  if (_isEditing) {
                    // Save changes
                    _deleteSelectedEntries();
                  }
                  _isEditing = !_isEditing;
                  if (!_isEditing) {
                    _entriesToDelete.clear();
                  }
                });
              },
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(text: 'Time Entries'),
                      Tab(text: 'Expenses'),
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
                child: OutlinedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    _startDate != null && _endDate != null
                        ? '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d').format(_endDate!)}'
                        : timeEntriesProvider.translate('selectDateRange'),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_userIds.isNotEmpty)
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedUserId,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    hint: Text(timeEntriesProvider.translate('filterByUser')),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(timeEntriesProvider.translate('allUsers')),
                      ),
                      ..._userIds.asMap().entries.map((entry) {
                        return DropdownMenuItem(
                          value: entry.value,
                          child: Text(_userNames[entry.key]),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedUserId = value;
                      });
                    },
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
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                timeEntriesProvider.translate('totalHours'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              Text(
                '${totalHours.toStringAsFixed(1)} ${timeEntriesProvider.translate('hours')}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                      return TimeEntryCard(
                        entry: entry,
                        isEditing: _isEditing,
                        onDelete:
                            _isEditing
                                ? () {
                                  setState(() {
                                    if (_entriesToDelete.contains(entry)) {
                                      _entriesToDelete.remove(entry);
                                    } else {
                                      _entriesToDelete.add(entry);
                                    }
                                  });
                                }
                                : null,
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
                child: OutlinedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    _startDate != null && _endDate != null
                        ? '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d').format(_endDate!)}'
                        : timeEntriesProvider.translate('selectDateRange'),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (_userIds.isNotEmpty)
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedUserId,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    hint: Text(timeEntriesProvider.translate('filterByUser')),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(timeEntriesProvider.translate('allUsers')),
                      ),
                      ..._userIds.asMap().entries.map((entry) {
                        return DropdownMenuItem(
                          value: entry.value,
                          child: Text(_userNames[entry.key]),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedUserId = value;
                      });
                    },
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
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                timeEntriesProvider.translate('totalExpenses'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              Text(
                formatAmount(
                  filteredExpenses.fold(0.0, (sum, e) => sum + e.amount),
                ),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 1,
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
                            '${expense.userName ?? 'Unknown'} - ${DateFormat.yMMMd().format(expense.date)}',
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
                          onTap: () {
                            // TODO: Add edit functionality
                          },
                        ),
                      );
                    },
                  ),
        ),

        // Add expense button
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _addExpense,
            icon: const Icon(Icons.add),
            label: Text(timeEntriesProvider.translate('addExpense')),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteSelectedEntries() async {
    if (_entriesToDelete.isEmpty) return;

    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(
      context,
      listen: false,
    );

    for (var entry in _entriesToDelete) {
      await timeEntriesProvider.deleteTimeEntry(entry.id);
    }

    setState(() {
      _entriesToDelete.clear();
    });
  }
}
