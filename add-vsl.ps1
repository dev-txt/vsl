# add-vsl.ps1
# Ferramenta para gerenciar VSLs (Windows / PowerShell)
# Funcoes:
# 1) Adicionar nova VSL (cria pasta vsl_00X, roda ffmpeg, atualiza player.html)
# 2) Deletar VSL existente (remove pasta vsl_00X e atualiza player.html)

$ErrorActionPreference = 'Stop'

# Descobrir raiz do repo (onde o script esta)
$scriptPath = $MyInvocation.MyCommand.Path
$repoRoot   = Split-Path -Parent $scriptPath
Set-Location $repoRoot

$playerPath = Join-Path $repoRoot 'player.html'

function Update-Allowed {
    param(
        [string]$FolderName,
        [string]$Action # "add" ou "remove"
    )

    if (-not (Test-Path $playerPath)) {
        Write-Host "player.html nao encontrado na raiz. Pulei atualizacao." -ForegroundColor Yellow
        return
    }

    $content = Get-Content $playerPath -Raw -Encoding UTF8
    $pattern = 'const allowed = \[(.*?)\];'

    if ($content -notmatch $pattern) {
        Write-Host 'Nao encontrei linha "const allowed = [...]" em player.html.' -ForegroundColor Yellow
        return
    }

    $listText = $Matches[1].Trim()
    $items = @()

    if ($listText) {
        $items = $listText -split ',' | ForEach-Object { $_.Trim() }
    }

    $newItem = "'$FolderName'"

    if ($Action -eq 'add') {
        if ($items -notcontains $newItem) {
            $items += $newItem
        } else {
            Write-Host "Item $newItem ja existe em allowed." -ForegroundColor Yellow
        }
    }
    elseif ($Action -eq 'remove') {
        $items = $items | Where-Object { $_ -ne $newItem }
    }

    $newList = [string]::Join(', ', $items)
    $newContent = $content -replace $pattern, "const allowed = [$newList];"

    Set-Content $playerPath -Value $newContent -Encoding UTF8
    Write-Host "player.html atualizado ($Action $FolderName)." -ForegroundColor Green
}

function Add-Vsl {
    Write-Host ""
    Write-Host "=== MODO: ADICIONAR NOVA VSL ===" -ForegroundColor Cyan

    # Verificar ffmpeg
    if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
        Write-Host "ERRO: ffmpeg nao encontrado no PATH." -ForegroundColor Red
        Write-Host 'Instale com:  winget install "FFmpeg (Essentials Build)"'
        exit 1
    }

    # Perguntar caminho do video ou pasta
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

    # Descobrir proximo vsl_00X
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

    # Criar pasta
    if (-not (Test-Path $folderPath)) {
        New-Item -ItemType Directory -Path $folderPath | Out-Null
    }

    # Rodar ffmpeg para quebrar o video
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

    # Atualizar player.html (lista allowed)
    Update-Allowed -FolderName $folderName -Action 'add'

    # Git opcional
    Write-Host ""
    $doGit = Read-Host "Deseja fazer git add/commit/push agora? (s/n)"

    if ($doGit -eq 's' -or $doGit -eq 'S') {
        try {
            git add $folderName $playerPath
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
}

function Remove-Vsl {
    Write-Host ""
    Write-Host "=== MODO: DELETAR VSL EXISTENTE ===" -ForegroundColor Cyan

    $dirs = Get-ChildItem -Directory -Name | Where-Object { $_ -match '^vsl_(\d+)$' } | Sort-Object

    if (-not $dirs -or $dirs.Count -eq 0) {
        Write-Host "Nao ha pastas vsl_*** para deletar." -ForegroundColor Yellow
        return
    }

    Write-Host "Pastas de VSL disponiveis:" -ForegroundColor Gray
    foreach ($d in $dirs) {
        Write-Host " - $d"
    }

    Write-Host ""
    $target = Read-Host "Digite o nome exato da VSL a deletar (ex: vsl_004)"
    $target = $target.Trim()

    if (-not $target) {
        Write-Host "Nenhum nome informado. Saindo." -ForegroundColor Yellow
        return
    }

    if ($dirs -notcontains $target) {
        Write-Host "VSL $target nao encontrada na lista de pastas." -ForegroundColor Red
        return
    }

    $confirm = Read-Host "Tem certeza que deseja deletar $target? (s/n)"
    if ($confirm -ne 's' -and $confirm -ne 'S') {
        Write-Host "Operacao cancelada." -ForegroundColor Yellow
        return
    }

    # Remover pasta fisica
    $folderPath = Join-Path $repoRoot $target
    if (Test-Path $folderPath) {
        Remove-Item -Recurse -Force $folderPath
        Write-Host "Pasta $target removida." -ForegroundColor Green
    } else {
        Write-Host "Pasta $target nao encontrada no disco (talvez ja removida)." -ForegroundColor Yellow
    }

    # Atualizar allowed em player.html
    Update-Allowed -FolderName $target -Action 'remove'

    # Git opcional
    Write-Host ""
    $doGit = Read-Host "Deseja fazer git add/commit/push da remocao agora? (s/n)"

    if ($doGit -eq 's' -or $doGit -eq 'S') {
        try {
            git add $target $playerPath
            $msg = "Remove VSL $target"
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
    Write-Host "Remocao de $target concluida." -ForegroundColor Cyan
}

Write-Host "=== VSL TOOL ===" -ForegroundColor Cyan
Write-Host "1) Adicionar nova VSL"
Write-Host "2) Deletar VSL existente"
$mode = Read-Host "Escolha uma opcao (1 ou 2)"

switch ($mode) {
    '1' { Add-Vsl }
    '2' { Remove-Vsl }
    default {
        Write-Host "Opcao invalida. Saindo." -ForegroundColor Yellow
        exit 1
    }
}
