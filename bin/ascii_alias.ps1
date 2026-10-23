<#
=====================================================================
 智美成ERP系统 · ASCII 路径别名助手
   Windows 下有两处必须使用纯 ASCII 路径,否则一定出问题:
     1) nginx   —— 处理含中文的路径会报
                    "CreateFile() ... failed (1113: No mapping for the Unicode character)"
     2) PHP 扩展 —— extension_dir 最终交给 LoadLibraryExA(ANSI 路径),
                    里面只要含中文,扩展 DLL 必定加载失败
                    (报 "Unable to load dynamic library ... 找不到指定的模块")
   做法:在临时目录建一个指向本安装目录的「目录联接(junction)」,
        它只是一个指针,不复制任何文件,删掉也不影响任何数据。
   为避免多套安装互相覆盖,别名带安装目录的哈希后缀。
=====================================================================
#>

function Get-ZmcShortHash {
    param([string]$Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text))
    } finally {
        $sha.Dispose()
    }
    return ([System.BitConverter]::ToString($bytes)).Replace('-', '').Substring(0, 8).ToLowerInvariant()
}

function Get-ZmcAsciiBaseDir {
    # 找一个能放联接的、纯 ASCII 的目录
    $candidates = @()
    if ($env:TEMP)      { $candidates += $env:TEMP }
    if ($env:SystemRoot) { $candidates += $env:SystemRoot }
    $candidates += 'C:\'
    foreach ($c in $candidates) {
        if (-not $c) { continue }
        if ($c -match '[^\x00-\x7F]') { continue }
        try { if (Test-Path -LiteralPath $c) { return $c } } catch { }
    }
    return $null
}

function Get-ZmcAliasPath {
    # 返回本安装目录对应的 ASCII 别名路径(只算路径,不创建)
    param([string]$Root)
    $base = Get-ZmcAsciiBaseDir
    if (-not $base) { return $null }
    return (Join-Path $base ('ZMC_ERP_' + (Get-ZmcShortHash $Root)))
}

function Test-ZmcNonAscii {
    param([string]$Path)
    if (-not $Path) { return $false }
    return ($Path -match '[^\x00-\x7F]')
}

function Initialize-ZmcAsciiAlias {
    # 安装目录含中文时建立 ASCII 目录联接。
    # 返回:纯 ASCII 目录直接返回 $Root;含中文则返回别名路径;失败返回 $null。
    param([string]$Root)
    if (-not (Test-ZmcNonAscii $Root)) { return $Root }

    $alias = Get-ZmcAliasPath -Root $Root
    if (-not $alias) { return $null }

    try {
        if (Test-Path -LiteralPath $alias) {
            $item = Get-Item -LiteralPath $alias -Force
            $cur = ''
            try { $cur = (@($item.Target) | Select-Object -First 1) } catch { }
            if ($item.LinkType -eq 'Junction' -and $cur) {
                $a = $cur.TrimEnd('\')
                $b = $Root.TrimEnd('\')
                if ($a -ieq $b) { return $alias }
            }
            & cmd.exe /c ('rmdir "' + $alias + '"') 2>&1 | Out-Null
        }
        & cmd.exe /c ('mklink /J "' + $alias + '" "' + $Root + '"') 2>&1 | Out-Null
        if (Test-Path -LiteralPath $alias) { return $alias }
    } catch { }
    return $null
}

function Initialize-ZmcAsciiAliasFor {
    # 只给「含中文的子目录」建别名(用于 ext 扩展目录的兜底方案)
    param([string]$Root, [string]$SubPath)
    if (-not (Test-ZmcNonAscii $SubPath)) { return $SubPath }
    $base = Get-ZmcAsciiBaseDir
    if (-not $base) { return $null }
    $alias = Join-Path $base ('ZMC_EXT_' + (Get-ZmcShortHash $SubPath))
    try {
        if (Test-Path -LiteralPath $alias) {
            $item = Get-Item -LiteralPath $alias -Force
            $cur = ''
            try { $cur = (@($item.Target) | Select-Object -First 1) } catch { }
            if ($item.LinkType -eq 'Junction' -and $cur) {
                if ($cur.TrimEnd('\') -ieq $SubPath.TrimEnd('\')) { return $alias }
            }
            & cmd.exe /c ('rmdir "' + $alias + '"') 2>&1 | Out-Null
        }
        & cmd.exe /c ('mklink /J "' + $alias + '" "' + $SubPath + '"') 2>&1 | Out-Null
        if (Test-Path -LiteralPath $alias) { return $alias }
    } catch { }
    return $null
}
