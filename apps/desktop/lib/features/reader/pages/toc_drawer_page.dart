import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class TocDrawerPage extends StatelessWidget {
  const TocDrawerPage({super.key, required this.bookUid});

  final String bookUid;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.openToc)),
      body: Center(
        child: Text(
          l10n.tocPageComingSoon(bookUid),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
