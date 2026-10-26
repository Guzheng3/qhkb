# 清涵课表 — 本地签名发布构建 + 版本标签助手
#
# 用途：本地签名构建正式 APK（prod / arm64），编译后自检签名与版本号，
#       并可按需创建本地附注标签（不推送）。
#
# 用法示例：
#   pwsh -NoProfile -File tool/build_release.ps1 -DryRun
#   pwsh -NoProfile -File tool/build_release.ps1 -KeyPropertiesPath "D:/keys/android/key.properties"
#   pwsh -NoProfile -File tool/build_release.ps1 -KeyPropertiesPath "D:/keys/android/key.properties" -Tag v5.2.0
#
# 说明文档：docs/BUILD_AND_SIGN.md
#
# 签名材料可以来自三处，优先级：-KeyPropertiesPath > android/key.properties > 环境变量。
# 指定 -KeyPropertiesPath 时，文件里的相对 storeFile 相对该 key.properties 所在目录解析。
#
# 天气数据由 withU 服务端获取，客户端不再需要任何第三方天气 Key，因此本脚本
# 不再注入 AMAP_KEY 之类的构建期常量。

param(
    [string]$KeyPropertiesPath = "",
    [string]$Tag = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {
}

function Fail([string]$Message) {
    Write-Host ""
    Write-Host "错误：$Message" -ForegroundColor Red
    exit 1
}

function Warn([string]$Message) {
    Write-Host "提示：$Message" -ForegroundColor Yellow
}

function Read-KeyProperties([string]$Path) {
    $props = @{}
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        $text = $line.Trim()
        if ($text.Length -eq 0) { continue }
        if ($text.StartsWith("#") -or $text.StartsWith("!")) { continue }
        $eq = $text.IndexOf("=")
        if ($eq -lt 0) { continue }
        $key = $text.Substring(0, $eq).Trim()
        $value = $text.Substring($eq + 1).Trim()
        $props[$key] = $value
    }
    return $props
}

function Resolve-StorePath([string]$StoreFile, [string]$BaseDir) {
    if ([System.IO.Path]::IsPathRooted($StoreFile)) {
        return $StoreFile
    }
    return [System.IO.Path]::GetFullPath((Join-Path $BaseDir $StoreFile))
}

function Test-AllEnvSet {
    foreach ($name in @(
            "ANDROID_KEYSTORE_PATH",
            "ANDROID_KEYSTORE_PASSWORD",
            "ANDROID_KEY_ALIAS",
            "ANDROID_KEY_PASSWORD")) {
        if (-not [Environment]::GetEnvironmentVariable($name)) {
            return $false
        }
    }
    return $true
}

function Find-BuildTool([string]$Name) {
    $roots = @()
    if ($env:ANDROID_HOME) { $roots += $env:ANDROID_HOME }
    if ($env:ANDROID_SDK_ROOT) { $roots += $env:ANDROID_SDK_ROOT }
    if ($env:LOCALAPPDATA) { $roots += (Join-Path $env:LOCALAPPDATA "Android\Sdk") }
    foreach ($root in $roots) {
        if (-not $root) { continue }
        $buildTools = Join-Path $root "build-tools"
        if (-not (Test-Path $buildTools)) { continue }
        $dirs = Get-ChildItem -Path $buildTools -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending
        foreach ($dir in $dirs) {
            foreach ($candidate in @("$Name.bat", "$Name.exe", $Name)) {
                $full = Join-Path $dir.FullName $candidate
                if (Test-Path $full) { return $full }
            }
        }
    }
    return $null
}

# ---------------------------------------------------------------------------
# 0. 定位仓库根
# ---------------------------------------------------------------------------
$RepoRoot = Split-Path -Parent $PSScriptRoot
$PubspecPath = Join-Path $RepoRoot "pubspec.yaml"
if (-not (Test-Path $PubspecPath)) {
    Fail "未找到 pubspec.yaml，无法定位仓库根（期望：$PubspecPath）"
}

Write-Host "清涵课表 本地发布构建" -ForegroundColor Cyan
Write-Host "仓库根：$RepoRoot"
if ($DryRun) {
    Write-Host "模式：DryRun（只做校验与打印，不编译、不打标签）" -ForegroundColor Cyan
}
Write-Host ""

