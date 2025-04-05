import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/providers/settings_provider.dart';
import 'package:timagatt/providers/shared_jobs_provider.dart';
import 'package:timagatt/widgets/common/custom_app_bar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _pendingRequestCount = 0;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPendingRequestCount();
    _loadNotifications();
  }

  Future<void> _loadPendingRequestCount() async {
    final provider = Provider.of<SharedJobsProvider>(context, listen: false);
    final count = await provider.getPendingRequestCount();
    if (mounted) {
      setState(() {
        _pendingRequestCount = count;
      });
    }
  }

  Future<void> _loadNotifications() async {
    print('🔄 Loading notifications...');
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ No authenticated user');
        return;
      }

      // Query the root notifications collection
      final rootSnapshot =
          await FirebaseFirestore.instance
              .collection('notifications')
              .where('userId', isEqualTo: user.uid)
              .where('status', isEqualTo: 'pending')
              .get();

      print('📝 Found ${rootSnapshot.docs.length} notifications');
      _notifications = rootSnapshot.docs.map((doc) => doc.data()).toList();

      print('📋 Notifications data: $_notifications');
      if (_notifications.isEmpty) {
        print('❌ No notifications found');
      }

      setState(() {});
    } catch (e) {
      print('❌ Error loading notifications: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);
    final sharedJobsProvider = Provider.of<SharedJobsProvider>(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: settingsProvider.translate('notifications'),
        showBackButton: true,
        showNotificationIcon: false,
        showRefreshButton: _tabController.index == 2,
        onRefreshPressed:
            _tabController.index == 2 ? _loadPendingRequestCount : null,
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            if (index == 2) {
              _loadPendingRequestCount();
            }
          },
          tabs: [
            Tab(text: settingsProvider.translate('messages')),
            Tab(text: settingsProvider.translate('offers')),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(settingsProvider.translate('requests')),
                  if (_pendingRequestCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.only(
                        left: 6,
                        right: 6,
                        top: 8,
                        bottom: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          _pendingRequestCount.toString(),
                          style: TextStyle(
                            color: theme.colorScheme.onPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
          _buildNotificationList('messages'),
          _buildNotificationList('offers'),
          _buildJobRequestsList(),
        ],
      ),
    );
  }

  Widget _buildNotificationList(String type) {
    return Center(
      child: Text(
        Provider.of<SettingsProvider>(context).translate('noNotifications'),
        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
      ),
    );
  }

  Widget _buildJobRequestsList() {
    print('🔄 Building job requests list');
    print('📝 Notifications count: ${_notifications.length}');
    print('📋 Notifications data: $_notifications');

    final settingsProvider = Provider.of<SettingsProvider>(context);

    if (_notifications.isEmpty) {
      print('❌ No notifications found');
      return Center(
        child: Text(
          settingsProvider.translate('noNotifications'),
          style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        print('🔍 Processing notification: $notification');

        final data = notification['data'] ?? {};
        final type = data['type'] ?? 'unknown';
        final jobId = data['jobId'] ?? '';
        final jobName = notification['body']?.split('"')[1] ?? 'Unknown Job';
        final senderName = data['senderName'] ?? 'Someone';

        print(
          '📌 Type: $type, Job: $jobName, JobId: $jobId, Sender: $senderName',
        );

        String notificationText;
        if (type == 'job_invitation') {
          notificationText = settingsProvider
              .translate('invitedYouToJob')
              .replaceAll('{name}', senderName)
              .replaceAll('{job}', jobName);
        } else {
          notificationText = settingsProvider
              .translate('wantsToJoinJob')
              .replaceAll('{name}', senderName)
              .replaceAll('{job}', jobName);
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade50,
              child: Icon(Icons.work_outline, color: Colors.blue.shade700),
            ),
            title: Text(jobName),
            subtitle: Text(
              notificationText,
              style: TextStyle(color: Colors.grey[700]),
            ),
            trailing:
                !(notification['read'] ?? false)
                    ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline),
                          color: Colors.green,
                          onPressed: () async {
                            print('✅ Accepting invitation/request');
                            final sharedJobsProvider =
                                Provider.of<SharedJobsProvider>(
                                  context,
                                  listen: false,
                                );

                            await sharedJobsProvider.handleJobInvitation(
                              notification['id'],
                              true,
                            );

                            // Update the notification status locally
                            setState(() {
                              notification['read'] = true;
                            });

                            // Remove the notification after a delay
                            Future.delayed(const Duration(seconds: 2), () {
                              if (mounted) {
                                setState(() {
                                  _notifications.removeWhere(
                                    (n) => n['id'] == notification['id'],
                                  );
                                });
                              }
                            });
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel_outlined),
                          color: Colors.red,
                          onPressed: () async {
                            print('❌ Rejecting invitation/request');
                            final sharedJobsProvider =
                                Provider.of<SharedJobsProvider>(
                                  context,
                                  listen: false,
                                );

                            await sharedJobsProvider.handleJobInvitation(
                              notification['id'],
                              false,
                            );

                            // Update the notification status locally
                            setState(() {
                              notification['read'] = true;
                            });

                            // Remove the notification after a delay
                            Future.delayed(const Duration(seconds: 2), () {
                              if (mounted) {
                                setState(() {
                                  _notifications.removeWhere(
                                    (n) => n['id'] == notification['id'],
                                  );
                                });
                              }
                            });
                          },
                        ),
                      ],
                    )
                    : null,
          ),
        );
      },
    );
  }
}
