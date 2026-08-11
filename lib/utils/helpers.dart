import 'package:intl/intl.dart';

/// Small formatting helpers used across the UI.
class Formatters {
  Formatters._();

  /// Formats a [Duration] as `HH:MM:SS` (used for server uptime).
  static String formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  /// Formats a [DateTime] as an ISO-8601 UTC stamp (API responses).
  static String formatIso(DateTime dt) => dt.toUtc().toIso8601String();

  /// Human-friendly absolute timestamp.
  static String formatDateTime(DateTime dt) =>
      DateFormat('yyyy-MM-dd HH:mm:ss').format(dt.toLocal());

  /// Short relative time using intl plurals.
  static String formatRelative(DateTime dt, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final diff = reference.difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Formats a byte size into a human-readable string.
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
