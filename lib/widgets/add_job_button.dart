import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timagatt/providers/jobs_provider.dart';

class AddJobButton extends StatelessWidget {
  const AddJobButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final jobsProvider = Provider.of<JobsProvider>(context);

    return IconButton(
      onPressed: () {
        // Navigate to Jobs screen with a parameter to indicate which tab to open
        Navigator.of(
          context,
        ).pushNamed('/jobs', arguments: {'initialTab': 2}).then((_) {
          // This will run when returning from the Jobs screen
          // Force a rebuild of the home screen to reflect any changes
          (context as Element).markNeedsBuild();
        });
      },
      icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.grey),
      tooltip: jobsProvider.translate('addJob'),
    );
  }
}
