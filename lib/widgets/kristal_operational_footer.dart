import 'package:flutter/material.dart';

import '../core/kristal_operational_rules.dart';

class KristalOperationalFooter extends StatelessWidget {
  const KristalOperationalFooter({
    super.key,
    this.status,
    this.showStatus = true,
  });

  final String? status;
  final bool showStatus;

  bool get _hasStatus => showStatus && (status?.trim().isNotEmpty ?? false);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      color: const Color(0xFF06111D),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _hasStatus
                ? Text(
                    status!.trim(),
                    textAlign: TextAlign.left,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFFFC857),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const Text(
            KristalOperationalRules.fullDeveloperCredit,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFFFC857),
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
          const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }
}
