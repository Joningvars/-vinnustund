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
import 'package:timagatt/widgets/common/custom_app_bar.dart';
import 'package:timagatt/utils/navigation.dart';
import 'package:go_router/go_router.dart';

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

  void _showDeleteJobDialog(Job job) {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );

    showDialog(
      context: context,
      builder:
          (dialogContext) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
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
                    settingsProvider.translate('deleteJob'),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    settingsProvider.translate('deleteJobConfirm'),
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(
                          settingsProvider.translate('cancel'),
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(dialogContext);

                          try {
                            print(
                              '🗑️ Attempting to delete job: ${job.connectionCode} (${job.name})',
                            );

                            // If job has a connection code, treat it as a shared job regardless of isShared flag
                            if (job.connectionCode != null) {
                              final sharedJobsProvider =
                                  Provider.of<SharedJobsProvider>(
                                    context,
                                    listen: false,
                                  );

                              print('Deleting shared job:');
                              print('- Job ID: ${job.id}');
                              print('- Connection Code: ${job.connectionCode}');
                              print('- Creator ID: ${job.creatorId}');

                              // Use the connection code from the job object
                              await sharedJobsProvider.deleteSharedJob(job);
                            } else {
                              final jobsProvider = Provider.of<JobsProvider>(
                                context,
                                listen: false,
                              );
                              await jobsProvider.deleteJob(job.id);
                            }

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    settingsProvider.translate('jobDeleted'),
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            print('❌ Error deleting job: $e');
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to delete job: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
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
                        child: Text(settingsProvider.translate('delete')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
      appBar: CustomAppBar(
        title: settingsProvider.translate('jobs'),
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: Text(settingsProvider.translate('deleteJob')),
                      content: Text(
                        settingsProvider.translate('deleteJobConfirm'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(settingsProvider.translate('cancel')),
                        ),
                        TextButton(
                          onPressed: () {
                            jobsProvider.clearAllJobs();
                            Navigator.pop(context);
                          },
                          child: Text(
                            settingsProvider.translate('delete'),
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: settingsProvider.translate('myJobs')),
            Tab(text: settingsProvider.translate('sharedJobs')),
            Tab(text: settingsProvider.translate('createNewJob')),
            Tab(text: settingsProvider.translate('joinJob')),
          ],
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.textTheme.bodyMedium?.color,
          dividerColor: Colors.transparent,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // My Jobs Tab
          _buildMyJobsTab(jobsProvider, timeEntriesProvider, theme),

          // Shared Jobs Tab
          _buildSharedJobsTab(context),

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
        jobsProvider.jobs
            .where((job) => !job.isShared && job.connectionCode == null)
            .toList();

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
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: regularJobs.length,
      itemBuilder: (context, index) {
        final job = regularJobs[index];
        final settingsProvider = Provider.of<SettingsProvider>(context);

        return GestureDetector(
          onLongPress: () => _showDeleteJobDialog(job),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: CircleAvatar(
                backgroundColor: job.color,
                radius: 24,
                child: Text(
                  job.name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              title: Text(job.name, style: const TextStyle(fontSize: 16)),
              subtitle: job.description != null ? Text(job.description!) : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (job.creatorId == FirebaseAuth.instance.currentUser?.uid)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _editJob(job),
                      tooltip: jobsProvider.translate('editJob'),
                    ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () {
                final settingsProvider = Provider.of<SettingsProvider>(
                  context,
                  listen: false,
                );
                final timeEntriesProvider = Provider.of<TimeEntriesProvider>(
                  context,
                  listen: false,
                );
                settingsProvider.setSelectedTabIndex(
                  2,
                ); // Switch to history tab
                timeEntriesProvider.selectedJob = job; // Set the selected job
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSharedJobsTab(BuildContext context) {
    final sharedJobsProvider = Provider.of<SharedJobsProvider>(context);
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    print(
      '🔄 Building shared jobs tab with ${sharedJobsProvider.sharedJobs.length} jobs',
    );

    if (sharedJobsProvider.sharedJobs.isEmpty) {
      return Center(
        child: Text(
          settingsProvider.translate('noSharedJobs'),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sharedJobsProvider.sharedJobs.length,
      itemBuilder: (context, index) {
        final job = sharedJobsProvider.sharedJobs[index];
        print('🔍 Processing shared job: ${job.name} (ID: ${job.id})');

        return GestureDetector(
          onLongPress: () => _showDeleteJobDialog(job),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: job.color,
                child: Text(
                  job.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(job.name),
              subtitle: Text(
                job.isPublic
                    ? settingsProvider.translate('publicJob')
                    : settingsProvider.translate('privateJob'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                context.go('/job-overview', extra: job);
              },
            ),
          ),
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
                onPressed:
                    _isLoading
                        ? null
                        : () =>
                            _joinJob(_codeController.text.trim().toUpperCase()),
              ),
            ),
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
                    onPressed: () {
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
                            content: Text(
                              timeEntriesProvider.translate('jobAdded'),
                            ),
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                          ),
                        );

                        Navigator.pop(context);
                      }
                    },
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
}

class SharedJobsTab extends StatefulWidget {
  const SharedJobsTab({Key? key}) : super(key: key);

  @override
  State<SharedJobsTab> createState() => _SharedJobsTabState();
}

class _SharedJobsTabState extends State<SharedJobsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Load shared jobs when the tab is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sharedJobsProvider = Provider.of<SharedJobsProvider>(
        context,
        listen: false,
      );
      // Set up the real-time listener for shared jobs
      sharedJobsProvider.listenToSharedJobs();
    });
  }

  @override
  void dispose() {
    // Clean up any listeners if needed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin

    final sharedJobsProvider = Provider.of<SharedJobsProvider>(context);
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);

    print(
      '🔄 Building shared jobs tab with ${sharedJobsProvider.sharedJobs.length} jobs',
    );

    if (sharedJobsProvider.sharedJobs.isEmpty) {
      return Center(
        child: Text(
          settingsProvider.translate('noSharedJobs'),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sharedJobsProvider.sharedJobs.length,
      itemBuilder: (context, index) {
        final job = sharedJobsProvider.sharedJobs[index];
        print('🔍 Processing shared job: ${job.name} (ID: ${job.id})');

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: job.color,
              child: Text(
                job.name.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(job.name),
            subtitle: Text(
              job.isPublic
                  ? settingsProvider.translate('publicJob')
                  : settingsProvider.translate('privateJob'),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              context.go('/job-overview', extra: job);
            },
          ),
        );
      },
    );
  }
}
