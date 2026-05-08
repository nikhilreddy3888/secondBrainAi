import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_colors.dart';

class DashboardSearchBar extends StatelessWidget {
  const DashboardSearchBar({
    super.key,
    required this.controller,
  });

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.borderColor),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: colors.textColor),
        decoration: InputDecoration(
          hintText: 'Search notes, passwords, events, doc...',
          hintStyle: TextStyle(color: colors.subtextColor),
          prefixIcon: Icon(
            Icons.search,
            color: colors.subtextColor,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          final query = value.trim();
          if (query.isNotEmpty) {
            context.push('/search', extra: query);
          }
        },
      ),
    );
  }
}
