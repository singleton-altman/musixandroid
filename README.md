<div align="center">

<img src="docs/banner.png" alt="MusicX" width="100%">

# MusicX

**液态玻璃风格的 Android 音乐播放器，连你自己的音乐服务器。**

歌在自己的硬盘里，界面在自己手里。

[![Release](https://img.shields.io/github/v/release/singleton-altman/musixandroid?style=flat-square&color=7C6CFF&label=release)](https://github.com/singleton-altman/musixandroid/releases/latest)
[![Stars](https://img.shields.io/github/stars/singleton-altman/musixandroid?style=flat-square&color=7C6CFF)](https://github.com/singleton-altman/musixandroid/stargazers)
[![Last Commit](https://img.shields.io/github/last-commit/singleton-altman/musixandroid?style=flat-square&color=7C6CFF)](https://github.com/singleton-altman/musixandroid/commits/main)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.4-54C5F8?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev)
[![Android](https://img.shields.io/badge/Android-8.0%2B-3DDC84?style=flat-square&logo=android&logoColor=white)](#环境要求)

[**下载 APK**](https://github.com/singleton-altman/musixandroid/releases/latest)　·　[快速开始](#三步开始)　·　[反馈问题](https://github.com/singleton-altman/musixandroid/issues)　·　[技术架构](#技术架构)

</div>

---

## 这是什么

一个**给自托管音乐服务器用的 Android 客户端**（纯 Flutter 实现）。

服务器跑在你自己的电脑、NAS 或 VPS 上，歌都在自己硬盘里；手机装这个 App 连上去，就能听歌、翻歌单、收每日推荐、管播放队列。不用开电脑、不用开网页，也不经过任何第三方云。

## 三步开始

|  | 做什么 | 说明 |
| :-: | --- | --- |
| **1** | 启动音乐服务器 | 需要 Musix Hub 兼容的 REST API，跑在你自己的设备上 |
| **2** | 下载并安装 APK | 从 [Releases](https://github.com/singleton-altman/musixandroid/releases/latest) 取最新版，Android 8.0 以上 |
| **3** | 填入地址与密码 | 打开 App 输入服务器地址，登录后即开始同步曲库 |

## 环境要求

| 项目 | 要求 |
| --- | --- |
| 手机系统 | Android 8.0+（minSdk 26） |
| 服务端 | 已部署的 Musix Hub 兼容服务（默认 `http://127.0.0.1:8080`） |
| 网络 | 局域网直连，或经反向代理 / 内网穿透访问 |

> 首次登录只需**地址 + 密码**，连接信息仅用于访问你的个人音乐库，不上传任何第三方。

## 构建

构建使用 Flutter **3.47.4**（GitHub Actions 已固定此版本）。`liquid_glass_widgets 1.17.1` 要求 Flutter 至少 3.41.0，旧版 3.24 无法编译。

<details>
<summary><b>首次构建（Windows）</b></summary>

<br>

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

</details>

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
```

---

<div align="center">

## English

<sub>

**MusicX** is a liquid-glass music player for Android that streams from your own self-hosted server.

Your library stays on your hardware. No account, no cloud, no third party.

Built with Flutter 3.47.4 · Requires Android 8.0+ · Updates ship through GitHub Releases.

[**Download**](https://github.com/singleton-altman/musixandroid/releases/latest)　·　[**Issues**](https://github.com/singleton-altman/musixandroid/issues)

</sub>

</div>
