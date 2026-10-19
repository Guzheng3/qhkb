# 编译与签名向导

这份文档说明**本地**如何签名编译清涵课表（Android），以及每次发版如何编号、打标签。

- 只看发布机制（CI、GitHub Release、tag 触发流程）：见 [RELEASE.md](./RELEASE.md)。
- 只看开发环境与构建命令：见 [README.md](../README.md)。
- 一键脚本：[tool/build_release.ps1](../tool/build_release.ps1)。

发布构建命令（与 [README.md](../README.md) 一致）：

```bash
flutter build apk --release --flavor prod --target-platform android-arm64
```

## 一、本地签名编译

正式包必须用**固定密钥**签名。同一 `.jks` 密钥库签名，新包才能覆盖安装升级；
换密钥或密钥不一致时，Android 会判定为不同应用，装机冲突，只能先卸载旧版再装新版。

### 1. 签名材料的三种给法

[android/app/build.gradle](../android/app/build.gradle) 按下面的优先级取签名材料：
先读仓库内 `android/key.properties` 的字段，字段缺失时回退到同名环境变量。

| 方式 | 位置 | 适用场景 |
|------|------|----------|
| A. 仓库内 key.properties | `android/key.properties` | 本机长期固定签名，最省事 |
| B. 环境变量 | `ANDROID_KEYSTORE_PATH` / `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_ALIAS` / `ANDROID_KEY_PASSWORD` | 不想落盘 key.properties，或用外部 CI |
| C. 脚本参数指定外部 key.properties | `build_release.ps1 -KeyPropertiesPath <path>` | 密钥库放在仓库之外的另一处目录 |

### 2. key.properties 字段

文件内容是一组 `key=value`（示例一律为占位符）：

```properties
storeFile=vip.qinghan.withu-release.jks
storePassword=<你的 storePassword>
keyAlias=vip.qinghan.withu
keyPassword=<你的 keyPassword>
```

- `storeFile` 是 `.jks` 密钥库路径。
- 方式 A 下，相对路径相对仓库的 `android/` 目录解析（与 Gradle `rootProject.file()` 一致）。
- 方式 C 下，相对路径相对**该 key.properties 文件所在目录**解析。
  例如 `E:/schedule/mikcb/android/key.properties` 里写 `storeFile=vip.qinghan.withu-release.jks`，
  对应的密钥库就是同目录下的 `E:/schedule/mikcb/android/vip.qinghan.withu-release.jks`。

### 3. 环境变量写法（PowerShell）

```powershell
$env:ANDROID_KEYSTORE_PATH = "D:\keys\vip.qinghan.withu-release.jks"
$env:ANDROID_KEYSTORE_PASSWORD = "<你的 storePassword>"
$env:ANDROID_KEY_ALIAS = "vip.qinghan.withu"
$env:ANDROID_KEY_PASSWORD = "<你的 keyPassword>"
```

### 4. 密钥绝不入库

- 密钥库 `.jks` / `.keystore` 与 `key.properties` **不得提交进仓库**，也不得放进工作区交付物。
- [.gitignore](../.gitignore) 已忽略 `android/key.properties`、`android/app/*.jks`、`android/app/*.keystore`。
  密钥库放在这些忽略路径之内即可。
- 编译完成后跑一次 `git status --short`，结果应为空；`git ls-files` 里不应出现任何密钥类文件。

### 5. 用脚本一键签名编译

[build_release.ps1](../tool/build_release.ps1) 会解析版本、校验签名材料、执行发布构建，
并在编译后自检签名证书与版本号。可在 `pwsh`（PowerShell 7）或 Windows PowerShell 5.1 下运行，
从仓库根或任意目录调用都能定位仓库根。

```powershell
# 仅预览：解析版本、显示期望 versionCode 与默认标签、检查签名材料是否就绪（不编译）
pwsh -NoProfile -File tool/build_release.ps1 -DryRun

# 用外部 key.properties 签名编译（相对 storeFile 相对该文件目录解析）
pwsh -NoProfile -File tool/build_release.ps1 -KeyPropertiesPath "E:/schedule/mikcb/android/key.properties"

# 编译通过后创建本地附注标签（不推送）
pwsh -NoProfile -File tool/build_release.ps1 -Tag v5.2.0
```

