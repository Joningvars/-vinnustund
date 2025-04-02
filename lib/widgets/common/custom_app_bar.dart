import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool showBackButton;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;
  final double? scrolledUnderElevation;

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
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      title: Text(
        title.toString(),
        style: theme.textTheme.titleLarge?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: foregroundColor ?? theme.colorScheme.onSurface,
        ),
      ),
      actions: actions,
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
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(bottom != null ? kToolbarHeight + 48 : kToolbarHeight);
}