# ---------------------------------------------------------------------------
# 1. 解析 pubspec.yaml 的 version:，推导 versionCode 与默认标签
# ---------------------------------------------------------------------------
$pubspecText = [System.IO.File]::ReadAllText($PubspecPath)
$versionMatch = [regex]::Match($pubspecText, "(?m)^\s*version:\s*([^\s#]+)")
if (-not $versionMatch.Success) {
    Fail "pubspec.yaml 中未找到 version: 字段"
}

$versionToken = $versionMatch.Groups[1].Value
$plusParts = $versionToken -split "\+", 2
$versionName = $plusParts[0]
$buildPart = ""
if ($plusParts.Length -gt 1) { $buildPart = $plusParts[1] }

if (-not $buildPart) {
    Fail "pubspec.yaml 的 version: 缺少 build number（应为 <versionName>+<build>，例如 5.2.0-0+139）"
}
$buildNumber = 0
if (-not [int]::TryParse($buildPart, [ref]$buildNumber)) {
    Fail "pubspec.yaml 的 build number 不是整数：$buildPart"
}

# Android versionCode = build number + 100000（对齐 android/app/build.gradle 的偏移）。
$expectedVersionCode = $buildNumber + 100000
# 默认标签：去掉 -0 之类的预发布后缀（四位数版本请用 -Tag 显式指定）。
$baseName = $versionName -replace "-.*$", ""
$defaultTag = "v$baseName"

$expectedPackage = "vip.qinghan.withu"
$expectedLabel = "清涵课表"

Write-Host "版本解析：" -ForegroundColor Green
Write-Host ("  pubspec version : {0}" -f $versionToken)
Write-Host ("  versionName     : {0}" -f $versionName)
Write-Host ("  build number    : {0}" -f $buildNumber)
Write-Host ("  期望 versionCode: {0}  (= {1} + 100000)" -f $expectedVersionCode, $buildNumber)
Write-Host ("  默认标签        : {0}" -f $defaultTag)
Write-Host ""

# ---------------------------------------------------------------------------
# 2. 校验签名材料
# ---------------------------------------------------------------------------
$signingReady = $false
$signingMode = ""
$signingStorePath = ""
$warnings = @()

$repoKeyProperties = Join-Path $RepoRoot "android\key.properties"

if ($KeyPropertiesPath) {
    if (-not (Test-Path $KeyPropertiesPath)) {
        Fail "-KeyPropertiesPath 指定的文件不存在：$KeyPropertiesPath"
    }
    $props = Read-KeyProperties $KeyPropertiesPath
    foreach ($field in @("storeFile", "storePassword", "keyAlias", "keyPassword")) {
        if (-not $props.ContainsKey($field) -or -not $props[$field]) {
            Fail "key.properties 缺少字段 $field：$KeyPropertiesPath"
        }
    }
    # 相对 storeFile 相对该 key.properties 所在目录解析。
    $baseDir = [System.IO.Path]::GetDirectoryName(
        [System.IO.Path]::GetFullPath($KeyPropertiesPath))
    $signingStorePath = Resolve-StorePath $props["storeFile"] $baseDir
    if (-not (Test-Path $signingStorePath)) {
        Fail "key.properties 指向的密钥库不存在：$signingStorePath"
    }
    $env:ANDROID_KEYSTORE_PATH = $signingStorePath
    $env:ANDROID_KEYSTORE_PASSWORD = $props["storePassword"]
    $env:ANDROID_KEY_ALIAS = $props["keyAlias"]
    $env:ANDROID_KEY_PASSWORD = $props["keyPassword"]
    $signingReady = $true
    $signingMode = "外部 key.properties：$KeyPropertiesPath"
    if (Test-Path $repoKeyProperties) {
        $warnings += "仓库内还存在 android/key.properties，Gradle 会优先使用它而非 -KeyPropertiesPath"
    }
}
elseif (Test-Path $repoKeyProperties) {
    $props = Read-KeyProperties $repoKeyProperties
    foreach ($field in @("storeFile", "storePassword", "keyAlias", "keyPassword")) {
        if (-not $props.ContainsKey($field) -or -not $props[$field]) {
            Fail "android/key.properties 缺少字段 $field：$repoKeyProperties"
        }
    }
    $androidDir = Join-Path $RepoRoot "android"
    $signingStorePath = Resolve-StorePath $props["storeFile"] $androidDir
    if (-not (Test-Path $signingStorePath)) {
        Fail "android/key.properties 指向的密钥库不存在：$signingStorePath"
    }
    $signingReady = $true
    $signingMode = "仓库内 android/key.properties"
}
elseif (Test-AllEnvSet) {
    $signingStorePath = $env:ANDROID_KEYSTORE_PATH
    if (-not [System.IO.Path]::IsPathRooted($signingStorePath)) {
        $signingStorePath = Resolve-StorePath $signingStorePath $RepoRoot
    }
    if (-not (Test-Path $signingStorePath)) {
        Fail "ANDROID_KEYSTORE_PATH 指向的密钥库不存在：$signingStorePath"
    }
    $signingReady = $true
    $signingMode = "环境变量 ANDROID_KEYSTORE_*"
}
else {
    $signingReady = $false
}

