import 'package:flutter/material.dart';

/// 阅读主题 → 页面背景色(与 mobile 阅读壳的 palette 同款三色)。
///
/// 漫画/PDF 等整页型视图此前把阅读区硬编码成黑/白,导致切换 day/night/sepia
/// 时"页面背后的底色"不跟主题走。统一用这里解析,让所有引擎的整页背景
/// 跟随阅读主题。
Color resolveReaderBackground(String theme) {
  switch (theme.toLowerCase()) {
    case 'night':
    case 'dark':
      return const Color(0xFF0F1115);
    case 'sepia':
    case 'tea':
      return const Color(0xFFF4ECD8);
    default:
      return Colors.white;
  }
}

/// 单页内容(漫画页图 / PDF 页)自身的底色:暗色主题下给近黑,
/// 亮/米色下给白,让扫描页边缘融入背景而不是突兀一块。
Color resolveReaderContentBackground(String theme) {
  switch (theme.toLowerCase()) {
    case 'night':
    case 'dark':
      return const Color(0xFF14161A);
    default:
      return Colors.white;
  }
}
