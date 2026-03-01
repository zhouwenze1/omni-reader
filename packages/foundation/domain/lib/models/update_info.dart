enum UpdateChannel { stable, beta, nightly }

extension UpdateChannelX on UpdateChannel {
  String get value {
    switch (this) {
      case UpdateChannel.stable:
        return 'stable';
      case UpdateChannel.beta:
        return 'beta';
      case UpdateChannel.nightly:
        return 'nightly';
    }
  }
}

UpdateChannel updateChannelFromValue(Object? value) {
  switch (value?.toString().toLowerCase()) {
    case 'beta':
      return UpdateChannel.beta;
    case 'nightly':
      return UpdateChannel.nightly;
    default:
      return UpdateChannel.stable;
  }
}

class UpdateInfo {
  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    this.currentBuild,
    this.latestBuild,
    this.releaseNotes = '',
    this.downloadUrl,
    this.publishedAt,
    this.forceUpdate = false,
    this.channel = UpdateChannel.stable,
  });

  final String currentVersion;
  final String latestVersion;
  final String? currentBuild;
  final String? latestBuild;
  final String releaseNotes;
  final String? downloadUrl;
  final DateTime? publishedAt;
  final bool forceUpdate;
  final UpdateChannel channel;

  bool get hasUpdate => _compareSemver(latestVersion, currentVersion) > 0;

  UpdateInfo copyWith({
    String? currentVersion,
    String? latestVersion,
    String? currentBuild,
    String? latestBuild,
    String? releaseNotes,
    String? downloadUrl,
    DateTime? publishedAt,
    bool? forceUpdate,
    UpdateChannel? channel,
  }) {
    return UpdateInfo(
      currentVersion: currentVersion ?? this.currentVersion,
      latestVersion: latestVersion ?? this.latestVersion,
      currentBuild: currentBuild ?? this.currentBuild,
      latestBuild: latestBuild ?? this.latestBuild,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      forceUpdate: forceUpdate ?? this.forceUpdate,
      channel: channel ?? this.channel,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'currentVersion': currentVersion,
      'latestVersion': latestVersion,
      'currentBuild': currentBuild,
      'latestBuild': latestBuild,
      'releaseNotes': releaseNotes,
      'downloadUrl': downloadUrl,
      'publishedAt': publishedAt?.toIso8601String(),
      'forceUpdate': forceUpdate,
      'channel': channel.value,
    };
  }

  factory UpdateInfo.fromJson(Map<String, Object?> json) {
    return UpdateInfo(
      currentVersion: _asString(json['currentVersion']) ?? '0.0.0',
      latestVersion: _asString(json['latestVersion']) ?? '0.0.0',
      currentBuild: _asString(json['currentBuild']),
      latestBuild: _asString(json['latestBuild']),
      releaseNotes: _asString(json['releaseNotes']) ?? '',
      downloadUrl: _asString(json['downloadUrl']),
      publishedAt: _asDateTime(json['publishedAt']),
      forceUpdate: _asBool(json['forceUpdate']) ?? false,
      channel: updateChannelFromValue(json['channel']),
    );
  }
}

int _compareSemver(String left, String right) {
  final leftParts = left
      .split('.')
      .map((item) => int.tryParse(item) ?? 0)
      .toList();
  final rightParts = right
      .split('.')
      .map((item) => int.tryParse(item) ?? 0)
      .toList();
  final length = leftParts.length > rightParts.length
      ? leftParts.length
      : rightParts.length;
  for (var i = 0; i < length; i++) {
    final l = i < leftParts.length ? leftParts[i] : 0;
    final r = i < rightParts.length ? rightParts[i] : 0;
    if (l > r) return 1;
    if (l < r) return -1;
  }
  return 0;
}

String? _asString(Object? value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

bool? _asBool(Object? value) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
  }
  return null;
}

DateTime? _asDateTime(Object? value) {
  if (value is DateTime) {
    return value;
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value);
  }
  if (value is num) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}
