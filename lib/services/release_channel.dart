/// 发布渠道配置。
///
/// 源码仓库可以设为私有，APK 与 Release 则放在一个公开的「发布仓库」里，
/// 方便任何人下载、也方便应用内检查更新（GitHub API 对私有仓库要求令牌）。
///
/// CI 通过 `--dart-define=RELEASE_REPO=owner/name` 注入实际值：
/// 源码仓库公开时就是它自己，转私有后指向那个公开仓库即可，无需改代码。
const String kReleaseRepo = String.fromEnvironment(
  'RELEASE_REPO',
  defaultValue: 'singleton-altman/musixandroid',
);

/// 最新 Release 的 API 地址。
const String kLatestReleaseApi =
    'https://api.github.com/repos/$kReleaseRepo/releases/latest';

/// 最新 APK 的直链（Release 资产名固定为 app-release.apk）。
const String kLatestApkUrl =
    'https://github.com/$kReleaseRepo/releases/latest/download/app-release.apk';
