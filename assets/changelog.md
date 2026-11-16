# 更新日记

## build-7 · 2026-09-23

本版构建没有可展示的提交说明，可直接安装使用。

## build-8 · 2026-09-23

### 新功能
- refine player chrome and theme contrast（ui）

## build-9 · 2026-09-23

### 新功能
- add collapsible glass player（ui）

## build-10 · 2026-09-23

### 问题修复
- restore playback diagnostics and layout（app）

## build-11 · 2026-09-23

### 问题修复
- stabilize streaming and dynamic themes（app）

## build-12 · 2026-09-23

### 问题修复
- handle system back in tab shell（app）

### 其它改动
- 22

## build-13 · 2026-09-23

### 新功能
- make player and nav fully transparent（ui）

## build-14 · 2026-09-23

### 新功能
- unify glass panels over custom backgrounds（ui）

## build-15 · 2026-09-24

### 新功能
- refine glass card transparency（ui）

## build-16 · 2026-09-24

### 新功能
- adopt liquid glass bottom chrome（ui）

### 问题修复
- improve lyrics routes and sign-out cleanup（player）

## build-17 · 2026-09-24

### 问题修复
- stabilize transparent bottom chrome（ui）

## build-18 · 2026-09-25

### 问题修复
- remove background color veils（ui）

## build-19 · 2026-09-25

### 问题修复
- remove dock background layer（ui）

## build-20 · 2026-09-25

### 新功能
- replace dock with liquid glass bar（ui）

### 问题修复
- remove settings frames and route color flash（ui）

## build-21 · 2026-09-25

### 问题修复
- eliminate route flashes and debug baselines（ui）

## build-24 · 2026-09-25

### 问题修复
- skip generated template widget test（ci）
- isolate page backgrounds and remove afterimages（navigation）

### 测试
- guard opaque instant routes（navigation）

### 其它改动
- clear static analysis issues（code）

## build-25 · 2026-09-26

### 问题修复
- align routed backgrounds to viewport（ui）
- disable debug baselines before frame paint（ui）

## build-26 · 2026-09-26

### 问题修复
- restore Material context for bottom overlays（ui）

## build-27 · 2026-09-26

### 问题修复
- tighten bottom chrome and stabilize keyboard focus（ui）

## build-28 · 2026-09-26

### 新功能
- add guess-you-like poster rail（home）

## build-29 · 2026-09-26

### 问题修复
- populate guess cards and add play controls（home）

## build-31 · 2026-09-26

### 问题修复
- make guess recommendations a shuffled playlist（home）

## build-32 · 2026-09-26

### 问题修复
- integrate guess playlist into featured recommendations（home）

## build-33 · 2026-09-26

### 问题修复
- place guess playlist first in featured rail（home）

## build-34 · 2026-10-02

### 新功能
- load full recommendations and skip broken sources（playback）

## build-35 · 2026-10-02

### 问题修复
- skip failed sources without opening picker（playback）

## build-36 · 2026-10-02

### 新功能
- add play and pause to guess card（home）

## build-37 · 2026-10-06

### 问题修复
- keep locked-screen audio buffered（playback）

## build-38 · 2026-10-06

### 新功能
- manage queue and sync system volume（player）

## build-41 · 2026-10-07

### 新功能
- adopt liquid glass controls and fixed APK signing（ui）

### 问题修复
- recognize scheme-prefixed APK signer reports（ci）
- support SDK-range APK signer certificates（ci）

## build-42 · 2026-10-07

### 问题修复
- render scrolling content behind floating glass controls（ui）

## 0.7.8(001) · build-43 · 2026-10-07

### 新功能
- complete glass controls and automate 0.7.8 build versions（ui）

## 0.7.8(002) · build-44 · 2026-10-07

### 问题修复
- bound loading and correct glass UI state（player）

## 0.7.8(003) · build-45 · 2026-10-08

### 问题修复
- bypass blocked cache proxy and stabilize glass rendering（player）

## 0.7.8(004) · build-46 · 2026-10-08

### 问题修复
- keep scrolling cards clear at rest and during drag（ui）

## 0.7.8(005) · build-47 · 2026-10-08

