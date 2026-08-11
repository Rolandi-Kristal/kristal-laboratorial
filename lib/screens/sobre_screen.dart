import 'package:flutter/material.dart';

import '../core/kristal_operational_rules.dart';

import '../core/app_constants.dart';

class SobreScreen extends StatelessWidget {
  const SobreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sobre o Sistema'),
      ),
      body: const Center(
        child: SizedBox(
          width: 720,
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.biotech, size: 88),
                  SizedBox(height: 18),
                  Text(
                    AppConstants.appName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    AppConstants.appSubtitle,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    AppConstants.institutionName,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 18),
                  Text('Versão: ${AppConstants.version}'),
                  SizedBox(height: 18),
                  Divider(),
                  SizedBox(height: 8),
                  Text(
                    KristalOperationalRules.fullDeveloperCredit,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
