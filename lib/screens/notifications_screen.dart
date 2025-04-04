import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/providers/settings_provider.dart';
import 'package:timagatt/providers/shared_jobs_provider.dart';
import 'package:timagatt/providers/jobs_provider.dart';
import 'package:timagatt/widgets/common/custom_app_bar.dart';
import 'package:timagatt/screens/job/job_requests_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timagatt/screens/job_overview_screen.dart';
import 'package:timagatt/models/job.dart';

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
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      print('🔄 Loading notifications...');
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .collection('notifications')
              .orderBy('createdAt', descending: true)
              .get();

      print('📝 Found ${snapshot.docs.length} notifications');

      if (mounted) {
        setState(() {
          _notifications =
              snapshot.docs.map((doc) {
                final data = doc.data();
                data['id'] = doc.id;
                print('📌 Notification data: $data');
                return data;
              }).toList();
        });
      }
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
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _pendingRequestCount.toString(),
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
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

        final type = notification['type'];
        final status = notification['status'];
        print('📌 Type: $type, Status: $status');

        // Handle both job_invitation and joinRequest types
        if (type == 'job_invitation' || type == 'joinRequest') {
          print('✅ Building notification card');
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                child: Icon(Icons.work_outline, color: Colors.blue.shade700),
              ),
              title: Text(notification['jobName'] ?? 'Unknown Job'),
              subtitle:
                  notification['requesterName'] != null
                      ? Text(
                        settingsProvider
                            .translate('wantsToJoinJob')
                            .replaceAll(
                              '{name}',
                              notification['requesterName'],
                            ),
                        style: TextStyle(color: Colors.grey[700]),
                      )
                      : notification['senderName'] != null
                      ? Text(
                        settingsProvider
                            .translate('invitedYouToJob')
                            .replaceAll('{name}', notification['senderName']),
                        style: TextStyle(color: Colors.grey[700]),
                      )
                      : Text(
                        settingsProvider.translate('someoneWantsToJoin'),
                        style: TextStyle(color: Colors.grey[700]),
                      ),
              trailing:
                  status == 'pending'
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
                                notification['status'] = 'accepted';
                              });

                              // Remove the notification after a delay
                              Future.delayed(Duration(seconds: 2), () {
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
                                notification['status'] = 'rejected';
                              });

                              // Remove the notification after a delay
                              Future.delayed(Duration(seconds: 2), () {
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
                      : Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color:
                              status == 'accepted'
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status == 'accepted'
                              ? settingsProvider.translate('accepted')
                              : settingsProvider.translate('rejected'),
                          style: TextStyle(
                            color:
                                status == 'accepted'
                                    ? Colors.green
                                    : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
            ),
          );
        }

        print('⚠️ Unhandled notification type: $type');
        return const SizedBox.shrink();
      },
    );
  }
}
