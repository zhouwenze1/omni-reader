import 'dart:io';
import 'dart:typed_data';

import 'package:foundation_domain/domain.dart';

/// 书架索引端口(BookCloudManager 对书架元数据的读写),由 data 包实现。
abstract class BookCloudLibraryPort {
  Future<LibraryIndexEntry?> findByBookUid(String bookUid);

  Future<List<LibraryIndexEntry>> listAllEntries();

  Future<void> upsertEntry(LibraryIndexEntry entry);

  Future<void> setCloudStatus(String bookUid, CloudBackupStatus status);

  Future<void> setEvicted(String bookUid, {required bool evicted});

  Future<void> setPinLocal(String bookUid, {required bool pinned});

  Future<void> deleteIndexEntry(String bookUid);
}

/// 本地书文件端口(大文件的读取/释放/取回),由 data 包实现。
abstract class BookCloudFilesPort {
  /// 书架目录下导入时保留的原始文件;不存在返回 null。
  Future<File?> originalFile(String bookUid);

  /// 书架目录下封面文件;不存在返回 null。
  Future<File?> coverFile(String bookUid);

  /// 把云端拉到的封面字节写到本地(书架显示纯云端书的封面)。
  Future<void> saveCoverBytes(String bookUid, Uint8List bytes, String ext);

  /// 释放本地大文件:`books/<uid>` 解析产物 + `library/<uid>/original/`。
  Future<void> evictBookFiles(String bookUid);

  /// `books/<uid>/meta.json` 是否在(本地可打开的判定)。
  Future<bool> hasLocalArtifacts(String bookUid);

  /// 下载临时落点(取回过程中先落到临时目录)。
  Future<String> createTempOriginalFile(String bookUid, String ext);

  /// 用原始文件重建解析产物/缺失文件,保留进度标注;失败抛异常。
  Future<void> restoreFromOriginal({
    required String bookUid,
    required String originalPath,
  });
}

/// 网络状态端口:仅 Wi-Fi 模式下判断当前是否可传输。桌面端用恒真实现。
abstract class NetworkStatusPort {
  Future<bool> get canTransfer;
}

class AlwaysAllowNetwork implements NetworkStatusPort {
  const AlwaysAllowNetwork();

  @override
  Future<bool> get canTransfer async => true;
}
