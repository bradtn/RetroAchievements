const monthNames = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];

const monthNamesShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                         'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String formatMonth(DateTime date) {
  return '${monthNames[date.month - 1]} ${date.year}';
}

String formatDate(DateTime date) {
  return '${monthNamesShort[date.month - 1]} ${date.day}, ${date.year}';
}

String formatTime(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return '';
  try {
    var date = DateTime.parse(dateStr);
    date = DateTime.utc(date.year, date.month, date.day, date.hour, date.minute, date.second).toLocal();
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute $amPm';
  } catch (_) {
    return '';
  }
}

bool isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
