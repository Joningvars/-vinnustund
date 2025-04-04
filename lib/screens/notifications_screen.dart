import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/providers/settings_provider.dart';
import 'package:timagatt/providers/shared_jobs_provider.dart';
import 'package:timagatt/widgets/common/custom_app_bar.dart';
import 'package:timagatt/screens/job/job_requests_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _pendingRequestCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPendingRequestCount();
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: settingsProvider.translate('notifications'),
        showBackButton: true,
        notificationCount: _pendingRequestCount,
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
          const JobRequestsScreen(showAppBar: false),
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
}
