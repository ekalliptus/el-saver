class MediaFileUtils {
  static String? detectExtension(List<int> bytes) {
    if (bytes.length < 8) return null;
    if (bytes[4] == 0x66 &&
        bytes[5] == 0x74 &&
        bytes[6] == 0x79 &&
        bytes[7] == 0x70) {
      return '.mp4';
    }
    if (bytes[0] == 0x1A &&
        bytes[1] == 0x45 &&
        bytes[2] == 0xDF &&
        bytes[3] == 0xA3) {
      return '.webm';
    }
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return '.jpg';
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return '.png';
    }
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes.length >= 12 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return '.webp';
    }
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) {
      return '.gif';
    }
    if ((bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) ||
        (bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0)) {
      return '.mp3';
    }
    return null;
  }

  static String validate({
    required List<int> bytes,
    required String? contentType,
    required int received,
    required int expected,
  }) {
    final type = (contentType ?? '').toLowerCase();
    if (type.contains('text/html') || type.contains('application/json')) {
      throw const FormatException('Server returned an error page');
    }
    final text = String.fromCharCodes(bytes.take(32)).trimLeft().toLowerCase();
    if (text.startsWith('<!doctype html') ||
        text.startsWith('<html') ||
        text.startsWith('{"error"') ||
        text.startsWith('{"detail"')) {
      throw const FormatException('Server returned an error body');
    }
    if (expected > 0 && received < expected * 0.95) {
      throw const FormatException('Incomplete download');
    }
    final extension = detectExtension(bytes);
    if (extension == null) throw const FormatException('Unknown media format');
    return extension;
  }

  static String filename(String id, String optionId, String extension) {
    final safeId = id.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final safeOption = optionId.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
    final ext = extension.startsWith('.') ? extension : '.$extension';
    return '${safeId}_${safeOption.isEmpty ? 'media' : safeOption}$ext';
  }
}
