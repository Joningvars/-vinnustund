import 'package:flutter/material.dart';

class StyledDropdown<T> extends StatelessWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;
  final String? hint;
  final Widget? prefix;
  final bool isExpanded;
  final double? width;
  final EdgeInsets? contentPadding;
  final Color? backgroundColor;

  const StyledDropdown({
    Key? key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.prefix,
    this.isExpanded = true,
    this.width,
    this.contentPadding,
    this.backgroundColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: backgroundColor ?? Theme.of(context).cardTheme.color,
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
      child: DropdownButtonFormField<T>(
        value: value,
        onChanged: onChanged,
        items: items,
        decoration: InputDecoration(
          contentPadding:
              contentPadding ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          prefixIcon: prefix,
        ),
        dropdownColor: backgroundColor ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        elevation: 4,
        isExpanded: isExpanded,
        menuMaxHeight: 300,
        alignment: AlignmentDirectional.bottomStart,
        hint: hint != null ? Text(hint!) : null,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 15,
        ),
      ),
    );
  }
}