### 问题修复
- restore profile actions and align home recommendations（ui）

### 其它改动
- Use frosted liquid glass cards for profile and settings, restore playlist creation and batch ingestion from favorites, reduce the compact progress thumb, and load home guesses from the web home endpoint.

## 0.7.8(006) · build-48 · 2026-10-08

### 问题修复
- keep profile glass material stable while scrolling（ui）

### 其它改动
- Render profile and settings cards with a fixed tint, live blur and vector rim so shader availability cannot fade the body. Add light and dark pixel checks for idle, drag, settled and shader-unavailable frames, and verify switches remain outside the card material layer.

## 0.7.8(007) · build-49 · 2026-10-08

### 问题修复
- match profile and settings glass to the navigation bar（ui）

### 其它改动
- Share neutral glass settings, adaptive quality and the grouped layer rendering used by the dock. Remove the fixed card tint and platform-view fallback, and disable whole-item repaint boundaries in profile and settings lists. Compare card and actual dock pixels in light and dark modes through scrolling and shader fallback.

## 0.7.8(008) · build-50 · 2026-10-08

### 问题修复
- remove glass backgrounds from profile and settings cards（ui）

### 其它改动
- Render content cards as padding only, removing the extra glass, blur, tint and background layers. Verify that wallpaper pixels remain unchanged while idle, dragging and settled in both light and dark modes.

## 0.7.8(009) · build-51 · 2026-10-08

本版构建没有可展示的提交说明，可直接安装使用。

## 0.7.8(010) · build-52 · 2026-10-12

### 问题修复
- align guess-you-like recommendation API

## 0.7.8(011) · build-53 · 2026-10-12

### 问题修复
- keep home guess card visible

## 0.7.8(012) · build-54 · 2026-11-01

### 新功能
- 平台歌单按平台分组支持折叠（library）
- 猜你喜欢只播放听过的歌，并改为电台式随机点播（player）

### 其它改动
- 补交 Flutter 生成的 Android 构建脚手架与迁移配置（android）
- 包含 Gradle wrapper、启动图标、debug/profile 清单等自动生成文件，及 Flutter 迁移器写入的 gradle 兼容开关；wrapper 指向腾讯镜像 Gradle 8.14.3 以匹配 AGP 8.11.1
- 分组标题默认收起、点击展开/收起，歌单多时页面不再被撑长；每次启动恢复默认收起
- 猜你喜欢与服务端播放历史求交集，只推荐听过的歌；历史接口异常时自动降级为不过滤
- 播放/下一首改为逐首向服务端随机取歌追加，不再预装固定列表洗牌
- 取歌时避开队列已有歌曲，全听过后允许重复；音源失败自动随机换歌补上

## 0.7.8(013) · build-55 · 2026-11-01

### 问题修复
- 猜你喜欢电台改为全池随机取歌，修复重复歌曲（player）

### 其它改动
- 电台不再套"只播放听过的"过滤，直接从服务端完整推荐池随机取歌
- 队列已有的歌严格避开，修复之前排除失败时同一首歌连排多次的问题

## 0.8.11(014) · build-56 · 2026-11-01

### 新功能
- 猜你喜欢卡片封面跟随当前播放歌曲（home）

### 其它改动
- 版本号 0.7.8 → 0.8.11，与服务端同步（version）
- 电台播放时卡片封面实时切换为正在播放的歌曲封面，不再固定服务端货架第一张

## 0.8.11(015) · build-57 · 2026-11-01

### 新功能
- 锁屏/通知媒体卡片增加爱心收藏按钮（player）

### 其它改动
- 收藏自定义动作移到控件首位，Android 13+ 媒体卡片左侧显示爱心；紧凑通知保持上一首/播放/下一首；收藏状态实时切换图标

## 0.8.11(016) · build-58 · 2026-11-01

### 问题修复
- 完善锁屏收藏按钮兼容性（player）

## 0.8.11(017) · build-59 · 2026-11-01

### 问题修复
- 兼容 ColorOS 锁屏收藏按钮（player）

## 0.8.11(018) · build-60 · 2026-11-01

