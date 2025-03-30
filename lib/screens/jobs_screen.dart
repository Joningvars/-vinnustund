import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/models/job.dart';
import 'package:timagatt/providers/jobs_provider.dart';
import 'package:timagatt/providers/time_entries_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timagatt/screens/job_overview_screen.dart';
import 'package:timagatt/providers/shared_jobs_provider.dart';
import 'package:timagatt/providers/settings_provider.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({Key? key}) : super(key: key);

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen>
    with SingleTickerProviderStateMixin {
  final _addJobFormKey = GlobalKey<FormState>();
  final _editJobFormKey = GlobalKey<FormState>();
  final _joinJobFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _codeController = TextEditingController();
  Color _selectedColor = Colors.blue;
  Job? _editingJob;

  // Define a single set of colors to use throughout the app
  final List<Color> _colorOptions = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.amber,
    Colors.cyan,
    Colors.deepPurple,
    Colors.lightBlue,
    Colors.lime,
    Colors.deepOrange,
    Colors.greenAccent,
    Colors.blueAccent,
  ];

  // Add a TabController
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Initialize the TabController with 4 tabs
    _tabController = TabController(length: 4, vsync: this);

    // Add listener to track tab changes
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // Rebuild to update FAB visibility
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get the initial tab from route arguments
    final arguments =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (arguments != null && arguments.containsKey('initialTab')) {
      final initialTab = arguments['initialTab'] as int;
      // Set the tab controller to the initial tab
      _tabController.animateTo(initialTab);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _nameController.clear();
    _descriptionController.clear();
    _selectedColor = Colors.blue;
    _editingJob = null;
  }

  void _showAddJobDialog() {
    _resetForm();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildJobForm(context),
    );
  }

  void _showEditJobDialog(Job job) {
    print('Editing job: ${job.id}, ${job.name}, ${job.color}');

    // Set form values
    _nameController.text = job.name;
    _descriptionController.text = job.description ?? '';

    setState(() {
      _selectedColor = job.color;
      _editingJob = job;
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildJobForm(context),
    );
  }

  Widget _buildJobForm(BuildContext context) {
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final formKey = _editingJob != null ? _editJobFormKey : _addJobFormKey;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _editingJob == null
                      ? timeEntriesProvider.translate('addJob')
                      : timeEntriesProvider.translate('editJob'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),

            // Job name field
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: timeEntriesProvider.translate('jobName'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return timeEntriesProvider.translate('jobNameRequired');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Job description field
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: timeEntriesProvider.translate('description'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Color picker
            Text(
              timeEntriesProvider.translate('jobColor'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildColorPicker(),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: _saveJob,
                child: Text(
                  timeEntriesProvider.translate('save'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPicker() {
    return StatefulBuilder(
      builder: (context, setStateLocal) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children:
              _colorOptions.map((color) {
                final isSelected = _selectedColor.value == color.value;
                return GestureDetector(
                  onTap: () {
                    setStateLocal(() {
                      _selectedColor = color;
                    });
                    // Also update the parent state
                    setState(() {
                      _selectedColor = color;
                    });
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                      boxShadow:
                          isSelected
                              ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ]
                              : null,
                    ),
                    child:
                        isSelected
                            ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                            : null,
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  void _saveJob() {
    final jobsProvider = Provider.of<JobsProvider>(context, listen: false);
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(
      context,
      listen: false,
    );

    if (_editingJob != null) {
      // Editing existing job
      if (_editJobFormKey.currentState!.validate()) {
        print('Saving edited job: ${_editingJob!.id}');
        print('New name: ${_nameController.text}');
        print('New description: ${_descriptionController.text}');
        print('New color: ${_selectedColor}');

        jobsProvider.updateJob(
          _editingJob!.id,
          name: _nameController.text,
          description:
              _descriptionController.text.isEmpty
                  ? null
                  : _descriptionController.text,
          color: _selectedColor,
        );

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(timeEntriesProvider.translate('jobUpdated')),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );

        Navigator.pop(context);
      }
    } else {
      // Adding new job
      if (_addJobFormKey.currentState!.validate()) {
        jobsProvider.addJob(
          _nameController.text,
          _selectedColor,
          _descriptionController.text.isEmpty
              ? null
              : _descriptionController.text,
        );

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(timeEntriesProvider.translate('jobAdded')),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );

        Navigator.pop(context);
      }
    }

    // After creating a shared job
    final sharedJobsProvider = Provider.of<SharedJobsProvider>(
      context,
      listen: false,
    );
    sharedJobsProvider.listenToSharedJobs();
  }

  void _confirmDeleteJob(Job job) {
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(
      context,
      listen: false,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(timeEntriesProvider.translate('deleteJob')),
            content: Text(
              timeEntriesProvider
                  .translate('deleteJobConfirmation')
                  .replaceAll('{jobName}', job.name),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(timeEntriesProvider.translate('cancel')),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Provider.of<JobsProvider>(
                    context,
                    listen: false,
                  ).deleteJob(job.id);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        timeEntriesProvider.translate('jobDeleted'),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
                child: Text(
                  timeEntriesProvider.translate('delete'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  void _editJob(Job job) {
    setState(() {
      _editingJob = job;
      _nameController.text = job.name;
      _descriptionController.text = job.description ?? '';
      _selectedColor = job.color;
    });

    _showAddJobDialog();
  }

  void _navigateToTab(int tabIndex) {
    _tabController.animateTo(tabIndex);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final jobsProvider = Provider.of<JobsProvider>(context);
    final sharedJobsProvider = Provider.of<SharedJobsProvider>(context);
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(context);
    final theme = Theme.of(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          settingsProvider.translate('jobs'),
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: timeEntriesProvider.translate('myJobs')),
            Tab(text: timeEntriesProvider.translate('sharedJobsSelectButton')),
            Tab(text: timeEntriesProvider.translate('createNewJob')),
            Tab(text: timeEntriesProvider.translate('joinJob')),
          ],
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.textTheme.bodyMedium?.color,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // My Jobs Tab
          _buildMyJobsTab(jobsProvider, timeEntriesProvider, theme),

          // Shared Jobs Tab
          _buildSharedJobsTab(jobsProvider, timeEntriesProvider, theme),

          // Create Job Tab
          _buildCreateJobTab(
            jobsProvider,
            sharedJobsProvider,
            timeEntriesProvider,
            theme,
          ),

          // Join Job Tab
          _buildJoinJobTab(jobsProvider, timeEntriesProvider, theme),
        ],
      ),
      floatingActionButton:
          _tabController.index <= 1
              ? FloatingActionButton(
                backgroundColor: theme.colorScheme.primary,
                onPressed: () {
                  // Navigate to the Create Job tab (index 2) instead of showing a dialog
                  _tabController.animateTo(2);
                },
                child: const Icon(Icons.add, color: Colors.white),
                tooltip: timeEntriesProvider.translate('addJob'),
              )
              : null,
    );
  }

  Widget _buildMyJobsTab(
    JobsProvider jobsProvider,
    TimeEntriesProvider timeEntriesProvider,
    ThemeData theme,
  ) {
    // Filter to only show non-shared jobs
    final regularJobs =
        jobsProvider.jobs.where((job) => !job.isShared).toList();

    if (regularJobs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              timeEntriesProvider.translate('noJobsYet'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              timeEntriesProvider.translate('createJobDescription'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to Create Job tab
                _tabController.animateTo(2);
              },
              icon: const Icon(Icons.add),
              label: Text(timeEntriesProvider.translate('createFirstJob')),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: regularJobs.length,
      itemBuilder: (context, index) {
        final job = regularJobs[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Job header
              ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: job.color,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      job.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  job.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                subtitle:
                    job.description != null && job.description!.isNotEmpty
                        ? Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            job.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                        : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Edit button
                    IconButton(
                      icon: Icon(
                        Icons.edit_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: () {
                        _showEditJobDialog(job);
                      },
                      tooltip: timeEntriesProvider.translate('editJob'),
                    ),
                    // View entries button
                    IconButton(
                      icon: Icon(
                        Icons.visibility_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      onPressed: () {
                        // Navigate to history screen filtered by this job
                        Navigator.pushNamed(
                          context,
                          '/history',
                          arguments: {'jobId': job.id},
                        );
                      },
                      tooltip: timeEntriesProvider.translate('viewEntries'),
                    ),
                    // Delete button
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        _showDeleteJobDialog(job);
                      },
                      tooltip: timeEntriesProvider.translate('deleteJob'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSharedJobsTab(
    JobsProvider jobsProvider,
    TimeEntriesProvider timeEntriesProvider,
    ThemeData theme,
  ) {
    return Consumer<SharedJobsProvider>(
      builder: (context, sharedJobsProvider, child) {
        // Force rebuild when sharedJobs changes
        final sharedJobs = sharedJobsProvider.sharedJobs;

        print('Building shared jobs tab with ${sharedJobs.length} jobs');

        return Column(
          children: [
            // Your existing UI elements

            // Display the shared jobs list
            Expanded(
              child:
                  sharedJobs.isEmpty
                      ? Center(child: Text('No shared jobs found'))
                      : ListView.builder(
                        itemCount: sharedJobs.length,
                        itemBuilder: (context, index) {
                          final job = sharedJobs[index];
                          return _buildJobItem(job);
                        },
                      ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildJoinJobTab(
    JobsProvider jobsProvider,
    TimeEntriesProvider timeEntriesProvider,
    ThemeData theme,
  ) {
    final codeController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon
            Row(
              children: [
                // Icon in semi-transparent circle
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.link_rounded,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    timeEntriesProvider.translate('joinSharedJob'),
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Connection code explanation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isDarkMode
                        ? theme.colorScheme.surface
                        : theme.colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          timeEntriesProvider.translate('enterConnectionCode'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timeEntriesProvider.translate('askJobCreatorForCode'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Code input field
            TextFormField(
              controller: codeController,
              decoration: InputDecoration(
                labelText: timeEntriesProvider.translate('connectionCode'),
                hintText: 'ABC-123',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.vpn_key_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste_rounded),
                  tooltip: 'Paste from clipboard',
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) {
                      codeController.text = data!.text!.trim();
                    }
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return timeEntriesProvider.translate('jobCodeRequired');
                }
                return null;
              },
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(letterSpacing: 1.5),
            ),
            const SizedBox(height: 32),

            // Join button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                child: Text(
                  timeEntriesProvider.translate('joinJob'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    if (codeController.text.isNotEmpty) {
                      _isLoading
                          ? null
                          : () => _joinJob(
                            _codeController.text.trim().toUpperCase(),
                          );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            _buildJoinJobButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateJobTab(
    JobsProvider jobsProvider,
    SharedJobsProvider sharedJobsProvider,
    TimeEntriesProvider timeEntriesProvider,
    ThemeData theme,
  ) {
    final createJobFormKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    // Move these variables outside the StatefulBuilder
    Color selectedColor = Colors.blue;
    bool isShared = false;
    bool isPublic = true;

    return StatefulBuilder(
      builder: (context, setStateLocal) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: createJobFormKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timeEntriesProvider.translate('createNewJob'),
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),

                // Job name field
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: timeEntriesProvider.translate('jobName'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return timeEntriesProvider.translate('jobNameRequired');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Job description field
                TextFormField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: timeEntriesProvider.translate('description'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                // Color picker
                Text(
                  timeEntriesProvider.translate('jobColor'),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 8,
                  children:
                      _colorOptions.map((color) {
                        final isSelected = selectedColor.value == color.value;
                        return GestureDetector(
                          onTap: () {
                            setStateLocal(() {
                              selectedColor = color;
                            });
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border:
                                  isSelected
                                      ? Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      )
                                      : null,
                              boxShadow:
                                  isSelected
                                      ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 4,
                                          spreadRadius: 0.5,
                                        ),
                                      ]
                                      : null,
                            ),
                            child:
                                isSelected
                                    ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                    : null,
                          ),
                        );
                      }).toList(),
                ),

                const SizedBox(height: 24),

                // Shared job toggle
                if (jobsProvider.isPaidUser) ...[
                  SwitchListTile(
                    title: Text(timeEntriesProvider.translate('sharedJob')),
                    subtitle: Text(
                      timeEntriesProvider.translate('sharedJobDescription'),
                    ),
                    value: isShared,
                    onChanged: (value) => setStateLocal(() => isShared = value),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.dividerColor),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),

                  // Public job toggle (only visible if shared is enabled)
                  if (isShared)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: SwitchListTile(
                        title: Text(timeEntriesProvider.translate('publicJob')),
                        subtitle: Text(
                          timeEntriesProvider.translate('publicJobDescription'),
                        ),
                        value: isPublic,
                        onChanged:
                            (value) => setStateLocal(() => isPublic = value),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: theme.dividerColor),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                ],

                const SizedBox(height: 32),

                // Create button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (createJobFormKey.currentState!.validate()) {
                        final name = nameController.text;
                        final description =
                            descriptionController.text.isEmpty
                                ? null
                                : descriptionController.text;

                        try {
                          if (isShared && jobsProvider.isPaidUser) {
                            // Create shared job
                            final sharedJobsProvider =
                                Provider.of<SharedJobsProvider>(
                                  context,
                                  listen: false,
                                );
                            await sharedJobsProvider.createSharedJob(
                              Job(
                                id: '', // Empty string, will be set by the provider
                                name: name,
                                color: selectedColor,
                                isPublic: isPublic,
                                isShared: true,
                              ),
                            );
                          } else {
                            // Create regular job
                            await jobsProvider.addJob(
                              name,
                              selectedColor,
                              description,
                            );
                          }

                          // Clear form
                          nameController.clear();
                          descriptionController.clear();
                          setStateLocal(() {
                            selectedColor = Colors.blue;
                            isShared = false;
                            isPublic = true;
                          });

                          // Show success message
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                timeEntriesProvider.translate('jobAdded'),
                              ),
                              backgroundColor: theme.colorScheme.primary,
                            ),
                          );

                          // Navigate to the appropriate tab
                          if (isShared) {
                            _tabController.animateTo(1); // Shared Jobs tab
                          } else {
                            _tabController.animateTo(0); // My Jobs tab
                          }

                          // After the job is created, refresh the shared jobs list
                          await sharedJobsProvider.refreshSharedJobs();
                        } catch (e) {
                          // Show error message
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: ${e.toString()}'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      timeEntriesProvider.translate('createJob'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteJobDialog(Job job) {
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(
      context,
      listen: false,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(timeEntriesProvider.translate('deleteJob')),
            content: Text(
              timeEntriesProvider
                  .translate('deleteJobConfirmation')
                  .replaceAll('{jobName}', job.name),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(timeEntriesProvider.translate('cancel')),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Provider.of<JobsProvider>(
                    context,
                    listen: false,
                  ).deleteJob(job.id);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        timeEntriesProvider.translate('jobDeleted'),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
                child: Text(
                  timeEntriesProvider.translate('delete'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  bool _isLoading = false;

  Future<void> _joinJob(String code) async {
    if (code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Please enter a connection code')));
      return;
    }

    // Show loading indicator
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = Provider.of<SharedJobsProvider>(context, listen: false);
      final jobsProvider = Provider.of<JobsProvider>(context, listen: false);

      // Debug print to confirm method is being called
      print('🔍 DEBUG: Calling connectUserToJob with code: $code');

      final success = await provider.connectUserToJob(code);

      if (mounted) {
        if (success) {
          // Refresh the jobs list to show the newly joined job
          await jobsProvider.fetchJobs(context);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully joined job'),
              backgroundColor: Colors.green,
            ),
          );

          // Close the dialog
          Navigator.pop(context);

          // Navigate to the shared jobs tab (index 1)
          _tabController.animateTo(1);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to join job. Please check the code and try again.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error joining job: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
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

  void _showJoinJobDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Join Job'),
            content: TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: 'Connection Code',
                hintText: 'Enter the 6-digit code',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed:
                    _isLoading
                        ? null
                        : () =>
                            _joinJob(_codeController.text.trim().toUpperCase()),
                child:
                    _isLoading
                        ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Text('Join'),
              ),
            ],
          ),
    );
  }

  Widget _buildJoinJobButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton.icon(
        onPressed: () {
          // Clear the code controller before showing the dialog
          _codeController.clear();
          _showJoinJobDialog();
        },
        icon: const Icon(Icons.add_link),
        label: const Text('Join Job with Code'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildJobItem(Job job) {
    return ListTile(
      leading: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(color: job.color, shape: BoxShape.circle),
      ),
      title: Text(job.name),
      subtitle: job.description != null ? Text(job.description!) : null,
      trailing: job.isShared ? Icon(Icons.group, color: Colors.blue) : null,
      onTap: () {
        // Navigate to job details or select the job
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => JobOverviewScreen(job: job)),
        );
      },
    );
  }
}
