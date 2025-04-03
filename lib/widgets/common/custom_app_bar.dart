import 'package:flutter/material.dart';
import 'package:timagatt/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/screens/notifications_screen.dart';
import 'package:timagatt/utils/navigation.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool showBackButton;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final double? scrolledUnderElevation;
  final bool showNotificationIcon;
  final bool showExportButton;
  final VoidCallback? onExportPressed;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
    this.showBackButton = false,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.scrolledUnderElevation,
    this.showNotificationIcon = true,
    this.showExportButton = false,
    this.onExportPressed,
  });

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);

    List<Widget> appBarActions = [];

    if (showExportButton) {
      appBarActions.add(
        IconButton(
          icon: const Icon(Icons.download),
          onPressed: onExportPressed,
        ),
      );
    }

    if (showNotificationIcon) {
      appBarActions.add(
        IconButton(
          icon: Stack(
            children: [
              const Icon(Icons.notifications_outlined),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 12,
                    minHeight: 12,
                  ),
                  child: const Text(
                    '3',
                    style: TextStyle(color: Colors.white, fontSize: 8),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
          onPressed: () {
            Navigation.push(context, const NotificationsScreen());
          },
        ),
      );
    }

    if (actions != null) {
      appBarActions.addAll(actions!);
    }

    return AppBar(
      title: Text(
        title.toString(),
        style: theme.textTheme.titleLarge?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: foregroundColor ?? theme.colorScheme.onSurface,
        ),
      ),
      actions: appBarActions,
      bottom: bottom,
      leading:
          showBackButton
              ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
              : null,
      backgroundColor: theme.scaffoldBackgroundColor,
      foregroundColor: foregroundColor ?? theme.colorScheme.onSurface,
      elevation: elevation ?? 0,
      scrolledUnderElevation: scrolledUnderElevation ?? 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: theme.textTheme.titleLarge?.color),
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(bottom != null ? kToolbarHeight + 48 : kToolbarHeight);
}
