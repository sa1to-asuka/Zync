/// 拍摄时间字符串归一化。
///
/// PTP 相机返回 `YYYYMMDDThhmmss`，EXIF 常见 `YYYY:MM:DD HH:MM:SS`，
/// 也有的来源已经格式化成 `YYYY.MM.DD HH:MM` 或使用 `-` 分隔。
/// 这里统一成 `YYYY.MM.DD HH:MM`，不做任何时区换算（PTP 是相机本地墙钟）。
String formatCaptureDate(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return '';

  final match = _dateTimePattern.firstMatch(text) ??
      _ptpPattern.firstMatch(text) ??
      _dateOnlyPattern.firstMatch(text);
  if (match == null) return text;

  final year = int.tryParse(match.group(1) ?? '');
  final month = int.tryParse(match.group(2) ?? '');
  final day = int.tryParse(match.group(3) ?? '');
  if (year == null || month == null || day == null) return text;
  // 相机未写入时间时常见 0000:00:00 00:00:00。
  if (year == 0 || month == 0 || day == 0) return '';
  if (month > 12 || day > 31) return text;

  var hour = 0;
  var minute = 0;
  if (match.groupCount >= 5) {
    hour = int.tryParse(match.group(4) ?? '') ?? 0;
    minute = int.tryParse(match.group(5) ?? '') ?? 0;
    if (hour > 23 || minute > 59) return text;
  }

  String two(int value) => value.toString().padLeft(2, '0');
  return '$year.${two(month)}.${two(day)} ${two(hour)}:${two(minute)}';
}

final RegExp _dateTimePattern = RegExp(
  r'^(\d{4})[:.\-/](\d{1,2})[:.\-/](\d{1,2})[ T](\d{1,2}):(\d{2})(?::(\d{2}))?',
);

final RegExp _ptpPattern = RegExp(
  r'^(\d{4})(\d{2})(\d{2})[T ](\d{2})(\d{2})(\d{2})',
);

final RegExp _dateOnlyPattern = RegExp(
  r'^(\d{4})[:.\-/](\d{1,2})[:.\-/](\d{1,2})$',
);
