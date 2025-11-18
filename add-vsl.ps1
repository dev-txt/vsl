# add-vsl.ps1
# Script para Windows / PowerShell
# Automatiza:
# - detectar proximo vsl_00X
# - quebrar video em HLS
# - atualizar player.html
# - (opcional) git add/commit/push

$ErrorActionPreference = 'Stop'

Write-Host "=== ADD VSL ===" -ForegroundColor Cyan

# 1) Descobrir raiz do repo (onde o script esta)
$scriptPath = $MyInvocation.MyCommand.Path
$repoRoot   = Split-Path -Parent $scriptPath
Set-Location $repoRoot

Write-Host "Repo root: $repoRoot"

# 2) Verificar ffmpeg
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host "ERRO: ffmpeg nao encontrado no PATH." -ForegroundColor Red
    Write-Host 'Instale com:  winget install "FFmpeg (Essentials Build)"'
    exit 1
}

# 3) Perguntar caminho do video ou pasta
Write-Host ""
$inputPath = Read-Host "Arraste aqui o arquivo .mp4 ou digite o caminho da pasta/arquivo"
$inputPath = $inputPath.Trim('"').Trim()

if (-not $inputPath) {
    Write-Host "Nenhum caminho informado. Saindo." -ForegroundColor Yellow
    exit 1
}

if (Test-Path $inputPath -PathType Container) {
    # Pasta: pega o primeiro .mp4
    $videoFile = Get-ChildItem $inputPath -Filter *.mp4 | Select-Object -First 1
    if (-not $videoFile) {
        Write-Host "Nenhum .mp4 encontrado na pasta." -ForegroundColor Red
        exit 1
    }
    $videoPath = $videoFile.FullName
} elseif (Test-Path $inputPath -PathType Leaf) {
    # Arquivo direto
    $videoPath = (Resolve-Path $inputPath).Path
} else {
    Write-Host "Caminho invalido: $inputPath" -ForegroundColor Red
    exit 1
}

Write-Host "Usando video: $videoPath" -ForegroundColor Green

# 4) Descobrir proximo vsl_00X

$dirs = Get-ChildItem -Directory -Name | Where-Object { $_ -match '^vsl_(\d+)$' }

$maxNum = 0
if ($dirs) {
    foreach ($d in $dirs) {
        if ($d -match '^vsl_(\d+)$') {
            $n = [int]$Matches[1]
            if ($n -gt $maxNum) { $maxNum = $n }
        }
    }
}

$nextNumber = $maxNum + 1
# pad com zeros: pega sempre os ultimos 3 digitos
$folderNumberPadded = ('000' + $nextNumber) -replace '.*(...$)', '$1'
$folderName = "vsl_$folderNumberPadded"
$folderPath = Join-Path $repoRoot $folderName

Write-Host "Nova pasta da VSL: $folderName" -ForegroundColor Cyan

# 5) Criar pasta
if (-not (Test-Path $folderPath)) {
    New-Item -ItemType Directory -Path $folderPath | Out-Null
}

# 6) Rodar ffmpeg para quebrar o video
# Usar / nos caminhos para os segmentos
$segmentPattern = "$folderName/segment_%03d.ts"
$outputIndex    = "$folderName/index.m3u8"

Write-Host ""
Write-Host "Quebrando video em HLS..." -ForegroundColor Cyan
Write-Host "ffmpeg -i `"$videoPath`" ... -> $outputIndex" -ForegroundColor DarkGray

& ffmpeg -i $videoPath `
    -codec:v libx264 -codec:a aac `
    -hls_time 6 -hls_playlist_type vod `
    -hls_segment_filename $segmentPattern `
    $outputIndex

if ($LASTEXITCODE -ne 0) {
    Write-Host "ffmpeg retornou codigo $LASTEXITCODE. Algo deu errado." -ForegroundColor Red
    exit 1
}

Write-Host "HLS gerado em: $folderName" -ForegroundColor Green

# 7) Atualizar player.html (lista allowed)
$playerPath = Join-Path $repoRoot 'player.html'
if (-not (Test-Path $playerPath)) {
    Write-Host "player.html nao encontrado na raiz. Pulei atualizacao." -ForegroundColor Yellow
} else {
    Write-Host "Atualizando player.html..." -ForegroundColor Cyan

    # ler e gravar explicitamente como UTF-8
    $content = Get-Content $playerPath -Raw -Encoding UTF8
    $pattern = 'const allowed = \[(.*?)\];'

    if ($content -match $pattern) {
        $listText = $Matches[1].Trim()
        $items = @()

        if ($listText) {
            $items = $listText -split ',' | ForEach-Object { $_.Trim() }
        }

        $newItem = "'$folderName'"

        if ($items -notcontains $newItem) {
            $items += $newItem
        } else {
            Write-Host "Item $newItem ja existe em allowed." -ForegroundColor Yellow
        }

        $newList = [string]::Join(', ', $items)
        $newContent = $content -replace $pattern, "const allowed = [$newList];"

        Set-Content $playerPath -Value $newContent -Encoding UTF8
        Write-Host "player.html atualizado com $folderName." -ForegroundColor Green
    } else {
        Write-Host 'Nao encontrei linha "const allowed = [...]" em player.html.' -ForegroundColor Yellow
    }
}

# 8) (Opcional) git add/commit/push
Write-Host ""
$doGit = Read-Host "Deseja fazer git add/commit/push agora? (s/n)"

if ($doGit -eq 's' -or $doGit -eq 'S') {
    try {
        git add $folderName player.html
        $msg = "Add nova VSL $folderName"
        git commit -m $msg
        git push origin main
        Write-Host "Git push concluido." -ForegroundColor Green
    } catch {
        Write-Host "Falha ao executar git add/commit/push: $_" -ForegroundColor Red
    }
} else {
    Write-Host "Ok, sem git automatico. Faca na mao depois." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Concluido. Nova VSL: $folderName" -ForegroundColor Cyan
Write-Host "URL HLS: https://dev-txt.github.io/vsl/$folderName/index.m3u8"
Write-Host "URL player: https://dev-txt.github.io/vsl/player.html?v=$folderName"
