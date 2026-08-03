import 'package:flutter/material.dart';

import '../core/app_constants.dart';

class KristalShell extends StatelessWidget {
  const KristalShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.actions = const <Widget>[],
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06111D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF142B42),
        elevation: 0,
        title: const Text(
          AppConstants.developerCredit,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: actions,
      ),
      body: Column(
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            decoration: const BoxDecoration(
              color: Color(0xFF18344F),
              border: Border(
                bottom: BorderSide(color: Color(0xFF26577D)),
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E88C6).withOpacity(0.24),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF3EC6FF)),
                  ),
                  child: Icon(icon, color: const Color(0xFF73D7FF), size: 30),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFFB7D7F1),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Image.asset(
                  AppConstants.hmrLogoPath,
                  width: 54,
                  height: 54,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.local_hospital,
                    color: Color(0xFF73D7FF),
                    size: 42,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
