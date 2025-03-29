import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/models/job.dart';
import 'package:timagatt/providers/jobs_provider.dart';
import 'package:timagatt/providers/time_entries_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

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
  Color _selectedColor = Colors.blue;
  Job? _editingJob;

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
    _nameController.text = job.name;
    _descriptionController.text = job.description ?? '';
    _selectedColor = job.color;
    _editingJob = job;

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
    final colors = [
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
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children:
          colors.map((color) {
            final isSelected = _selectedColor.value == color.value;
            return GestureDetector(
              onTap: () {
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
                              color: color.withOpacity(0.3),
                              blurRadius: 4,
                              spreadRadius: 0.5,
                            ),
                          ]
                          : null,
                ),
                child:
                    isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
              ),
            );
          }).toList(),
    );
  }

  void _saveJob() {
    final formKey = _editingJob != null ? _editJobFormKey : _addJobFormKey;
    if (formKey.currentState!.validate()) {
      final jobsProvider = Provider.of<JobsProvider>(context, listen: false);
      final name = _nameController.text;
      final description =
          _descriptionController.text.isEmpty
              ? null
              : _descriptionController.text;

      if (_editingJob == null) {
        // Add new job
        jobsProvider.addJob(name, _selectedColor, description);
      } else {
        // Update existing job
        jobsProvider.updateJob(
          _editingJob!.id,
          name: name,
          description: description,
          color: _selectedColor,
        );
      }

      Navigator.pop(context);

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Provider.of<TimeEntriesProvider>(
              context,
              listen: false,
            ).translate(_editingJob == null ? 'jobAdded' : 'jobUpdated'),
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
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
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(timeEntriesProvider.translate('jobs')),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: timeEntriesProvider.translate('myJobs')),
            Tab(text: timeEntriesProvider.translate('sharedJobs')),
            Tab(text: timeEntriesProvider.translate('createJob')),
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
          _buildCreateJobTab(jobsProvider, timeEntriesProvider, theme),

          // Join Job Tab
          _buildJoinJobTab(jobsProvider, timeEntriesProvider, theme),
        ],
      ),
      floatingActionButton:
          _tabController.index <= 1
              ? FloatingActionButton(
                onPressed: () {
                  if (_tabController.index == 0) {
                    // For My Jobs tab
                    _showAddJobDialog();
                  } else if (_tabController.index == 1) {
                    // For Shared Jobs tab
                    _tabController.animateTo(2); // Navigate to Create Job tab
                  }
                },
                child: const Icon(Icons.add),
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
    final myJobs = jobsProvider.jobs.where((job) => !job.isShared).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (myJobs.isEmpty)
            _buildEmptyJobsState(timeEntriesProvider, theme)
          else
            ...myJobs.map(
              (job) => _buildSlideableJobCard(
                job,
                theme,
                Theme.of(context).brightness == Brightness.dark,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSharedJobsTab(
    JobsProvider jobsProvider,
    TimeEntriesProvider timeEntriesProvider,
    ThemeData theme,
  ) {
    final sharedJobs = jobsProvider.sharedJobs;

    if (!jobsProvider.isPaidUser) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                timeEntriesProvider.translate('sharedJobsPremiumFeature'),
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                timeEntriesProvider.translate('upgradeToAccessSharedJobs'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Navigate to upgrade screen
                },
                child: Text(timeEntriesProvider.translate('upgrade')),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sharedJobs.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Icon(
                      Icons.group_work_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      timeEntriesProvider.translate('noSharedJobs'),
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeEntriesProvider.translate(
                        'createSharedJobDescription',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ...sharedJobs.map(
              (job) =>
                  _buildSharedJobCard(job, theme, jobsProvider.currentUserId),
            ),
        ],
      ),
    );
  }

  Widget _buildJoinJobTab(
    JobsProvider jobsProvider,
    TimeEntriesProvider timeEntriesProvider,
    ThemeData theme,
  ) {
    final codeController = TextEditingController();

    if (!jobsProvider.isPaidUser) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                timeEntriesProvider.translate('sharedJobsPremiumFeature'),
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Navigate to upgrade screen
                },
                child: Text(timeEntriesProvider.translate('upgrade')),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _joinJobFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              timeEntriesProvider.translate('joinSharedJob'),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              timeEntriesProvider.translate('enterCodeToJoin'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: codeController,
              decoration: InputDecoration(
                labelText: timeEntriesProvider.translate('connectionCode'),
                hintText: 'ABC123',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(letterSpacing: 2),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (codeController.text.isNotEmpty) {
                    jobsProvider.joinSharedJob(codeController.text);

                    // Navigate to shared jobs tab
                    _navigateToTab(1);
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(timeEntriesProvider.translate('join')),
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary.withOpacity(0.7),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    timeEntriesProvider.translate('sharedJobInfo'),
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedJobCard(Job job, ThemeData theme, String? currentUserId) {
    final isOwner = job.creatorId == currentUserId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: job.color,
                  child: Text(
                    job.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (job.description != null &&
                          job.description!.isNotEmpty)
                        Text(
                          job.description!,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (isOwner)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmDeleteJob(job),
                    tooltip: Provider.of<TimeEntriesProvider>(
                      context,
                      listen: false,
                    ).translate('delete'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.link, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    job.connectionCode ?? '',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  job.isPublic ? Icons.public : Icons.lock_outline,
                  size: 16,
                  color: theme.textTheme.bodySmall?.color,
                ),
                const SizedBox(width: 4),
                Text(
                  Provider.of<TimeEntriesProvider>(
                    context,
                  ).translate(job.isPublic ? 'publicJob' : 'privateJob'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyJobsState(
    TimeEntriesProvider timeEntriesProvider,
    ThemeData theme,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 32),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.work_outline,
            size: 64,
            color: theme.colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            timeEntriesProvider.translate('noJobsYet'),
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            timeEntriesProvider.translate('createJobDescription'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddJobDialog,
            icon: const Icon(Icons.add),
            label: Text(timeEntriesProvider.translate('createFirstJob')),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlideableJobCard(Job job, ThemeData theme, bool isDark) {
    return Slidable(
      key: ValueKey(job.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => _editJob(job),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: Colors.white,
            icon: Icons.edit,
            label: Provider.of<TimeEntriesProvider>(
              context,
              listen: false,
            ).translate('edit'),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
          ),
          SlidableAction(
            onPressed: (_) => _confirmDeleteJob(job),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: Provider.of<TimeEntriesProvider>(
              context,
              listen: false,
            ).translate('delete'),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: job.color.withOpacity(0.3), width: 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _editJob(job),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Color indicator with job initial
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: job.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: job.color.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
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
                const SizedBox(width: 16),
                // Job details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (job.description != null &&
                          job.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            job.description!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodySmall?.color,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                // Slide indicator
                Icon(
                  Icons.swipe_left,
                  color: theme.colorScheme.primary.withOpacity(0.5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateSharedJobDialog() {
    final nameController = TextEditingController();
    final timeEntriesProvider = Provider.of<TimeEntriesProvider>(
      context,
      listen: false,
    );
    bool isPublic = true;
    Color selectedColor = Colors.blue;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: Text(timeEntriesProvider.translate('createSharedJob')),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: timeEntriesProvider.translate('jobName'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(timeEntriesProvider.translate('jobColor')),
                        const SizedBox(height: 8),
                        _buildColorPickerDialog(selectedColor, (color) {
                          setState(() => selectedColor = color);
                        }),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: Text(
                            timeEntriesProvider.translate('publicJob'),
                          ),
                          subtitle: Text(
                            timeEntriesProvider.translate(
                              'publicJobDescription',
                            ),
                          ),
                          value: isPublic,
                          onChanged:
                              (value) => setState(() => isPublic = value),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(timeEntriesProvider.translate('cancel')),
                    ),
                    TextButton(
                      onPressed: () {
                        if (nameController.text.isNotEmpty) {
                          Provider.of<JobsProvider>(
                            context,
                            listen: false,
                          ).createSharedJob(
                            nameController.text,
                            selectedColor,
                            isPublic,
                          );
                          Navigator.pop(context);
                        }
                      },
                      child: Text(timeEntriesProvider.translate('create')),
                    ),
                  ],
                ),
          ),
    );
  }

  Widget _buildColorPickerDialog(
    Color currentColor,
    Function(Color) onColorSelected,
  ) {
    final colors = [
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
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children:
          colors.map((color) {
            final isSelected = currentColor.value == color.value;
            return GestureDetector(
              onTap: () => onColorSelected(color),
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
                ),
                child:
                    isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
              ),
            );
          }).toList(),
    );
  }

  Widget _buildCreateJobTab(
    JobsProvider jobsProvider,
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

    final _colorOptions = [
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
      Colors.brown,
      Colors.blueGrey,
      Colors.greenAccent,
      Colors.blueAccent,
    ];

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
                  spacing: 8,
                  runSpacing: 12,
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
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border:
                                  isSelected
                                      ? Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      )
                                      : null,
                              boxShadow:
                                  isSelected
                                      ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 8,
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
                      if (createJobFormKey.currentState!.validate()) {
                        final name = nameController.text;
                        final description =
                            descriptionController.text.isEmpty
                                ? null
                                : descriptionController.text;

                        if (isShared && jobsProvider.isPaidUser) {
                          jobsProvider.createSharedJob(
                            name,
                            selectedColor,
                            isPublic,
                          );
                        } else {
                          jobsProvider.addJob(name, selectedColor, description);
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

                        // Use the navigation method instead of direct tab controller access
                        if (isShared) {
                          // Close the current screen first
                          Navigator.pop(context);

                          // Then navigate to the shared jobs tab
                          _navigateToTab(1);
                        } else {
                          // Close the current screen first
                          Navigator.pop(context);

                          // Then navigate to my jobs tab
                          _navigateToTab(0);
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
}
