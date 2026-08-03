import 'package:flutter/material.dart';
import '../core/app_constants.dart';
class KristalLogoHeader extends StatelessWidget {
  final double logoHeight;
  const KristalLogoHeader({super.key, this.logoHeight = 170});
  @override Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Image.asset(AppConstants.logoPath, height: logoHeight, fit: BoxFit.contain, errorBuilder: (_,__,___)=> const Icon(Icons.biotech, size: 100)),
    const SizedBox(height: 10),
    const Text(AppConstants.appName, textAlign: TextAlign.center, style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
    const Text(AppConstants.appSubtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
    const SizedBox(height: 4),
    const Text('Versão ${AppConstants.version}', style: TextStyle(color: Colors.white38, fontSize: 12)),
  ]);
}
