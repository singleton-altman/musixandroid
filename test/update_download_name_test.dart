import 'package:flutter_test/flutter_test.dart';

import 'package:musix/services/app_update.dart';

/// 每个 release 的 asset 都叫 `app-release.apk`，落盘名如果沿用 asset 名，
/// 磁盘上就有多份同名安装包、无法分辨版本 —— 用户就是这样重复装到老包的。
/// 落盘名必须带上 build 标签和展示版本。
void main() {
  group('downloadFileName', () {
    test('folds build tag and display version into the name', () {
      final name = AppUpdateService.downloadFileName(
        Uri.parse(
            'https://github.com/singleton-altman/musixandroid/releases/download/build-70/app-release.apk'),
        '0.8.12(002)',
      );
      expect(name, 'musix-build-70-0.8.12(002).apk');
    });

    test('distinct versions never share a file name', () {
      final a = AppUpdateService.downloadFileName(
        Uri.parse(
            'https://github.com/singleton-altman/musixandroid/releases/download/build-69/app-release.apk'),
        '0.8.12(001)',
      );
      final b = AppUpdateService.downloadFileName(
        Uri.parse(
            'https://github.com/singleton-altman/musixandroid/releases/download/build-70/app-release.apk'),
        '0.8.12(002)',
      );
      expect(a, isNot(b));
    });

    test('falls back to the asset stem when no label is given', () {
      final name = AppUpdateService.downloadFileName(
        Uri.parse(
            'https://github.com/singleton-altman/musixandroid/releases/download/build-70/app-release.apk'),
        '',
      );
      expect(name, 'musix-build-70.apk');
    });

    test('sanitises unexpected characters instead of failing', () {
      final name = AppUpdateService.downloadFileName(
        Uri.parse('https://example.com/download/build-71/app-release.apk'),
        '1.0.0 beta/预览',
      );
      expect(name, endsWith('.apk'));
      expect(name, isNot(contains('/')));
      expect(name, isNot(contains(' ')));
    });

    test('keeps a unique name when the url carries no tag', () {
      final name = AppUpdateService.downloadFileName(
        Uri.parse('https://example.com/app-release.apk'),
        '',
      );
      expect(name, startsWith('musix-update-'));
      expect(name, endsWith('.apk'));
    });
  });
}
