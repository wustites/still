import 'media_kind.dart';

enum MediaSort { name, modified, added, duration, lastPlayed }

extension MediaSortLabel on MediaSort {
  String get label => switch (this) {
    MediaSort.name => '名称',
    MediaSort.modified => '修改时间',
    MediaSort.added => '加入时间',
    MediaSort.duration => '时长',
    MediaSort.lastPlayed => '最近播放',
  };
}

/// Everything needed to describe one library query. Value equality lets the
/// page avoid resubscribing to an identical drift stream on rebuild.
class MediaFilter {
  const MediaFilter({
    this.rootId,
    this.kind,
    this.favoritesOnly = false,
    this.recentOnly = false,
    this.query = '',
    this.sort = MediaSort.name,
    this.limit,
  });

  final int? rootId;
  final MediaKind? kind;
  final bool favoritesOnly;
  final bool recentOnly;
  final String query;
  final MediaSort sort;
  final int? limit;

  MediaFilter copyWith({
    int? rootId,
    MediaKind? kind,
    bool? favoritesOnly,
    bool? recentOnly,
    String? query,
    MediaSort? sort,
    int? limit,
    bool clearRoot = false,
    bool clearKind = false,
  }) {
    return MediaFilter(
      rootId: clearRoot ? null : (rootId ?? this.rootId),
      kind: clearKind ? null : (kind ?? this.kind),
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      recentOnly: recentOnly ?? this.recentOnly,
      query: query ?? this.query,
      sort: sort ?? this.sort,
      limit: limit ?? this.limit,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is MediaFilter &&
        other.rootId == rootId &&
        other.kind == kind &&
        other.favoritesOnly == favoritesOnly &&
        other.recentOnly == recentOnly &&
        other.query == query &&
        other.sort == sort &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(
    rootId,
    kind,
    favoritesOnly,
    recentOnly,
    query,
    sort,
    limit,
  );
}
