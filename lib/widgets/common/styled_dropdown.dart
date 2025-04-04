import 'package:flutter/material.dart';
import 'package:timagatt/models/job.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/providers/settings_provider.dart';

class StyledDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;
  final String? hint;
  final String? emptyStateKey;
  final Widget? prefix;
  final bool isExpanded;
  final double? width;
  final EdgeInsets? contentPadding;
  final Color? backgroundColor;
  final Color? dropdownIconColor;

  const StyledDropdown({
    Key? key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.emptyStateKey = 'noJobsYet',
    this.prefix,
    this.isExpanded = true,
    this.width,
    this.contentPadding,
    this.backgroundColor,
    this.dropdownIconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final theme = Theme.of(context);

    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: backgroundColor ?? theme.colorScheme.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: backgroundColor ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonFormField<T>(
          value: value,
          onChanged: items.isEmpty ? null : onChanged,
          items:
              items.isEmpty
                  ? [
                    DropdownMenuItem<T>(
                      value: null,
                      child: Text(
                        settingsProvider.translate(emptyStateKey!),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ]
                  : items,
          decoration: InputDecoration(
            contentPadding:
                contentPadding ??
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            prefixIcon: prefix,
            hintText: items.isEmpty ? null : hint,
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          dropdownColor: backgroundColor ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          elevation: 4,
          isExpanded: isExpanded,
          menuMaxHeight: 300,
          alignment: AlignmentDirectional.bottomStart,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontSize: 15,
          ),
          icon: Icon(
            Icons.arrow_drop_down,
            color: dropdownIconColor ?? theme.colorScheme.onSurface,
          ),
          selectedItemBuilder: (context) {
            if (items.isEmpty) {
              return [
                Text(
                  settingsProvider.translate(emptyStateKey!),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ];
            }
            return items.map<Widget>((item) {
              if (item.value == null) {
                return Text(
                  hint ?? settingsProvider.translate('allJobs'),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }
              if (item.value is Job) {
                final job = item.value as Job;
                return Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: job.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(job.name),
                  ],
                );
              }
              return Text(item.value.toString());
            }).toList();
          },
        ),
      ),
    );
  }
}