参数：

| 参数 | 说明 |
|------|------|
| `-KeyPropertiesPath <path>` | 可选。指定外部 key.properties；缺省时按优先级用仓库内 `android/key.properties` 或环境变量 |
| `-Tag <name>` | 可选。编译并自检通过后创建**本地**附注标签；只打印 `git push origin <name>` 供你自己决定是否推送 |
| `-DryRun` | 只做校验与打印，不编译、不打标签 |

## 二、版本号与打标签

### 1. 改 pubspec 的 version

版本真源是 [pubspec.yaml](../pubspec.yaml) 的 `version:`，格式为 `<versionName>+<build>`：

```yaml
version: 5.2.0-0+139
```

- `5.2.0` 是基线版本。
- `-0` / `-7` 是预发布后缀；含 `-` 会被 GitHub Actions 判定为预发布（见 [RELEASE.md](./RELEASE.md)）。
- `139` 是 build number，必须递增。

三位数 / 四位数版本、预发布与正式版的完整规则在 [RELEASE.md](./RELEASE.md)，这里不重复。

### 2. 从 version 推导 Android versionCode

[android/app/build.gradle](../android/app/build.gradle) 里：

```groovy
versionCode = (flutter.versionCode as int) + 100000
versionName = overrideVersionName ?: flutter.versionName
```

- `flutter.versionCode` 就是 pubspec `+` 后面的 build number。
- 最终 `versionCode = build number + 100000`。例如 `+139` → `100139`。
- `+100000` 偏移用于确保 `versionCode` 始终高于旧版按 ABI 拆分构建的值，避免被误判为降级安装。
- `versionName` 默认取 pubspec 的 `versionName`；设了 `OVERRIDE_VERSION_NAME`
  （Gradle 属性或同名环境变量）时用它覆盖，CI 就是用 tag 名覆盖最终 `versionName`。

### 3. 什么时候打标签、怎么命名

- **每次发版**才打标签，日常提交不打。
- 标签名固定为 `v` + 对外版本号，例如 `v5.2.0`、`v1.1.10.7`。
- 标签与 release notes 文件名必须完全一致：tag `v1.1.10.7` 对应 `docs/releases/v1.1.10.7.md`。
- 推 tag 触发 CI 发布流程；**推送由你自己决定**，脚本只创建本地标签并打印推送命令。

### 4. 脚本的默认标签推导

脚本从 pubspec 的 `versionName` 去掉 `-0` 之类的预发布后缀得到默认标签：

| pubspec version | versionName | 期望 versionCode | 默认标签 |
|-----------------|-------------|------------------|----------|
| `5.2.0-0+139` | `5.2.0-0` | `100139` | `v5.2.0` |
| `1.3.2-0+109` | `1.3.2-0` | `100109` | `v1.3.2` |

四位数版本默认推导会少一段：`1.1.10-7+37` 推导为 `v1.1.10`。
此时用 `-Tag v1.1.10.7` 显式指定即可（规则见 [RELEASE.md](./RELEASE.md)）。

## 三、编译后自检

脚本在构建成功后做两项自检，并打印结论：

- 用 `apksigner verify --print-certs` 打印签名证书的 SHA-256。
- 用 `aapt2 dump badging` 校验 `package name='vip.qinghan.withu'`、`application-label`、
  `versionCode` 是否等于第一步算出的期望值；`versionCode` 或包名不符会让脚本以非零码退出。

`apksigner` / `aapt2` 从 `ANDROID_HOME`、`ANDROID_SDK_ROOT` 或常见安装路径的
`build-tools/<版本>/` 下查找。找不到时相应自检会被跳过，并打印明确提示，不会静默通过。

## 相关文档

- 发布机制（CI / GitHub Release / tag 流程）：[RELEASE.md](./RELEASE.md)
- 开发环境与构建命令：[README.md](../README.md)
- 构建疑难排查：[BUILD_TROUBLESHOOTING.md](./BUILD_TROUBLESHOOTING.md)
- 一键脚本：[tool/build_release.ps1](../tool/build_release.ps1)