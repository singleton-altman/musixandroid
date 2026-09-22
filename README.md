<div align="center">

![MusicX](docs/banner.png)

# MusicX

**液态玻璃 UI 音乐播放器** —— 连接你的个人媒体库，全平台聚合、歌单管理、无缝续播，一个 App 畅听整个曲库。

[![Stars](https://img.shields.io/github/stars/singleton-altman/musixandroid?style=flat&color=7C6CFF)](https://github.com/singleton-altman/musixandroid/stargazers)
[![Forks](https://img.shields.io/github/forks/singleton-altman/musixandroid?style=flat&color=7C6CFF)](https://github.com/singleton-altman/musixandroid/network/members)
[![Issues](https://img.shields.io/github/issues/singleton-altman/musixandroid?style=flat&color=7C6CFF)](https://github.com/singleton-altman/musixandroid/issues)
[![Release](https://img.shields.io/github/v/release/singleton-altman/musixandroid?style=flat&color=7C6CFF&label=Release)](https://github.com/singleton-altman/musixandroid/releases/latest)
[![Last Commit](https://img.shields.io/github/last-commit/singleton-altman/musixandroid?style=flat&color=7C6CFF)](https://github.com/singleton-altman/musixandroid/commits/main)
[![Top Language](https://img.shields.io/github/languages/top/singleton-altman/musixandroid?style=flat&color=7C6CFF)](https://github.com/singleton-altman/musixandroid)

[⬇️ 下载 APK](https://github.com/singleton-altman/musixandroid/releases/latest) · [🐛 反馈问题](https://github.com/singleton-altman/musixandroid/issues) · [💡 功能建议](https://github.com/singleton-altman/musixandroid/issues)

`Flutter` `Android` `Liquid Glass` `Glassmorphism` `Music Player` `Self-hosted` `Material 3`

</div>

---

## 这是什么

给自托管音乐服务器用的 **Android 客户端**（纯 Flutter 实现）。服务器放在家里 / NAS / VPS 上，手机装这个 App，就能听歌、看歌单、追每日推荐、管理队列，不用再开电脑开网页。

## 功能

- **个人媒体库** —— 连接自托管音乐服务器，支持多平台账号绑定与订阅任务，随处无缝续播
- **全平台聚合** —— 猜你喜欢、每日推荐、每日私享，跨平台随机推荐封面轮换
- **液态玻璃 UI** —— 页面、弹层、播放条全场景玻璃质感，基于 `liquid_glass_widgets`
- **界面材质切换** —— 液态玻璃（折射透镜，默认）/ 毛玻璃（平磨砂）一键切换，实时生效并持久化
- **随机背景图** —— 多行背景图接口直链，模糊度（0–30px）与不透明度（20–100%）实时调节
- **22 款应用图标** —— 液态玻璃（默认）、经典霓虹、复古黑胶、霓虹耳机、复古磁带、吉他拨片、钢琴夜曲等，切换即时生效、数据不受影响
- **主题与显示模式** —— 多套主题色 + 浅色 / 深色 / 跟随系统
- **播放体验** —— 播放条快捷控制、队列管理、锁屏 / 通知媒体卡片、正在播放桌面小组件
- **在线升级** —— 应用内检查更新，多下载线路并行竞速 + 测速选择，后台下载不断歌，安装包完整性校验，失败自动回退直连

## 下载

到 [Releases](https://github.com/singleton-altman/musixandroid/releases/latest) 页面下载最新 APK 安装（Android 8.0+）。应用内「设置 → 检查更新」也能直接检测并在后台下载新版本。

## 环境要求

- Android 8.0+（minSdk 26）
- 已部署的自托管音乐服务器（Musix Hub 兼容 REST API）

## 使用说明

1. 首次启动输入自托管音乐服务器的**地址与密码**即可登录（默认 `http://127.0.0.1:8080`，连接信息仅用于访问你的个人音乐库）
2. 在 **设置 → 外观与主题** 中调整显示模式、界面材质、应用图标、主题色与背景图
3. 切换应用图标后桌面图标会稍作延迟刷新，应用数据不受影响

## 构建

构建使用 Flutter **3.47.4**（GitHub Actions 已固定此版本）。`liquid_glass_widgets 1.17.1` 要求 Flutter 至少 3.41.0，旧版 3.24 无法编译。

### 首次构建（Windows）

工程只包含手写的源码与 Android 配置，Gradle wrapper / gradlew / 启动图标等自动生成文件需由 Flutter 补齐：

```bash
# 1) 让 Flutter 生成 gradle wrapper、gradlew、图标等缺失的脚手架文件
#    （会保留已存在的 lib/、pubspec.yaml、android/app/src 下的手写文件）
flutter create --platforms=android --org com.musix .

# 2) 拉取依赖
flutter pub get

# 3) 构建 APK
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

> 若 `flutter create` 覆盖了 `AndroidManifest.xml`，用 git 恢复本仓库版本（内含 cleartext HTTP、音频前台服务、musicx:// deep link、桌面小组件声明）。

### 固定 APK 签名

Release 构建使用同一份 PKCS12 密钥，禁止回退到临时 debug 签名。GitHub Actions 从仓库 Secrets 恢复密钥：

- `ANDROID_KEYSTORE_BASE64`：PKCS12 文件的 Base64
- `ANDROID_KEYSTORE_PASSWORD`：密钥库密码
- `ANDROID_KEY_ALIAS`：别名
- `ANDROID_KEY_PASSWORD`：私钥密码

构建后使用 `apksigner verify` 校验 APK，并与 `android/signing-certificate.sha256` 的固定公钥指纹比较，签名不一致不会上传或发布。

本地构建从被 Git 忽略的 `android/key.properties` 读取 `storeFile`（绝对路径）、`storePassword`、`keyAlias` 和 `keyPassword`，也可使用对应的 `ANDROID_KEYSTORE_PATH` 等环境变量。**不要提交密钥库或密码文件。**

### 版本号规则

- 显示版本 `0.8.12(006)`：括号内是**同一基础版本的第 N 个构建**，基础版本（`pubspec.yaml` 的 `version`）升级后从 001 重新计数；失败或取消的构建不占序号。
- Android `versionCode` = 全局构建号 + `android/version.properties` 的 `versionCodeOffset`（历史偏移 42），始终递增，保证任何已装版本都能被新包覆盖升级。
- 仓库迁移后 `GITHUB_RUN_NUMBER` 从 1 重算，`scripts/version_scheme.py` 的 `RUN_NUMBER_EPOCH = 73` 负责平移；标签 / Release 名一律取 `APP_BUILD_TAG`（如 `build-79`）。
- 改 README / docs 的提交不会触发构建（工作流配置了 paths-ignore）。

## 技术架构

- 播放音频交由原生播放器读取 HTTP 流（支持 Range 和鉴权头），保留 3–5 分钟原生内存预缓冲；切歌与加载超时会隔离旧引擎，锁屏控制随新引擎重新绑定
- 服务端为 Musix Hub REST API，Cookie 鉴权 `musix_session` + 反向代理 cookie，响应信封 `{result:{status,data,error}}`

| 职责 | 实现 |
| --- | --- |
| 状态管理 | `provider` + `ChangeNotifier`（`lib/stores/`）|
| 网络层 | `lib/api/`，Cookie 鉴权与统一响应信封解析 |
| 播放引擎 | `just_audio` + `audio_service`，原生播放器读 HTTP 流并自定义 Cookie header |
| 图片加载 | `cached_network_image` + Cookie header |
| 本地持久化 | `shared_preferences`（`lib/local/`）|
| 锁屏 / 通知 | `audio_service` 媒体会话 |
| 桌面小组件 | `home_widget` + Android AppWidget |
| 封面取色 | `palette_generator` |
| 图标切换 | 22 个 `activity-alias` + `PackageManager.setComponentEnabledSetting` |
| 应用内更新 | GitHub Releases + 多线路加速 / 测速 / 后台下载（`lib/services/`）|

## 项目结构

```
lib/
├── app.dart            # 应用入口与根布局
├── theme/              # 液态玻璃材质、路由转场、背景层
├── views/              # 主页、播放器、设置、更新等页面
├── services/           # 更新线路、测速、图标切换等服务
├── stores/             # UI 状态管理
├── local/              # 本地持久化偏好
└── ...
android/                # 平台壳工程（activity-alias 图标切换等）
tool/                   # 图标 / 横幅生成脚本（dart:ui、Pillow 程序化绘制）
test/                   # 单元与 Widget 测试
```

## 测试

```bash
flutter analyze        # 静态分析
flutter test           # 全量测试
```

## English

**MusicX** is a Flutter music player for Android that connects to your self-hosted music server.

- Personal library with cross-platform aggregation, playlists, and seamless playback resume
- Liquid glass UI with switchable materials (refractive liquid glass / frosted glass), random background with live blur & opacity tuning
- 22 switchable launcher icons, multiple theme colors, light / dark / system display modes
- In-app updates with multi-route acceleration, speed test, background download and integrity checks
