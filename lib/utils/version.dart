import 'package:package_info_plus/package_info_plus.dart';

/// Simple semantic version representation and comparison.
class Version implements Comparable<Version> {
  final int major;
  final int minor;
  final int patch;

  const Version(this.major, this.minor, this.patch);

  factory Version.zero() => const Version(0, 0, 0);

  static Version parse(String? value) {
    if (value == null || value.trim().isEmpty) return Version.zero();
    final normalized = value.trim();

    // Strip any build metadata or pre-release (e.g., 1.2.3+45 or 1.2.3-beta)
    final core = normalized.split('+').first.split('-').first;
    final parts = core.split('.');

    int parsePart(String s) {
      final n = int.tryParse(s);
      return n == null || n < 0 ? 0 : n;
    }

    if (parts.isEmpty) return Version.zero();
    final maj = parsePart(parts[0]);
    final min = parts.length > 1 ? parsePart(parts[1]) : 0;
    final pat = parts.length > 2 ? parsePart(parts[2]) : 0;
    return Version(maj, min, pat);
  }

  @override
  int compareTo(Version other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator <(Version other) => compareTo(other) < 0;
  bool operator <=(Version other) => compareTo(other) <= 0;
  bool operator >(Version other) => compareTo(other) > 0;
  bool operator >=(Version other) => compareTo(other) >= 0;

  @override
  String toString() => '$major.$minor.$patch';
}

class VersionInfo {
  /// Returns the current application version parsed as [Version].
  /// Falls back to 0.0.0 when unknown.
  static Future<Version> current() async {
    try {
      final info = await PackageInfo.fromPlatform();
      // Prefer version; buildNumber may be appended by stores.
      return Version.parse(info.version);
    } catch (_) {
      return Version.zero();
    }
  }
}


