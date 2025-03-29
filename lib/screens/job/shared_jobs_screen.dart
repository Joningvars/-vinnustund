import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/models/job.dart';
import 'package:timagatt/providers/shared_jobs_provider.dart';
import 'package:timagatt/providers/time_entries_provider.dart';
import 'package:flutter/services.dart';
import 'package:timagatt/screens/job/job_requests_screen.dart';
import 'package:badges/badges.dart' as badges;

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
    final provider = Provider.of<SharedJobsProvider>(context, listen: false);
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
      final job = await provider.joinJobByCode(code);
      if (job != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully joined ${job.name}')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createSharedJob() async {
    final provider = Provider.of<SharedJobsProvider>(context, listen: false);
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
      if (!provider.isPaidUser) {
        setState(() {
          _errorMessage = 'Only paid users can create shared jobs';
        });
        return;
      }

      final job = await provider.createSharedJob(
        name,
        _selectedColor,
        isPublic: _isPublic,
      );

      if (mounted) {
        // Show dialog with the connection code
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => AlertDialog(
                title: Text('Job Created'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Share this connection code with your team:'),
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
                            job.connectionCode!,
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
                                ClipboardData(text: job.connectionCode!),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Code copied to clipboard'),
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
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Return to previous screen
                    },
                    child: const Text('Done'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToJobRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const JobRequestsScreen()),
    );
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
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SharedJobsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(provider.translate('sharedJobs')),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: provider.translate('joinJob')),
            Tab(text: provider.translate('createJob')),
            Tab(text: provider.translate('mySharedJobs')),
          ],
        ),
        actions: [
          FutureBuilder<int>(
            future: provider.getPendingRequestCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return count > 0
                  ? IconButton(
                    icon: Badge(
                      label: Text(count.toString()),
                      child: Icon(Icons.notifications),
                    ),
                    onPressed: _navigateToJobRequests,
                  )
                  : SizedBox.shrink();
            },
          ),
        ],
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
                  provider.translate('enterJobCode'),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    labelText: provider.translate('connectionCode'),
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
                          ? const CircularProgressIndicator()
                          : Text(provider.translate('joinJob')),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                if (provider.isPaidUser)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.notifications),
                      label: Text(provider.translate('viewPendingRequests')),
                      onPressed: _navigateToJobRequests,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
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
                if (!provider.isPaidUser) ...[
                  Card(
                    color: Colors.amber.shade100,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            provider.translate('paidFeature'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(provider.translate('upgradeToCreateSharedJobs')),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              // Navigate to subscription screen
                            },
                            child: Text(provider.translate('upgrade')),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                Text(
                  provider.translate('createSharedJob'),
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: provider.translate('jobName'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  provider.translate('selectJobColor'),
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
                  title: Text(provider.translate('publicJob')),
                  subtitle: Text(provider.translate('publicJobDescription')),
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
                      provider.isPaidUser && !_isLoading
                          ? _createSharedJob
                          : null,
                  child:
                      _isLoading
                          ? const CircularProgressIndicator()
                          : Text(provider.translate('createJob')),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                if (provider.isPaidUser)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.notifications),
                      label: Text(provider.translate('viewPendingRequests')),
                      onPressed: _navigateToJobRequests,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
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
        final job = provider.sharedJobs[index];
        return ListTile(
          leading: CircleAvatar(backgroundColor: job.color),
          title: Text(job.name),
          subtitle: Text(job.connectionCode ?? ''),
          trailing:
              job.creatorId == provider.currentUserId
                  ? IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _showDeleteConfirmation(job),
                  )
                  : null,
        );
      },
    );
  }
}
