<!-- build-72 -->

## 新功能

- 安装器版本号与 App 内展示对齐：Android versionName 改用 APP_DISPLAY_VERSION，安装确认页显示 0.8.12(004) 而非全局运行号 071，不再误判为新旧版本

## 问题修复

- 本地/CI 缺少环境变量时 gradle 回退旧格式，不影响手动构建
