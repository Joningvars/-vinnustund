import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/providers/time_clock_provider.dart';
import 'package:timagatt/services/database_service.dart';

class JobRequestsScreen extends StatefulWidget {
  const JobRequestsScreen({Key? key}) : super(key: key);

  @override
  _JobRequestsScreenState createState() => _JobRequestsScreenState();
}

class _JobRequestsScreenState extends State<JobRequestsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final provider = Provider.of<TimeClockProvider>(context, listen: false);
      final requests = await provider.getPendingJoinRequests();

      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _respondToRequest(String requestId, bool approve) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = Provider.of<TimeClockProvider>(context, listen: false);
      await provider.respondToJoinRequest(requestId, approve);

      // Remove the request from the list
      setState(() {
        _requests.removeWhere((request) => request['id'] == requestId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? 'Request approved. User has been added to the job.'
                : 'Request denied.',
          ),
          backgroundColor: approve ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TimeClockProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(provider.translate('pendingRequests')),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRequests),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red),
                ),
              )
              : _requests.isEmpty
              ? Center(child: Text(provider.translate('noRequests')))
              : ListView.builder(
                itemCount: _requests.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final request = _requests[index];
                  return _buildRequestCard(request);
                },
              ),
      floatingActionButton: ElevatedButton(
        onPressed: () async {
          try {
            // Test write access to joinRequests collection
            final testDoc = await FirebaseFirestore.instance
                .collection('joinRequests')
                .add({'test': true, 'timestamp': FieldValue.serverTimestamp()});

            // If successful, delete the test document
            await testDoc.delete();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Firestore rules test passed!')),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Firestore rules test failed: $e')),
            );
          }
        },
        child: Text('Test Firestore Rules'),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final provider = Provider.of<TimeClockProvider>(context);
    final timestamp = request['timestamp'] as Timestamp?;
    final date =
        timestamp != null
            ? DateFormat.yMMMd().add_jm().format(timestamp.toDate())
            : 'Unknown date';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, size: 20),
                const SizedBox(width: 8),
                FutureBuilder<String>(
                  future: _getUserName(request['requesterId']),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Text('Loading user...');
                    }
                    return Text(
                      snapshot.data ?? 'Unknown user',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.work, size: 20),
                const SizedBox(width: 8),
                FutureBuilder<String>(
                  future: _getJobName(request['jobId']),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Text('Loading job...');
                    }
                    return Text(snapshot.data ?? 'Unknown job');
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 20),
                const SizedBox(width: 8),
                Text(date),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _respondToRequest(request['id'], false),
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: Text(provider.translate('denyRequest')),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _respondToRequest(request['id'], true),
                  icon: const Icon(Icons.check),
                  label: Text(provider.translate('approveRequest')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _getUserName(String userId) async {
    try {
      final provider = Provider.of<TimeClockProvider>(context, listen: false);
      if (provider.currentUserId == null) {
        return 'Unknown user';
      }
      final db = DatabaseService(uid: provider.currentUserId!);
      final userData = await db.getUserData(userId);
      return userData?['name'] ?? 'Unknown user';
    } catch (e) {
      print('Error getting user name: $e');
      return 'Unknown user';
    }
  }

  Future<String> _getJobName(String jobId) async {
    try {
      final provider = Provider.of<TimeClockProvider>(context, listen: false);
      final job = provider.jobs.firstWhere((job) => job.id == jobId);
      return job.name;
    } catch (e) {
      return 'Unknown job';
    }
  }
}
