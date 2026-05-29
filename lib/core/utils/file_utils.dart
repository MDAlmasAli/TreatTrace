// file_utils.dart — helpers for detecting file types from Supabase signed URLs.

const _imageExts = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'};

bool isImageUrl(String url) {
  final ext = extFromUrl(url);
  return _imageExts.contains(ext);
}

String extFromUrl(String url) {
  final path = url.split('?').first;
  final dotIdx = path.lastIndexOf('.');
  return dotIdx == -1 ? '' : path.substring(dotIdx + 1).toLowerCase();
}
