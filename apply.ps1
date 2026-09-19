# ============================================================
#  Claude Desktop 中文语言包 - 一键应用脚本
#  每次 Claude 更新后，双击 apply-zh.bat 即可重新汉化
#  翻译文件存放在脚本目录下的 langpack\translated-zh-CN
#  修改前的原文件备份在脚本目录下的 backup
# ============================================================
[CmdletBinding()]
param(
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$baseDir   = $PSScriptRoot
$packDir   = "$baseDir\langpack\translated-zh-CN"
$backupDir = "$baseDir\backup"

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# 提权由 bat 入口统一负责，这里只做兜底检查
if (-not (Test-IsAdministrator)) {
    Write-Host "未获得管理员权限，请通过 应用中文.bat 运行本脚本。" -ForegroundColor Red
    Read-Host "按回车关闭窗口"
    exit 1
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Claude Desktop 中文语言包" -ForegroundColor Cyan
if ($Uninstall) { Write-Host "  模式: 卸载（还原英文）" -ForegroundColor Yellow }
else            { Write-Host "  模式: 应用中文" -ForegroundColor Green }
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ---------- 1. 定位 Claude ----------
Write-Host "[1/6] 查找 Claude Desktop..." -ForegroundColor Cyan
$pkg = Get-AppxPackage -Name Claude -ErrorAction SilentlyContinue |
    Sort-Object Version -Descending | Select-Object -First 1
if (-not $pkg) { Write-Host "  未检测到 Claude Desktop" -ForegroundColor Red; Read-Host "按回车关闭窗口"; exit 1 }

$claudePath = $pkg.InstallLocation
$version    = $pkg.Version.ToString()
$resources  = Join-Path $claudePath "app\resources"
Write-Host "  版本: $version" -ForegroundColor Green
Write-Host "  路径: $claudePath"
Write-Host ""

# ---------- 2. 找匹配的翻译版本 ----------
Write-Host "[2/6] 查找匹配的翻译文件..." -ForegroundColor Cyan
$available = Get-ChildItem -LiteralPath $packDir -Directory |
    Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
    ForEach-Object { [pscustomobject]@{ Name = $_.Name; Ver = [version]$_.Name } } |
    Sort-Object Ver -Descending

if (-not $available) { Write-Host "  未找到任何翻译文件，请先下载语言包" -ForegroundColor Red; Read-Host "按回车关闭窗口"; exit 1 }

$installed = [version]$version
# 精确匹配优先，其次取最接近的较旧版本，最后取最接近的较新版本
$matched = $available | Where-Object { $_.Ver -eq $installed } | Select-Object -First 1
if (-not $matched) { $matched = $available | Where-Object { $_.Ver -lt $installed } | Select-Object -First 1 }
if (-not $matched) { $matched = $available | Sort-Object Ver | Select-Object -First 1 }

$verDir = Join-Path $packDir $matched.Name
Write-Host "  使用翻译: $($matched.Name)" -ForegroundColor Green
if ($matched.Name -ne $version) {
    Write-Host "  (当前 Claude $version 与翻译 $($matched.Name) 有版本差，属正常)" -ForegroundColor DarkGray
}
Write-Host ""

# ---------- 3. 关闭 Claude + 获取权限 ----------
Write-Host "[3/6] 关闭 Claude 并获取写入权限..." -ForegroundColor Cyan
taskkill /f /im claude.exe 2>$null | Out-Null
Start-Sleep -Seconds 2

& takeown.exe /f $claudePath /r /d Y 2>$null | Out-Null
& icacls.exe $claudePath /grant "BUILTIN\Administrators:(OI)(CI)F" /t /c /q 2>$null | Out-Null
Write-Host "  完成" -ForegroundColor Green
Write-Host ""

# ---------- 4. 复制翻译文件 ----------
Write-Host "[4/6] 复制翻译文件..." -ForegroundColor Cyan

$targets = @(
    @{ Src = (Join-Path $verDir "ion-dist\zh-CN.json");       Dst = (Join-Path $resources "ion-dist\i18n\zh-CN.json") },
    @{ Src = (Join-Path $verDir "desktop-shell\zh-CN.json");  Dst = (Join-Path $resources "zh-CN.json") },
    @{ Src = (Join-Path $verDir "ion-dist\dynamic\zh-CN.json"); Dst = (Join-Path $resources "ion-dist\i18n\dynamic\zh-CN.json") }
)

foreach ($t in $targets) {
    if (-not (Test-Path -LiteralPath $t.Src)) {
        Write-Host "  缺少翻译文件: $($t.Src)" -ForegroundColor Red
        continue
    }
    [System.IO.Directory]::CreateDirectory((Split-Path -Parent $t.Dst)) | Out-Null
    Copy-Item -LiteralPath $t.Src -Destination $t.Dst -Force
    $rel = $t.Dst.Substring($resources.Length).TrimStart('\')
    Write-Host "  OK: $rel" -ForegroundColor Green
}
Write-Host ""

# ---------- 5. 注册 zh-CN 语言 ----------
Write-Host "[5/6] 在 JS 中注册中文语言..." -ForegroundColor Cyan

$assetsDir = Join-Path $resources "ion-dist\assets\v1"
if (-not (Test-Path -LiteralPath $assetsDir)) {
    Write-Host "  未找到 assets 目录，跳过 JS 补丁" -ForegroundColor Yellow
}
else {
    $jsFiles = Get-ChildItem -LiteralPath $assetsDir -Filter "*.js" -File |
        Where-Object { $_.Length -lt 10MB }

    # 需要修补的三类模式（用字符串字面量替换，安全、幂等）
    $patterns = @(
        # 1. 语言列表数组: ["en-US",...,"id-ID"] -> 加 ,"zh-CN"
        #    用通用结尾 "id-ID"] 匹配，兼容 1.x 的 "id-ID"];function 和 2.x 的 "id-ID"],xxx
        @{
            Name = "语言列表数组"
            From = '"id-ID"]'
            To   = '"id-ID","zh-CN"]'
        },
        # 2. 日期格式化 locale 映射: "id-ID":"id"} -> 加 ,"zh-CN":"zh"
        @{
            Name = "日期映射"
            From = '"id-ID":"id"};function'
            To   = '"id-ID":"id","zh-CN":"zh"};function'
        },
        # 3. persona 语言分支: case"id-ID":return["language","id"];default
        @{
            Name = "persona 分支"
            From = 'case"id-ID":return["language","id"];default'
            To   = 'case"id-ID":return["language","id"];case"zh-CN":return["language","zh"];default'
        }
    )

    $patchedCount = 0
    foreach ($f in $jsFiles) {
        $content = [System.IO.File]::ReadAllText($f.FullName)
        $changed = $false

        foreach ($p in $patterns) {
            if ($content.Contains($p.From) -and -not $content.Contains($p.To)) {
                # 备份原文件（用 .NET 字节读写，绕开 EFS 加密属性）
                $stamp = $f.Name
                $bakPath = Join-Path $backupDir "$stamp.bak"
                if (-not (Test-Path -LiteralPath $bakPath)) {
                    [System.IO.Directory]::CreateDirectory($backupDir) | Out-Null
                    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
                    [System.IO.File]::WriteAllBytes($bakPath, $bytes)
                }
                $content = $content.Replace($p.From, $p.To)
                $changed = $true
            }
        }

        if ($changed) {
            [System.IO.File]::WriteAllText($f.FullName, $content, [System.Text.UTF8Encoding]::new($false))
            $patchedCount++
        }
    }
    Write-Host "  已修补 $patchedCount 个 JS 文件" -ForegroundColor Green
}
Write-Host ""

# ---------- 6. 更新配置 ----------
Write-Host "[6/6] 更新配置文件..." -ForegroundColor Cyan
$configPaths = @(
    (Join-Path $env:APPDATA "Claude\config.json"),
    (Join-Path $env:LOCALAPPDATA "Claude\config.json"),
    (Join-Path $env:LOCALAPPDATA "Claude-3p\config.json")
)

foreach ($cp in $configPaths) {
    if (Test-Path -LiteralPath $cp) {
        try {
            $json = Get-Content -LiteralPath $cp -Raw | ConvertFrom-Json
            if ($Uninstall) { $json.locale = "en-US" }
            else            { $json.locale = "zh-CN" }
            $json | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $cp -Encoding UTF8
            Write-Host "  OK: $cp -> locale=$($json.locale)" -ForegroundColor Green
        }
        catch {
            Write-Host "  更新失败: $cp ($($_.Exception.Message))" -ForegroundColor Yellow
        }
    }
}
Write-Host ""

# ---------- 完成 ----------
Write-Host "============================================" -ForegroundColor Cyan
if ($Uninstall) { Write-Host "  已还原为英文，重启 Claude 后生效" -ForegroundColor Green }
else            { Write-Host "  中文已应用，正在重启 Claude..." -ForegroundColor Green }
Write-Host "============================================" -ForegroundColor Cyan

# 重启 Claude
if (-not $Uninstall) {
    Start-Sleep -Seconds 1
    $appUserModelId = "Claude_pzs8sxrjxfjjc!Claude"
    try {
        Start-Process "shell:AppsFolder\$appUserModelId" -ErrorAction SilentlyContinue
    }
    catch {
        # 若 AppUserModelId 失效，直接启动 exe
        $exe = Join-Path $claudePath "app\claude.exe"
        if (Test-Path -LiteralPath $exe) { Start-Process $exe }
    }
}

Write-Host ""
Write-Host "按任意键关闭窗口..." -ForegroundColor DarkGray
$null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
