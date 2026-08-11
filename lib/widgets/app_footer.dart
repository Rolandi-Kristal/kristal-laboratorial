import 'package:flutter/material.dart';
import '../core/app_constants.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(8),
      child: Text(AppConstants.developerCredit,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white70, fontWeight: FontWeight.bold)));
}