### 新功能
- 猜你喜欢卡片未播放时轮换推荐封面（home）

### 其它改动
- 未播放/刚打开时封面固定回落到列表第一首，观感单一。
- 转为 StatefulWidget 后每 5 秒在推荐列表封面上轮换（随机起点，
- 每次打开不同）；播放中仍跟随当前歌曲封面。

## 0.8.11(019) · build-61 · 2026-11-11

### 新功能
- 适配 MoviePilotLite 的下载线路机制（可选加速源+测速）（update）
- 在线升级 + 播放条按钮与进度点重做（update）
- 界面材质设置支持毛玻璃/液态玻璃切换，升级 liquid_glass_widgets 1.17.1（glass）

### 性能优化
- 播放条延迟优化与按钮重设计（player）

### 界面与体验
- 播放条按钮恢复纯图标样式，仅保留进度条强调色圆点（player）
- 播放页顶部按钮玻璃化（nowplaying）

### 重构
- 移除关于分组中重复的更新下载线路行（settings）

### 其它改动
- 记录线路入口收敛（memory）
- 线路切换入口统一收敛到检查更新弹层内（与用户反馈一致），线路选择、测速与自定义源功能不变
- 记录下载线路适配（memory）
- 新增 UpdateMirror 模型与 UpdateMirrorStore：内置 gh-proxy.org/gh-proxy.com/ghfast.top/ghproxy.net 四条加速源，支持前缀式与 {url} 占位符式模板，自定义源校验/去重并持久化到 SharedPreferences
- 新增 UpdateSpeedTester：Range 流式请求 + 5 秒窗口测速，MirrorSpeedController 管理测速状态与最快线路提示
- AppUpdateService：检查更新改为全线路并行竞速（首选当前线路）；下载按所选线路执行并校验 APK 头（PK\x03\x04），失败自动回退直连；APK 缓存 7 天过期清理
- 设置 → 关于 新增「更新下载线路」行；检查更新弹层内嵌线路切换入口；新增线路管理面板（测速、选择、自定义增删）
- 新增 test/update_mirror_test.dart 12 个用例，全套 84 测试通过；模拟器端到端验证测速/切换/检查更新
- 收起态 3 键与展开态 5 键去掉磨砂圆片底座，恢复 _compactButton/_compactPlayButton/_iconButton 纯图标按钮
- 红色实心播放钮与进度条 Slider 圆点保留不变
- 新增 AppUpdateService：GitHub Releases 检查更新（版本格式 0.8.11(018)），多加速镜像自动回退下载，下载后经系统安装器安装
- 设置 → 关于 新增 检查更新 行，玻璃弹层展示新版本/当前版本/更新说明，下载带进度百分比与线路显示，可取消

## 0.8.11(020) · build-62 · 2026-11-11

### 新功能
- 界面材质切换、播放体验优化与在线升级

### 其它改动
- 界面材质
- 新增 GlassMaterial 枚举与持久化（默认液态玻璃），设置页外观与主题分组新增「界面材质」行，玻璃菜单选择、选中项带勾选
- playerGlassSettings 双材质预设：液态玻璃为折射透镜（thickness 24 / refraction 1.18 / 色散），毛玻璃为平磨砂（无折射无色散、blur 22 + 磨砂罩），全部玻璃表面全局生效
- liquid_glass_widgets 1.10.0 → 1.17.1（约 30% 帧开销下降、着色器释放修复、premium 质量提升），以 GlassThemeData.classic() 固定经典外观
- 播放体验
- 播放条延迟优化：进度更新隔离到独立滑块组件，玻璃面板不再随进度高频重建
- 播放页顶部收起/菜单按钮玻璃化；播放条按钮恢复纯图标样式，进度条改用强调色圆点滑块
- 在线升级
- 检查更新经 GitHub Releases，多线路并行竞速；下载支持加速源线路（内置 4 条 + 自定义源，支持测速、切换、增删，持久化保存）
- 下载校验 APK 文件头，失败自动回退直连；缓存 7 天自动清理；线路切换入口收敛到检查更新弹层内
- 新增 glass_material_test 与 update_mirror_test 共 15 个用例，全套 84 测试通过

