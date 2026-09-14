enum AppTheme { light, dark }

/// A timestamped preference, with a durable marker for pending remote writes.
class ThemePreference {
  const ThemePreference({
    this.theme = AppTheme.light,
    this.updatedAt = 0,
    this.pending = false,
  });

  final AppTheme theme;
  final int updatedAt;
  final bool pending;

  ThemePreference acknowledged() =>
      ThemePreference(theme: theme, updatedAt: updatedAt);

  Map<String, Object> toMap() => {
    'theme': theme.name,
    'updatedAt': updatedAt,
    'pending': pending,
  };

  factory ThemePreference.fromMap(Map<dynamic, dynamic> map) {
    final theme = map['theme'];
    final updatedAt = map['updatedAt'];
    if ((theme != 'light' && theme != 'dark') ||
        updatedAt is! int ||
        updatedAt < 0) {
      throw const FormatException('Invalid theme preference.');
    }
    return ThemePreference(
      theme: theme == 'dark' ? AppTheme.dark : AppTheme.light,
      updatedAt: updatedAt,
      pending: map['pending'] == true,
    );
  }
}
