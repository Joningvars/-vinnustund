import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/models/job.dart';
import 'package:timagatt/models/time_entry.dart';
import 'package:timagatt/models/expense.dart';
import 'package:timagatt/providers/jobs_provider.dart';
import 'package:timagatt/providers/settings_provider.dart';
import 'package:timagatt/providers/time_entries_provider.dart';
import 'package:timagatt/providers/expenses_provider.dart';
import 'package:timagatt/screens/job/add_expense_screen.dart';
import 'package:timagatt/screens/job/edit_expense_screen.dart';
import 'package:timagatt/widgets/common/styled_dropdown.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';
import '../widgets/time_entry_card.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timagatt/widgets/common/custom_app_bar.dart';

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
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _pendingRequests = [];

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Add listener to track tab changes
    _tabController.addListener(() {
      setState(() {}); // Force rebuild when tab changes
    });

    _loadData();
    _loadMembers();
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

  Future<void> _loadMembers() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get members from the job's connectedUsers list
      if (widget.job.connectedUsers != null) {
        final membersSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .where(
                  FieldPath.documentId,
                  whereIn: widget.job.connectedUsers!,
                )
                .get();

        _members =
            membersSnapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'name': data['name'] ?? 'Unknown User',
                'email': data['email'] ?? '',
                'isCreator': doc.id == widget.job.creatorId,
              };
            }).toList();
      }

      // Get pending requests if the current user is the creator
      if (widget.job.creatorId == currentUser.uid &&
          widget.job.connectionCode != null) {
        final requestsSnapshot =
            await FirebaseFirestore.instance
                .collection('sharedJobs')
                .doc(widget.job.connectionCode)
                .collection('joinRequests')
                .get();

        _pendingRequests =
            requestsSnapshot.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                'userId': data['userId'],
                'userName': data['userName'] ?? 'Unknown User',
                'userEmail': data['userEmail'] ?? '',
                'timestamp': data['timestamp'],
              };
            }).toList();
      }

      setState(() {});
    } catch (e) {
      print('Error loading members: $e');
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
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: widget.job.name,
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => _exportToPDF(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: settingsProvider.translate('timeEntries')),
            Tab(text: settingsProvider.translate('expenses')),
            Tab(text: settingsProvider.translate('members')),
          ],
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.textTheme.bodyMedium?.color,
          dividerColor: Colors.transparent,
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
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTimeEntriesTab(),
                        _buildExpensesTab(),
                        _buildMembersTab(),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildTimeEntriesTab() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
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
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 17,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
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
                    hint: settingsProvider.translate('allUsers'),
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
    final settingsProvider = Provider.of<SettingsProvider>(context);
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
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
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
                    hint: settingsProvider.translate('allUsers'),
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

  Widget _buildMembersTab() {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isCreator = currentUser?.uid == widget.job.creatorId;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Members section
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Provider.of<TimeEntriesProvider>(context).translate('members'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ..._members.map(
              (member) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(member['name'][0].toUpperCase()),
                  ),
                  title: Text(member['name']),
                  subtitle: Text(member['email']),
                  trailing:
                      member['isCreator']
                          ? const Text('Creator')
                          : isCreator
                          ? IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed:
                                () =>
                                    _handleMemberAction(member['id'], 'remove'),
                          )
                          : null,
                ),
              ),
            ),
          ],
        ),

        // Pending requests section (only for creator)
        if (isCreator && _pendingRequests.isNotEmpty) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pending Requests',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                ..._pendingRequests.map(
                  (request) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(request['userName'][0].toUpperCase()),
                      ),
                      title: Text(request['userName']),
                      subtitle: Text(request['userEmail']),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline),
                            color: Colors.green,
                            onPressed:
                                () => _handleMemberAction(
                                  request['userId'],
                                  'approve',
                                ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel_outlined),
                            color: Colors.red,
                            onPressed:
                                () => _handleMemberAction(
                                  request['userId'],
                                  'deny',
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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

  Future<void> _handleMemberAction(String userId, String action) async {
    try {
      if (action == 'remove') {
        // Remove member from connectedUsers
        await FirebaseFirestore.instance
            .collection('sharedJobs')
            .doc(widget.job.connectionCode)
            .update({
              'connectedUsers': FieldValue.arrayRemove([userId]),
            });

        // Remove from user's jobs collection
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('jobs')
            .doc(widget.job.id)
            .delete();

        // Refresh members list
        await _loadMembers();
      } else if (action == 'approve') {
        // Find the request in pendingRequests
        final request = _pendingRequests.firstWhere(
          (r) => r['userId'] == userId,
        );

        // Add user to connectedUsers
        await FirebaseFirestore.instance
            .collection('sharedJobs')
            .doc(widget.job.connectionCode)
            .update({
              'connectedUsers': FieldValue.arrayUnion([userId]),
            });

        // Add job to user's jobs collection
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('jobs')
            .doc(widget.job.id)
            .set(widget.job.toJson());

        // Delete the request
        await FirebaseFirestore.instance
            .collection('sharedJobs')
            .doc(widget.job.connectionCode)
            .collection('joinRequests')
            .doc(request['id'])
            .delete();

        // Refresh members and requests lists
        await _loadMembers();
      } else if (action == 'deny') {
        // Find the request in pendingRequests
        final request = _pendingRequests.firstWhere(
          (r) => r['userId'] == userId,
        );

        // Delete the request
        await FirebaseFirestore.instance
            .collection('sharedJobs')
            .doc(widget.job.connectionCode)
            .collection('joinRequests')
            .doc(request['id'])
            .delete();

        // Refresh requests list
        await _loadMembers();
      }
    } catch (e) {
      print('Error handling member action: $e');
    }
  }

  Future<void> _exportToPDF(BuildContext context) async {
    try {
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );
      final timeEntriesProvider = Provider.of<TimeEntriesProvider>(
        context,
        listen: false,
      );
      final jobsProvider = Provider.of<JobsProvider>(context, listen: false);

      // Get all time entries for this job
      final jobEntries =
          _entries.where((entry) => entry.jobId == widget.job.id).toList();
      final jobExpenses =
          _expenses.where((expense) => expense.jobId == widget.job.id).toList();

      if (jobEntries.isEmpty && jobExpenses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(settingsProvider.translate('noEntriesForExport')),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Create a PDF document with custom theme
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: pw.Font.ttf(
            await rootBundle.load(
              'assets/fonts/Comfortaa/Comfortaa-Regular.ttf',
            ),
          ),
          bold: pw.Font.ttf(
            await rootBundle.load('assets/fonts/Comfortaa/Comfortaa-Bold.ttf'),
          ),
        ),
      );

      // Load logo
      final logoImage = pw.MemoryImage(
        (await rootBundle.load('assets/icons/logo.png')).buffer.asUint8List(),
      );

      // Define colors
      final primaryColor = PdfColor.fromHex('#3D5AFE');
      final accentColor = PdfColor.fromHex('#00C853');
      final bgColor = PdfColors.white;
      final lightGrey = PdfColor.fromHex('#F5F5F5');
      final mediumGrey = PdfColor.fromHex('#9E9E9E');
      final textColor = PdfColors.black;

      // Sort entries by date (newest first)
      jobEntries.sort((a, b) => b.startTime.compareTo(a.startTime));
      jobExpenses.sort((a, b) => b.date.compareTo(a.date));

      // Calculate totals
      final totalDuration = jobEntries.fold<Duration>(
        Duration.zero,
        (total, entry) => total + entry.duration,
      );
      final totalHours = totalDuration.inHours;
      final totalMinutes = totalDuration.inMinutes % 60;
      final totalExpenses = jobExpenses.fold<double>(
        0,
        (total, expense) => total + expense.amount,
      );

      // Add content to PDF
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(30),
          header: (pw.Context context) {
            return pw.Column(
              children: [
                // Header with logo and title
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        pw.Image(logoImage, width: 40, height: 40),
                        pw.SizedBox(width: 10),
                        pw.Text(
                          'Tímagátt',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    pw.Text(
                      DateFormat('yyyy-MM-dd').format(DateTime.now()),
                      style: pw.TextStyle(fontSize: 14, color: mediumGrey),
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                // Job title and summary
                pw.Container(
                  margin: const pw.EdgeInsets.symmetric(vertical: 15),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: lightGrey,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        widget.job.name,
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            settingsProvider.translate('totalHours') +
                                ': ' +
                                '$totalHours,${totalMinutes.toString().padLeft(2, '0')}',
                            style: pw.TextStyle(
                              fontSize: 14,
                              color: primaryColor,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            settingsProvider.translate('totalExpenses') +
                                ': ' +
                                '${totalExpenses.toInt()} kr',
                            style: pw.TextStyle(
                              fontSize: 14,
                              color: accentColor,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          build: (pw.Context context) {
            return [
              // Time Entries Section
              if (jobEntries.isNotEmpty) ...[
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 20),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        settingsProvider.translate('timeEntries'),
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          borderRadius: pw.BorderRadius.circular(8),
                          border: pw.Border.all(color: lightGrey, width: 1),
                        ),
                        child: pw.Table(
                          border: pw.TableBorder.symmetric(
                            inside: pw.BorderSide(color: lightGrey, width: 0.5),
                          ),
                          columnWidths: {
                            0: const pw.FlexColumnWidth(1.0), // Date
                            1: const pw.FlexColumnWidth(1.0), // User
                            2: const pw.FlexColumnWidth(0.8), // Clock In
                            3: const pw.FlexColumnWidth(0.8), // Clock Out
                            4: const pw.FlexColumnWidth(0.6), // Hours
                            5: const pw.FlexColumnWidth(2.0), // Description
                          },
                          children: [
                            // Header row
                            pw.TableRow(
                              decoration: pw.BoxDecoration(
                                color: primaryColor,
                                borderRadius: pw.BorderRadius.only(
                                  topLeft: pw.Radius.circular(8),
                                  topRight: pw.Radius.circular(8),
                                ),
                              ),
                              children: [
                                _buildTableHeader(
                                  settingsProvider.translate('date'),
                                ),
                                _buildTableHeader(
                                  settingsProvider.translate('name'),
                                ),
                                _buildTableHeader(
                                  settingsProvider.translate('clockInPDF'),
                                ),
                                _buildTableHeader(
                                  settingsProvider.translate('clockOutPDF'),
                                ),
                                _buildTableHeader(
                                  settingsProvider.translate('hours'),
                                ),
                                _buildTableHeader(
                                  settingsProvider.translate('description'),
                                ),
                              ],
                            ),
                            // Data rows
                            ...jobEntries.asMap().entries.map((entry) {
                              final isEven = entry.key % 2 == 0;
                              final hours = entry.value.duration.inHours;
                              final minutes =
                                  entry.value.duration.inMinutes % 60;
                              return pw.TableRow(
                                decoration: pw.BoxDecoration(
                                  color:
                                      isEven
                                          ? bgColor
                                          : PdfColor(
                                            lightGrey.red,
                                            lightGrey.green,
                                            lightGrey.blue,
                                            0.5,
                                          ),
                                ),
                                children: [
                                  _buildTableCell(
                                    timeEntriesProvider.formatDate(
                                      entry.value.startTime,
                                    ),
                                  ),
                                  _buildTableCell(
                                    entry.value.userName ?? 'Unknown',
                                  ),
                                  _buildTableCell(
                                    timeEntriesProvider.formatTime(
                                      entry.value.startTime,
                                    ),
                                  ),
                                  _buildTableCell(
                                    timeEntriesProvider.formatTime(
                                      entry.value.endTime,
                                    ),
                                  ),
                                  _buildTableCell(
                                    '$hours,${minutes.toString().padLeft(2, '0')}',
                                  ),
                                  _buildTableCell(
                                    entry.value.description ?? '-',
                                  ),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Expenses Section
              if (jobExpenses.isNotEmpty) ...[
                pw.Container(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        settingsProvider.translate('expenses'),
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Container(
                        decoration: pw.BoxDecoration(
                          borderRadius: pw.BorderRadius.circular(8),
                          border: pw.Border.all(color: lightGrey, width: 1),
                        ),
                        child: pw.Table(
                          border: pw.TableBorder.symmetric(
                            inside: pw.BorderSide(color: lightGrey, width: 0.5),
                          ),
                          columnWidths: {
                            0: const pw.FlexColumnWidth(1.0), // Date
                            1: const pw.FlexColumnWidth(1.0), // User
                            2: const pw.FlexColumnWidth(1.0), // Amount
                            3: const pw.FlexColumnWidth(2.0), // Description
                          },
                          children: [
                            // Header row
                            pw.TableRow(
                              decoration: pw.BoxDecoration(
                                color: accentColor,
                                borderRadius: pw.BorderRadius.only(
                                  topLeft: pw.Radius.circular(8),
                                  topRight: pw.Radius.circular(8),
                                ),
                              ),
                              children: [
                                _buildTableHeader(
                                  settingsProvider.translate('date'),
                                ),
                                _buildTableHeader(
                                  settingsProvider.translate('name'),
                                ),
                                _buildTableHeader(
                                  settingsProvider.translate('amount'),
                                ),
                                _buildTableHeader(
                                  settingsProvider.translate('description'),
                                ),
                              ],
                            ),
                            // Data rows
                            ...jobExpenses.asMap().entries.map((entry) {
                              final isEven = entry.key % 2 == 0;
                              return pw.TableRow(
                                decoration: pw.BoxDecoration(
                                  color:
                                      isEven
                                          ? bgColor
                                          : PdfColor(
                                            lightGrey.red,
                                            lightGrey.green,
                                            lightGrey.blue,
                                            0.5,
                                          ),
                                ),
                                children: [
                                  _buildTableCell(
                                    timeEntriesProvider.formatDate(
                                      entry.value.date,
                                    ),
                                  ),
                                  _buildTableCell(
                                    entry.value.userName ?? 'Unknown',
                                  ),
                                  _buildTableCell(
                                    '${entry.value.amount.toInt()} kr',
                                  ),
                                  _buildTableCell(
                                    entry.value.description ?? '-',
                                  ),
                                ],
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ];
          },
        ),
      );

      // Save the PDF
      final output = await getTemporaryDirectory();
      final file = File(
        '${output.path}/job_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        // Show success dialog with modern styling
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Success icon
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 50,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Success message
                    Text(
                      settingsProvider.translate('exportComplete'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      settingsProvider.translate('exportCompleteMessage'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // View button
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            OpenFile.open(file.path);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.visibility,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 28,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  settingsProvider.translate('view'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Share button
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            Share.shareXFiles([XFile(file.path)]);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.share,
                                  color: Colors.purple,
                                  size: 28,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  settingsProvider.translate('share'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Close button
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 16,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.close, color: Colors.grey, size: 28),
                                const SizedBox(height: 8),
                                Text(
                                  settingsProvider.translate('close'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      print('Error exporting to PDF: $e');
      if (mounted) {
        final settingsProvider = Provider.of<SettingsProvider>(
          context,
          listen: false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(settingsProvider.translate('exportError')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  pw.Widget _buildTableHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  pw.Widget _buildTableCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 9)),
    );
  }
}
