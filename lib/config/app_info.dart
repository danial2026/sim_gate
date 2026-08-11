import 'package:package_info_plus/package_info_plus.dart';

/// Runtime app metadata.
///
/// Loaded once at startup from `package_info_plus` so the version and build
/// number come from the single source of truth (the `version:` field in
/// `pubspec.yaml`) instead of being hardcoded in Dart. The same value also
/// drives the Android APK version (`flutter.versionName`/`versionCode`).
class AppInfo {
  AppInfo({required this.version, required this.buildNumber});

  /// Reads the version + build number from the platform package info.
  static Future<AppInfo> load() async {
    final info = await PackageInfo.fromPlatform();
    return AppInfo(
      version: info.version,
      buildNumber: int.tryParse(info.buildNumber) ?? 0,
    );
  }

  final String version;
  final int buildNumber;
}
