import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

String _safeFileName(String title) {
  return title
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .trim()
      .replaceAll(RegExp(r'\s+'), '_');
}

/// Dio ghi trực tiếp vào thư mục tài liệu ứng dụng.
Future<String> downloadMp3WithDio({
  required String url,
  required String title,
}) async {
  final dio = Dio();
  final dir = await getApplicationDocumentsDirectory();
  final name = '${_safeFileName(title)}.mp3';
  final path = '${dir.path}${Platform.pathSeparator}$name';
  await dio.download(url, path);
  return path;
}
