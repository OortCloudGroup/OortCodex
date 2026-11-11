param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [string]$ExePath = "G:\lanjian\nginx\html_88_56\OortCodex-Desktop.exe",

    [string]$JsonPath = "latest.json"
)

$ErrorActionPreference = "Stop"

function Resolve-ProjectPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path (Get-Location) $Path
}

try {
    $resolvedExePath = Resolve-ProjectPath -Path $ExePath
    $resolvedJsonPath = Resolve-ProjectPath -Path $JsonPath

    if (-not (Test-Path -LiteralPath $resolvedExePath -PathType Leaf)) {
        throw "exe 文件不存在：$resolvedExePath"
    }

    if (-not (Test-Path -LiteralPath $resolvedJsonPath -PathType Leaf)) {
        throw "latest.json 文件不存在：$resolvedJsonPath"
    }

    $latest = Get-Content -Raw -LiteralPath $resolvedJsonPath | ConvertFrom-Json
    $sha1Hash = (Get-FileHash -LiteralPath $resolvedExePath -Algorithm SHA1).Hash.ToLower()
    $sha256Hash = (Get-FileHash -LiteralPath $resolvedExePath -Algorithm SHA256).Hash.ToLower()

    # 防呆：2026-11-11 发布 1.1.7 时，安装包还没替换就运行了本脚本，
    # 清单写入了新版本号和旧安装包的哈希，客户端升级时 sha256 校验失败。
    # Windows 安装包自带版本信息，必须与要发布的版本号一致。
    $exeVersion = (Get-Item -LiteralPath $resolvedExePath).VersionInfo.ProductVersion
    if ($exeVersion -and $exeVersion.Trim() -ne $Version -and $exeVersion.Trim() -ne "$Version.0") {
        throw "安装包版本为 $exeVersion，与要发布的 $Version 不一致：$resolvedExePath"
    }
    # 版本号变了但哈希与清单旧值相同，说明安装包还是上一版，直接中止。
    if ($latest.version -ne $Version -and $latest.sha256hash -eq $sha256Hash) {
        throw "安装包哈希与 $($latest.version) 版清单相同，可能还是旧安装包，请先替换再运行：$resolvedExePath"
    }

    $timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
    $productVersion = "$Version.0"

    # 更新发布信息字段
    $latest.url = $latest.url -replace "/download/v[^/]+/", "/download/v$Version/"
    $latest.name = $Version
    $latest.version = $Version
    $latest.productVersion = $productVersion
    $latest.hash = $sha1Hash
    $latest.timestamp = $timestamp
    $latest.sha256hash = $sha256Hash

    $json = $latest | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($resolvedJsonPath, $json, [System.Text.UTF8Encoding]::new($false))

    Write-Host "更新完成：$resolvedJsonPath"
    Write-Host "版本号：$Version"
    Write-Host "productVersion：$productVersion"
    Write-Host "SHA1：$sha1Hash"
    Write-Host "SHA256：$sha256Hash"
    Write-Host "时间戳：$timestamp"
}
catch {
    Write-Error "更新 latest.json 失败：$($_.Exception.Message)"
    exit 1
}
