import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_domain/domain.dart';
import 'package:go_router/go_router.dart';

import '../../../di/providers.dart';
import '../../../di/repositories_providers.dart';
import '../../../routes/route_paths.dart';

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryAsync = ref.watch(libraryIndexProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            onPressed: () => _importBook(context, ref),
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Import',
          ),
        ],
      ),
      body: libraryAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No books yet. Tap import.'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final progress =
                  ((item.cachedProgress ?? 0) * 100).toStringAsFixed(1);
              return ListTile(
                title: Text(item.title),
                subtitle: Text('${item.format} · $progress%'),
                onTap: () => context.push(RoutePaths.reader(item.bookUid)),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Failed to load library: $error')),
      ),
    );
  }

  Future<void> _importBook(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const [
        'epub',
        'pdf',
        'ldf',
        'zip',
        'cbz',
        'webpub',
        'lpf',
        'mp3',
        'm4b',
      ],
    );

    final path = picked?.files.single.path;
    if (path == null) {
      return;
    }

    final appSettings =
        await ref.read(settingsRepositoryProvider).getAppSettings();
    final result = await ref.read(importRepositoryProvider).importBookFromFile(
          path,
          debugMode: appSettings.debugImport,
        );

    ref.invalidate(libraryIndexProvider);

    if (!context.mounted) {
      return;
    }

    final message = result.alreadyImported
        ? 'Already imported: ${result.bookUid}'
        : result.task.status == ImportTaskStatus.success
            ? 'Imported: ${result.bookUid}'
            : 'Import failed: ${result.task.errorMessage}';

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
