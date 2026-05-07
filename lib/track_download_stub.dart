/// Fallback khi không có `dart:html` hay `dart:io`.
Future<String> downloadMp3WithDio({
  required String url,
  required String title,
}) async {
  throw UnsupportedError('Tải xuống không hỗ trợ trên nền tảng này.');
}