## 0.8.11(021) · build-63 · 2026-11-11

### 新功能
- 界面材质切换、播放体验优化、在线升级与个性化定制

### 其它改动
- 界面材质
- 新增 GlassMaterial 枚举与持久化（默认液态玻璃），设置页外观与主题分组新增「界面材质」行，玻璃菜单选择、选中项带勾选
- playerGlassSettings 双材质预设：液态玻璃为折射透镜（thickness 24 / refraction 1.18 / 色散），毛玻璃为平磨砂（无折射无色散、blur 22 + 磨砂罩），全部玻璃表面全局生效
- liquid_glass_widgets 1.10.0 → 1.17.1（约 30% 帧开销下降、着色器释放修复、premium 质量提升），以 GlassThemeData.classic() 固定经典外观
- 播放体验
- 播放条延迟优化：进度更新隔离到独立滑块组件，玻璃面板不再随进度高频重建
- 播放页顶部收起/菜单按钮玻璃化；播放条按钮恢复纯图标样式，进度条改用强调色圆点滑块
- 在线升级
- 检查更新经 GitHub Releases，多线路并行竞速；下载支持加速源线路（内置 4 条 + 自定义源，支持测速、切换、增删，持久化保存）
- 下载校验 APK 文件头，失败自动回退直连；缓存 7 天自动清理；线路切换入口收敛到检查更新弹层内
- 背景图调节
- 随机背景图新增「模糊度」（0–30px）与「不透明度」（20–100%）实时滑杆，持久化保存，应用级与页面级背景同步生效

## 0.8.11(022) · build-64 · 2026-11-11

### 新功能
- 应用图标系统重构 —— 22 款可切换，液态玻璃为默认图标

### 其它改动
- 修复图标背景发黑：生成脚本原先所有变体共用一个近黑径向底，改为每款独立的竖向渐变底 + 双色辉光斑，深色款也提亮为可见深蓝
- 新增 14 款不同构图：彩虹声浪、复古黑胶、霓虹耳机、跳动音符、玻璃播放、潮流均衡器、复古磁带、舞台麦克风、吉他拨片、钢琴夜曲、重低音炮、彩虹光盘、复古收音机、液态玻璃
- 液态玻璃设为默认图标：Manifest 默认启用对应 activity-alias、应用级 icon 指向液态玻璃、Dart/Kotlin 默认值同步、选择器排到首位
- 生成脚本同时输出 4 列预览拼图，便于挑选与回归

## 0.8.11(023) · build-65 · 2026-11-15

### 新功能
- 全站玻璃化统一、自适应图标与更新内容展示
- 22 款图标改为 adaptive icon 双层结构（前景 66dp 安全区），修复桌面图标被拉长变形（icon）
- 共享音乐菜单/弹层组件支持图标触发、分组标题、勾选态与可滚动，合集详情、收藏、日志、入库记录、订阅管理、设置页的弹层菜单全部玻璃化，全项目 PopupMenuButton 清零（ui）
- 检查更新面板展示更新内容（分组条目、可滚动），非 Release 场景回退 compare API 拉取提交（update）
- 新增 scripts/generate_release_notes.py 按 conventional commit 分组生成更新说明，workflow 附带 body 发布（ci）

### 问题修复
- 解析音源期间提前进入前台服务并广播 buffering，锁屏/切后台不再长时间卡在「正在解析音源」（player）

### 测试
- 新增更新说明解析单测，修复图标生成用例与既有 widget 用例

## 0.8.12(001) · build-69 · 2026-11-16

<!-- build-69 -->

### 新功能
- 检查更新支持后台下载：点下载后可继续听歌、切页面，进度常驻底部横幅，下载完成自动拉起安装器
- 下载完整性校验：加速源返回的截断安装包会被识别并丢弃，自动回退直连重下，避免「安装包解析失败」

### 问题修复
- 版本号规则调整：基础版本升级后序列从 001 重新计数（0.8.12(001)、0.8.12(002)…），Android versionCode 改为始终递增，避免被系统判定降级而安装失败
- 更新日记中的各版本号同步新规则
