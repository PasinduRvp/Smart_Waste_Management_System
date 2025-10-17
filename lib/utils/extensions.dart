extension DateTimeExtensions on DateTime {
  bool isToday() {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  bool isTomorrow() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return year == tomorrow.year &&
        month == tomorrow.month &&
        day == tomorrow.day;
  }

  bool isWithinDays(int days) {
    final limit = DateTime.now().add(Duration(days: days));
    return isBefore(limit) && isAfter(DateTime.now());
  }

  String toFormattedString() {
    return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
  }

  String toReadableString() {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '$day ${months[month - 1]}, $year';
  }

  int getDaysUntil() {
    final now = DateTime.now();
    final diffDuration  = difference(now);
    return diffDuration .inDays;
  }
}