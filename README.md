# Como adicionar um novo vídeo (VSL) ao repositório

Este guia explica como pegar um arquivo `.mp4`, quebrar em HLS (`.m3u8` + `.ts`) com **FFmpeg** e publicar como uma nova VSL no repositório `dev-txt/vsl`.

---

## 1. Pré-requisitos

### 1.1. Ter Git instalado

Verifique no terminal:

    git --version

Se não reconhecer o comando, instale o Git antes de continuar.

### 1.2. Instalar FFmpeg (pela linha de comando)

Use o comando de acordo com seu sistema:

**Ubuntu / Debian (Linux)**

    sudo apt update && sudo apt install -y ffmpeg

**macOS (com Homebrew instalado)**

    brew install ffmpeg

**Windows (com Chocolatey instalado)**  
Abra o PowerShell como Administrador:

    choco install ffmpeg -y

Depois confirme se está ok:

    ffmpeg -version

Se aparecer a versão do FFmpeg, você está pronto.

---

## 2. Clonar ou atualizar o repositório

### 2.1. Se ainda NÃO tiver o repositório local

No terminal:

    git clone https://github.com/dev-txt/vsl.git
    cd vsl

### 2.2. Se JÁ tiver o repositório local

Entre na pasta do projeto e atualize:

    cd vsl
    git pull origin main

---

## 3. Preparar o novo vídeo

1. Escolha um nome de pasta para a nova VSL, seguindo o padrão:

   - `vsl_001`
   - `vsl_002`
   - `vsl_003`
   - `vsl_004`
   - etc.

2. Copie o arquivo `.mp4` para a raiz do repositório (por exemplo: `meu_video.mp4` na pasta `vsl`).

3. Crie a pasta da nova VSL (exemplo: `vsl_004`):

    mkdir vsl_004

---

## 4. Quebrar o vídeo em HLS com FFmpeg

Ainda na raiz do repositório (onde está o `meu_video.mp4`), execute o comando abaixo EM UMA LINHA:

    ffmpeg -i meu_video.mp4 -codec:v libx264 -codec:a aac -hls_time 6 -hls_playlist_type vod -hls_segment_filename "vsl_004/segment_%03d.ts" vsl_004/index.m3u8

Esse comando vai:

- Ler o arquivo de entrada `meu_video.mp4`
- Criar a playlist HLS em: `vsl_004/index.m3u8`
- Gerar vários segmentos `.ts`:

  - `vsl_004/segment_000.ts`
  - `vsl_004/segment_001.ts`
  - `vsl_004/segment_002.ts`
  - ...

Verifique depois:

- Dentro de `vsl_004` deve existir:
  - 1 arquivo `index.m3u8`
  - vários arquivos `segment_XXX.ts`

---

## 5. Atualizar o `player.html` (se for usar o parâmetro `?v=`)

Se o player estiver configurado para aceitar VSLs via parâmetro, como:

- `player.html?v=vsl_001`
- `player.html?v=vsl_002`
- `player.html?v=vsl_003`

Então edite o arquivo `player.html` na raiz do repositório e atualize a lista de VSLs permitidas.

Procure a linha (exemplo):

    const allowed = ['vsl_001', 'vsl_002', 'vsl_003'];

Inclua a nova VSL, por exemplo:

    const allowed = ['vsl_001', 'vsl_002', 'vsl_003', 'vsl_004'];

Salve o arquivo.

---

## 6. Comitar e enviar as mudanças para o GitHub

Na raiz do repositório, execute:

    git add vsl_004
    git add player.html
    git commit -m "Add nova VSL vsl_004"
    git push origin main

Após o `git push`, o GitHub Pages vai publicar automaticamente a nova versão do site.

---

## 7. Como usar a nova VSL

### 7.1. Via iframe (usando `player.html`)

Depois do deploy, a URL base será algo como:

    https://dev-txt.github.io/vsl/

Para a nova VSL, você pode usar:

    https://dev-txt.github.io/vsl/player.html?v=vsl_004

Exemplo de iframe para embutir em qualquer página:

```html
<iframe
  src="https://dev-txt.github.io/vsl/player.html?v=vsl_004"
  width="100%"
  height="360"
  frameborder="0"
  allow="autoplay; fullscreen"
  allowfullscreen>
</iframe>