Write-Host "签名材料：" -ForegroundColor Green
if ($signingReady) {
    Write-Host ("  状态：就绪（{0}）" -f $signingMode)
    Write-Host ("  密钥库：{0}" -f $signingStorePath)
} else {
    Write-Host "  状态：未就绪" -ForegroundColor Yellow
    Write-Host "  需要下列任一来源："
    Write-Host "    1) android/key.properties（仓库内，已 gitignore）"
    Write-Host "    2) 环境变量 ANDROID_KEYSTORE_PATH / ANDROID_KEYSTORE_PASSWORD / ANDROID_KEY_ALIAS / ANDROID_KEY_PASSWORD"
    Write-Host "    3) 本脚本参数 -KeyPropertiesPath <外部 key.properties>"
}
foreach ($w in $warnings) {
    Warn $w
}
Write-Host ""

# ---------------------------------------------------------------------------
# 3. DryRun：打印到此处即结束
# ---------------------------------------------------------------------------
if ($DryRun) {
    if ($Tag) {
        Write-Host ("DryRun：编译通过后将创建本地附注标签 {0}（不推送）" -f $Tag)
    } else {
        Write-Host ("DryRun：未传 -Tag，编译后不会打标签；默认建议标签为 {0}" -f $defaultTag)
    }
    Write-Host "DryRun 结束。" -ForegroundColor Green
    exit 0
}

# ---------------------------------------------------------------------------
# 4. 真实构建前：签名不通过则报错退出
# ---------------------------------------------------------------------------
if (-not $signingReady) {
    Fail "签名材料未就绪，无法构建正式 APK。请按上面列出的三种方式之一提供签名材料。"
}

# 标签已存在时尽早失败，避免白跑一次构建。
if ($Tag) {
    $existingEarly = (& git -C $RepoRoot tag --list $Tag | Out-String).Trim()
    if ($existingEarly) {
        Fail "标签已存在：$Tag（请换名，或先处理已有标签）"
    }
}

$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) {
    Fail "未在 PATH 中找到 flutter，请把 Flutter SDK 的 bin 目录加入 PATH"
}

$buildArgs = @(
    "build", "apk", "--release", "--flavor", "prod", "--target-platform", "android-arm64"
)

$buildArgsDisplay = $buildArgs -join " "
Write-Host ("开始构建：flutter {0}" -f $buildArgsDisplay) -ForegroundColor Cyan
& flutter @buildArgs
if ($LASTEXITCODE -ne 0) {
    Fail "flutter build apk 失败（退出码 $LASTEXITCODE）"
}
Write-Host ""

# ---------------------------------------------------------------------------
# 5. 编译后自检：签名证书 SHA-256 + 包名 / 应用名 / versionCode
# ---------------------------------------------------------------------------
$apkPath = Join-Path $RepoRoot "build\app\outputs\flutter-apk\app-prod-release.apk"
if (-not (Test-Path $apkPath)) {
    Fail "未找到构建产物：$apkPath"
}
Write-Host "构建产物：$apkPath" -ForegroundColor Green
Write-Host ""

