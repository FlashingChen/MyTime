# Agent 指南:CI/CD 发布流程

本仓库在 GitHub 与 CNB(cnb.cool)双平台配置了发布流水线:**推送 `v*` tag 自动构建签名 release APK 并创建 Release**。任何改动 CI/CD 的 agent 必须先读本文档。

## 触发方式

| 平台 | 配置 | 触发 |
| --- | --- | --- |
| GitHub | `.github/workflows/release.yml` | push tag `v*` |
| CNB | `.cnb.yml` | push tag `v*`(`tag_push` 事件) |

tag 需为 semver: `v1.2.3`、`v1.2.3+4`、`v1.2.3-rc.1`。非 semver 的 tag 会被 `scripts/package-release-apk.sh` 拒绝并构建失败;`v1.2.3-rc.1` 这类 tag 在 GitHub 上会发布为 prerelease。两个平台 tag 规则保持一致,新增平台需同步。

## 文件职责

| 文件 | 职责 |
| --- | --- |
| `.github/workflows/release.yml` | GitHub:tag 触发 → 注入签名 secrets → 打包 APK → 发布 GitHub Release |
| `.cnb.yml` | CNB:tag 触发 → 注入签名变量 → 打包 APK → 上传附件 → 创建 CNB Release |
| `scripts/build-release-apk.sh` | 校验签名配置后执行 `flutter build apk --release`(本地与 CI 共用) |
| `scripts/verify-release-config.sh` | 签名材料校验:**CI 走环境变量,本地走 key.properties + macOS Keychain** |
| `scripts/package-release-apk.sh` | 版本解析 + 构建 + 产出 `release/mytime-<tag>.apk` 与 `.sha256`,两个 CI 共用 |
| `android/app/build.gradle.kts` | 签名解析:环境变量优先,回退 key.properties + Keychain |

日常质量检查(`flutter analyze` / `flutter test`)在 `.github/workflows/quality.yml`,与发布流水线无关。

## 签名材料(已配置)

本地 macOS 已配置完毕,`verify-release-config.sh` 本地模式可直接通过:

- `android/key.properties`(gitignored):`keyAlias=mytime-release`、`storeFile=/Users/flashingchen/.mytime/mytime-release.jks`
- keystore 文件:`~/.mytime/mytime-release.jks`(别名 `mytime-release`)
- 两个密码存在 macOS Keychain(服务 `com.mytime.mytime.android.release.store-password` / `key-password`,账号 `MyTime Android Release`)

**CI 环境(4 个变量)**由平台密钥管理注入:

| 变量 | 内容 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | keystore 文件内容的 base64 |
| `ANDROID_KEYSTORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_PASSWORD` | key 密码 |
| `ANDROID_KEY_ALIAS` | `mytime-release` |

- GitHub:仓库 Settings → Secrets and variables → Actions,配置同名 secret。
- CNB:项目设置 → 变量,配置同名加密变量。
- 生成 base64(mac):`base64 -i ~/.mytime/mytime-release.jks | tr -d '\n'`;密码从 Keychain 取:`security find-generic-password -a "MyTime Android Release" -s <service> -w`。
- **secret 未配置时构建会失败**,`verify-release-config.sh` 会明确提示缺失项——这是有意设计,防止产出未签名 APK。

## 发布步骤

1. (可选)更新 `pubspec.yaml` 的 `version`;构建时会用 tag 覆盖 `--build-name`,tag 中 `+N` 覆盖 build number(versionCode),否则用 CI 的构建序号。
2. `git tag v1.2.3 && git push origin v1.2.3`
3. GitHub 与 CNB 各自构建并创建 Release,APK 与 SHA256 作为附件。

## 安全约束

- 密钥类文件一律不得进仓库。`.gitignore` 已覆盖:`android/key.properties`、`*.jks`、`*.keystore`、`*.jks.b64`、`*.p12`、`.env*`、`ios/Flutter/Private.xcconfig`。**新增任何密钥/证书/私钥文件时必须同时加入 .gitignore**,并通过 `git check-ignore` 验证。
- workflow 中 secret 只用于环境变量注入,不得 echo 到日志、不得写进仓库内文件。
- `AGENTS.md` 是项目文档,应随仓库提交,不要加入 .gitignore。

## 维护注意

- 构建产物路径有变时,同步更新 `scripts/build-release-apk.sh` 与 `scripts/package-release-apk.sh` 中的候选路径(`build/app/outputs/apk/release/` 与 `build/app/outputs/flutter-apk/` 两个历史位置)。
- 签名解析逻辑(gradle kts / verify 脚本)改动后,需同时验证本地 Keychain 模式与 CI env 模式。
- GitHub Actions 中 `secrets` 上下文**不能用于 `if:` 条件**,需先映射到 job 级 `env` 再判断(见 release.yml 的 `HAS_KEYSTORE` 写法)。
- 验证发布构建:`ANDROID_KEYSTORE_*` 四变量 + 临时 jks,跑 `./scripts/package-release-apk.sh v1.2.3 2`;或直接本地跑(Keychain 已配好)。
