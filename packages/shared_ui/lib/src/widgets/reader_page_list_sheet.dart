import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:kernel/kernel.dart';

/// Bottom-sheet page index for formats that expose a visual page list
/// (comics, PDF thumbnails): a thumbnail grid the user can jump from.
///
/// The sheet itself is chrome-agnostic; any header actions (e.g. a reading
/// direction toggle) are passed in by the caller via [headerActions].
class ReaderPageListSheet extends StatelessWidget {
  const ReaderPageListSheet({
    super.key,
    required this.source,
    required this.onSelectPage,
    this.headerActions = const <Widget>[],
    this.title = '页列表',
  });

  /// Page image/title source (usually the reader session itself).
  final ReaderPageIndexSource source;

  final ValueChanged<int> onSelectPage;

  /// Extra actions rendered in the sheet header (e.g. a direction toggle).
  final List<Widget> headerActions;

  final String title;

  @override
  Widget build(BuildContext context) {
    final source = this.source;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ...headerActions,
                IconButton(
                  tooltip: '关闭',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 140,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: source.pageCount,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    onSelectPage(index);
                  },
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: FutureBuilder<Uint8List?>(
                            future: source.loadPageImage(index),
                            builder: (context, snapshot) {
                              final bytes = snapshot.data;
                              if (bytes == null) {
                                return Container(
                                  color: Colors.black12,
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                );
                              }
                              return Image.memory(
                                bytes,
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                filterQuality: FilterQuality.low,
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        source.pageTitle(index),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