$apksigner = Find-BuildTool "apksigner"
if ($apksigner) {
    Write-Host "签名证书（apksigner）：" -ForegroundColor Green
    # 按退出码判定成败。JVM 启动时会因本机 JAVA_TOOL_OPTIONS 往 stderr 打一行
    # "Picked up ..."；PS 5.1 在 EAP=Stop 下会把经 2>&1 合并的原生命令 stderr
    # 当成终止错误（NativeCommandError），导致校验成功也会中断脚本。这里仅在本次
    # 调用期间局部放宽 EAP 并随即恢复，真实失败仍由非零退出码兜住。
    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $verifyOutput = & $apksigner verify --print-certs $apkPath 2>&1
        $verifyExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEap
    }
    $verifyText = ($verifyOutput | Out-String)
    if ($verifyExit -ne 0) {
        Write-Host ("apksigner 校验失败（退出码 {0}），原始输出如下：" -f $verifyExit) -ForegroundColor Red
        Write-Host $verifyText
        Fail "apksigner verify 失败（退出码 $verifyExit）：APK 签名校验未通过，请勿据此版本发布。"
    }
    $certMatch = [regex]::Match($verifyText, "SHA-256 digest:\s*([0-9a-fA-F]{64})")
    if ($certMatch.Success) {
        Write-Host ("  SHA-256: {0}" -f $certMatch.Groups[1].Value)
    } else {
        Write-Host "  未能解析证书 SHA-256，原始输出如下：" -ForegroundColor Yellow
        Write-Host $verifyText
    }
} else {
    Warn "未找到 apksigner（ANDROID_HOME/build-tools 下），跳过签名证书自检"
}
Write-Host ""

$aapt2 = Find-BuildTool "aapt2"
$badgingFailed = $false
if ($aapt2) {
    Write-Host "包信息（aapt2）：" -ForegroundColor Green
    $badgingText = (& $aapt2 dump badging $apkPath | Out-String)
    $pkgMatch = [regex]::Match($badgingText, "package: name='([^']+)' versionCode='([^']+)' versionName='([^']*)'")
    $labelMatch = [regex]::Match($badgingText, "application-label:'([^']*)'")
    if ($pkgMatch.Success) {
        $actualName = $pkgMatch.Groups[1].Value
        $actualCode = $pkgMatch.Groups[2].Value
        $actualVersionName = $pkgMatch.Groups[3].Value
        Write-Host ("  package name : {0}" -f $actualName)
        Write-Host ("  versionCode  : {0}" -f $actualCode)
        Write-Host ("  versionName  : {0}" -f $actualVersionName)
        if ($actualName -ne $expectedPackage) {
            Write-Host ("  package name 与期望不符（期望 {0}）" -f $expectedPackage) -ForegroundColor Red
            $badgingFailed = $true
        }
        if ($actualCode -ne "$expectedVersionCode") {
            Write-Host ("  versionCode 与期望不符（期望 {0}）" -f $expectedVersionCode) -ForegroundColor Red
            $badgingFailed = $true
        }
    } else {
        Write-Host "  未能解析 package 信息，原始输出如下：" -ForegroundColor Yellow
        Write-Host $badgingText
        $badgingFailed = $true
    }
    if ($labelMatch.Success) {
        $actualLabel = $labelMatch.Groups[1].Value
        Write-Host ("  application-label: {0}" -f $actualLabel)
        if ($actualLabel -ne $expectedLabel) {
            Warn ("application-label 与期望不符（期望 {0}）" -f $expectedLabel)
        }
    } else {
        Warn "未能解析 application-label"
    }
} else {
    Warn "未找到 aapt2（ANDROID_HOME/build-tools 下），跳过包信息自检"
}
Write-Host ""

if ($badgingFailed) {
    Fail "编译后自检未通过：包名或 versionCode 与预期不一致，请勿据此版本发布。"
}

# ---------------------------------------------------------------------------
# 6. 可选：创建本地附注标签（不推送）
# ---------------------------------------------------------------------------
if ($Tag) {
    $existing = (& git -C $RepoRoot tag --list $Tag | Out-String).Trim()
    if ($existing) {
        Fail "标签已存在：$Tag（请换名，或先处理已有标签）"
    }
    & git -C $RepoRoot tag -a $Tag -m "release $Tag"
    if ($LASTEXITCODE -ne 0) {
        Fail "创建标签失败：$Tag"
    }
    Write-Host ("已创建本地附注标签：{0}" -f $Tag) -ForegroundColor Green
    Write-Host ("如需推送：git push origin {0}" -f $Tag) -ForegroundColor Cyan
} else {
    Write-Host ("未传 -Tag，未创建标签；默认建议标签为 {0}" -f $defaultTag) -ForegroundColor Cyan
}

Write-Host ""
Write-Host "完成。" -ForegroundColor Green
exit 0