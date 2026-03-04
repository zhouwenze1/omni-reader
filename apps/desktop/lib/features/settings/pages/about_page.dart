import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.about)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.menu_book, size: 64),
                    const SizedBox(height: 12),
                    Text(
                      l10n.appBrandName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.appVersionText),
                  ],
                ),
              ),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {},
              child: Text(l10n.checkForUpdates),
            ),
          ],
        ),
      ),
    );
  }
}
