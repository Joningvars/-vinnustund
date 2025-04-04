import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/models/job.dart';
import 'package:timagatt/providers/shared_jobs_provider.dart';
import 'package:flutter/services.dart';
import 'package:timagatt/screens/job/job_requests_screen.dart';
import 'package:timagatt/providers/jobs_provider.dart';
import 'package:timagatt/providers/settings_provider.dart';
import 'package:timagatt/widgets/common/custom_app_bar.dart';
import 'package:timagatt/screens/job_overview_screen.dart';
import 'package:go_router/go_router.dart';

class SharedJobsScreen extends StatefulWidget {
  const SharedJobsScreen({Key? key}) : super(key: key);

  @override
  _SharedJobsScreenState createState() => _SharedJobsScreenState();
}

class _SharedJobsScreenState extends State<SharedJobsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  Color _selectedColor = Colors.blue;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isPublic = true;

  final List<Color> _colorOptions = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _joinJob() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a connection code';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final provider = Provider.of<SharedJobsProvider>(context, listen: false);

      // Add debug print to confirm method is being called
      print('🔍 DEBUG: Calling connectUserToJob with code: $code');

      final success = await provider.connectUserToJob(code);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully joined job'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          setState(() {
            _errorMessage =
                'Failed to join job. Please check the code and try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createSharedJob() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a job name';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final provider = Provider.of<SharedJobsProvider>(context, listen: false);

      // Create a Job object
      final Job newJob = Job(
        id: '', // Will be set by the provider
        name: name,
        color: _selectedColor,
        isShared: true,
        isPublic: _isPublic,
      );

      final code = await provider.createSharedJob(newJob, context);

      if (mounted) {
        if (code != null) {
          _nameController.clear();
          _tabController.animateTo(2); // Switch to My Shared Jobs tab

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Job created with code: $code'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() {
            _errorMessage = 'Failed to create job';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToJobRequests() {
    context.push('/job-requests');
  }

  void _showDeleteConfirmation(Job job) {
    final provider = Provider.of<SharedJobsProvider>(context, listen: false);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete Shared Job'),
            content: Text(
              'Are you sure you want to delete "${job.name}"? This will remove the job for all connected users.',
            ),
            actions: [
              TextButton(onPressed: () => context.pop(), child: Text('Cancel')),
              TextButton(
                onPressed: () async {
                  context.pop();
                  try {
                    await provider.deleteSharedJob(job);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Job deleted successfully')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                },
                child: Text('Delete'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
    );
  }

  Future<void> _joinSharedJob(String connectionCode) async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('🔄 Starting join process for code: $connectionCode');

      final sharedJobsProvider = Provider.of<SharedJobsProvider>(
        context,
        listen: false,
      );

      final jobsProvider = Provider.of<JobsProvider>(context, listen: false);

      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );

      // Use the existing joinJobByCode method that's known to work
      print('🔄 Calling joinJobByCode on SharedJobsProvider');
      final job = await sharedJobsProvider.joinJobByCode(connectionCode);

      if (job != null) {
        print('✅ Successfully joined job: ${job.name}');

        // Force refresh the jobs list
        print('🔄 Refreshing jobs list');
        await jobsProvider.refreshJobs();
        print('✅ Jobs list refreshed');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(settingsProvider.translate('jobJoined')),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('❌ Failed to join job');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(settingsProvider.translate('invalidJobCode')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Error joining shared job: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showDeleteJobDialog(Job job) {
    final provider = Provider.of<SharedJobsProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(settingsProvider.translate('deleteJob')),
            content: Text(
              settingsProvider
                  .translate('deleteJobConfirm')
                  .replaceAll('{jobName}', job.name),
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: Text(settingsProvider.translate('cancel')),
              ),
              TextButton(
                onPressed: () async {
                  context.pop();
                  try {
                    if (job.isShared) {
                      await provider.deleteSharedJob(job);

                      // Force refresh the UI
                      setState(() {});

                      // Also refresh the jobs list in JobsProvider
                      await Provider.of<JobsProvider>(
                        context,
                        listen: false,
                      ).refreshJobs();
                    } else {
                      await Provider.of<JobsProvider>(
                        context,
                        listen: false,
                      ).deleteJob(job.id);
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(settingsProvider.translate('jobDeleted')),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: Text(
                  settingsProvider.translate('delete'),
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  void _showShareCodeDialog(Job job) {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(settingsProvider.translate('shareJobCode')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(settingsProvider.translate('askJobCreatorForCode')),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        job.connectionCode ?? '',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: job.connectionCode ?? ''),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                settingsProvider.translate('copyCode'),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => context.pop(),
                child: Text(settingsProvider.translate('close')),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final sharedJobsProvider = Provider.of<SharedJobsProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: settingsProvider.translate('sharedJobs'),
        showBackButton: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: settingsProvider.translate('mySharedJobs')),
            Tab(text: settingsProvider.translate('createSharedJob')),
            Tab(text: settingsProvider.translate('joinSharedJob')),
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
          // Join Job Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  settingsProvider.translate('enterJobCode'),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: settingsProvider.translate('connectionCode'),
                    hintText: 'ABC123',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(letterSpacing: 2),
                  maxLength: 6,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(_errorMessage!, style: TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _joinJob,
                  child:
                      _isLoading
                          ? CircularProgressIndicator()
                          : Text(settingsProvider.translate('joinJob')),
                ),
                if (sharedJobsProvider.isPaidUser)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.notifications),
                      label: Text(
                        settingsProvider.translate('viewPendingRequests'),
                      ),
                      onPressed: _navigateToJobRequests,
                    ),
                  ),
                ElevatedButton(
                  onPressed: () async {
                    final provider = Provider.of<SharedJobsProvider>(
                      context,
                      listen: false,
                    );
                    final code = _codeController.text.trim().toUpperCase();

                    if (code.isEmpty) {
                      setState(() {
                        _errorMessage = 'Please enter a connection code';
                      });
                      return;
                    }

                    try {
                      // Check if the job is private
                      final isPrivate = await provider.checkIfJobIsPrivate(
                        code,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Job is ${isPrivate ? 'private' : 'public'}',
                          ),
                        ),
                      );
                    } catch (e) {
                      setState(() {
                        _errorMessage = e.toString();
                      });
                    }
                  },
                  child: Text('Check Job Privacy'),
                ),
              ],
            ),
          ),

          // Create Job Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!sharedJobsProvider.isPaidUser) ...[
                  Card(
                    color: Colors.amber.shade100,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            settingsProvider.translate('paidFeature'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            settingsProvider.translate(
                              'upgradeToCreateSharedJobs',
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              // Navigate to subscription screen
                            },
                            child: Text(settingsProvider.translate('upgrade')),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Text(
                  settingsProvider.translate('createSharedJob'),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: settingsProvider.translate('jobName'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  settingsProvider.translate('selectJobColor'),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children:
                      _colorOptions.map((color) {
                        final isSelected = _selectedColor.value == color.value;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedColor = color;
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
                          ),
                        );
                      }).toList(),
                ),
                SwitchListTile(
                  title: Text(settingsProvider.translate('publicJob')),
                  subtitle: Text(
                    settingsProvider.translate('publicJobDescription'),
                  ),
                  value: _isPublic,
                  onChanged: (value) {
                    setState(() {
                      _isPublic = value;
                    });
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(_errorMessage!, style: TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed:
                      sharedJobsProvider.isPaidUser && !_isLoading
                          ? _createSharedJob
                          : null,
                  child:
                      _isLoading
                          ? const CircularProgressIndicator()
                          : Text(settingsProvider.translate('createJob')),
                ),
                if (sharedJobsProvider.isPaidUser)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.notifications),
                      label: Text(
                        settingsProvider.translate('viewPendingRequests'),
                      ),
                      onPressed: _navigateToJobRequests,
                    ),
                  ),
              ],
            ),
          ),

          // My Shared Jobs Tab
          _buildSharedJobsList(),
        ],
      ),
    );
  }

  Widget _buildSharedJobsList() {
    final provider = Provider.of<SharedJobsProvider>(context);

    return ListView.builder(
      itemCount: provider.sharedJobs.length,
      itemBuilder: (context, index) {
        final Job job = provider.sharedJobs[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: job.color,
              child: Text(
                job.name.substring(0, 1).toUpperCase(),
                style: TextStyle(color: Colors.white),
              ),
            ),
            title: Text(job.name),
            subtitle: Text(
              job.isPublic
                  ? provider.translate('publicJob')
                  : provider.translate('privateJob'),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.share),
                  onPressed: () {
                    _showShareCodeDialog(job);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () {
                    _showDeleteJobDialog(job);
                  },
                ),
              ],
            ),
            onTap: () {
              context.push('/job-overview', extra: {'job': job});
            },
          ),
        );
      },
    );
  }
}
