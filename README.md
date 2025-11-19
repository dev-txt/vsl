# Como adicionar um novo vídeo (VSL) ao repositório (Windows)

Este guia mostra como, no **Windows**, pegar um arquivo `.mp4`, quebrar em HLS (`.m3u8` + `.ts`) com **FFmpeg** e publicar como uma nova VSL no repositório `dev-txt/vsl`, usando:

1. Modo recomendado: **script `add-vsl.ps1`** (automático: ADD/DELETE + update do `player.html`)
2. Modo manual: comandos diretos (para quem quiser controle total)

---

## 1. Pré-requisitos (Windows)

### 1.1. Ter Git instalado

No Prompt de Comando ou PowerShell:

    git --version

Se não aparecer a versão, instale o Git pelo site oficial antes de continuar.

### 1.2. Instalar o FFmpeg com 1 comando (via winget)

No Windows 10 ou 11, abra o **PowerShell** (pode ser normal mesmo) e rode:

    winget install "FFmpeg (Essentials Build)"

Depois confirme se deu certo:

    ffmpeg -version

Se aparecer a versão do FFmpeg, está pronto para uso.

---

## 2. Clonar ou atualizar o repositório

### 2.1. Se ainda NÃO tiver o repositório local

No PowerShell ou Prompt:

    git clone https://github.com/dev-txt/vsl.git
    cd vsl

### 2.2. Se JÁ tiver o repositório local

    cd vsl
    git pull origin main

---

## 3. Modo recomendado: usando o script `add-vsl.ps1` (ADD & DELETE)

O script `add-vsl.ps1` automatiza:

- Descobrir o próximo `vsl_00X`
- Quebrar o vídeo em HLS
- Atualizar o `player.html` (`const allowed = [...]`)
- Opcionalmente rodar `git add/commit/push`
- Deletar uma VSL existente (pasta + remoção da lista `allowed`)

> O script foi feito para rodar em **Windows / PowerShell**.

### 3.1. Pré-requisitos específicos do script

- FFmpeg instalado e acessível no `PATH` (veja seção 1.2).
- Repositório `vsl` clonado localmente (veja seção 2).
- Arquivo `add-vsl.ps1` salvo na **raiz do repositório** (mesmo lugar do `player.html`).

### 3.2. Executando o script

No PowerShell:

    cd CAMINHO\PARA\vsl
    .\add-vsl.ps1

O script mostrará um menu:

    === VSL TOOL ===
    1) Adicionar nova VSL
    2) Deletar VSL existente

Escolha `1` ou `2` e pressione Enter.

---

### 3.3. Opção 1 – Adicionar nova VSL via script

Fluxo quando você escolhe **1) Adicionar nova VSL**:

1. O script pergunta o caminho do vídeo:

   - Você pode **arrastar o arquivo `.mp4`** para dentro da janela do PowerShell, ou  
   - Digitar o caminho completo do arquivo ou da pasta que contém o `.mp4`  
     (se for pasta, ele usa o primeiro `.mp4` encontrado na pasta).

2. O script então:

   - Detecta automaticamente qual será a próxima pasta:
     - `vsl_001`, `vsl_002`, `vsl_003`, `vsl_004`, ...
   - Cria a pasta nova dentro do repositório, por exemplo: `vsl_004`
   - Roda o FFmpeg e gera:
     - `vsl_004/index.m3u8`
     - `vsl_004/segment_000.ts`, `segment_001.ts`, ...
   - Atualiza o `player.html`, adicionando a pasta na linha:

         const allowed = ['vsl_001', 'vsl_002', ..., 'vsl_00X'];

   - Pergunta se você quer que ele faça automaticamente:
     - `git add`
     - `git commit`
     - `git push origin main`

3. No final, o script mostra as URLs prontas, por exemplo:

   - Playlist HLS:

         https://dev-txt.github.io/vsl/vsl_00X/index.m3u8

   - Player com botão de unmute:

         https://dev-txt.github.io/vsl/player.html?v=vsl_00X

---

### 3.4. Opção 2 – Deletar VSL existente via script

Fluxo quando você escolhe **2) Deletar VSL existente**:

1. O script lista as pastas de VSL:

       Pastas de VSL disponiveis:
        - vsl_001
        - vsl_002
        - vsl_003
        - vsl_004

2. Ele pergunta qual VSL remover:

       Digite o nome exato da VSL a deletar (ex: vsl_004)

3. PedE uma confirmação:

       Tem certeza que deseja deletar vsl_004? (s/n)

4. Se você confirmar com `s`:

   - Remove a pasta física, por exemplo `vsl_004`
   - Atualiza o `player.html`, removendo essa VSL da lista:

         const allowed = ['vsl_001', 'vsl_002', 'vsl_003', 'vsl_004'];

     ficando, por exemplo:

         const allowed = ['vsl_001', 'vsl_002', 'vsl_003'];

   - Pergunta se você quer rodar:
     - `git add`
     - `git commit`
     - `git push origin main`

5. No final, mostra algo como:

       Remocao de vsl_004 concluida.

### 3.5. Quando faz sentido usar o script

Use o `add-vsl.ps1` quando quiser:

- Não esquentar a cabeça com numeração (`vsl_001`, `vsl_002`, …)
- Evitar editar `player.html` na mão
- Reduzir chance de erro em comando de FFmpeg / Git
- Deletar VSLs antigas de forma consistente (pasta + `allowed`)

Se quiser controle manual, use a próxima seção.

---

## 4. Modo manual: sem script

Se você prefere fazer tudo na mão (ou se o script não estiver disponível), dá para fazer o processo inteiro manualmente.

### 4.1. Preparar o novo vídeo

1. Escolha o nome da pasta da nova VSL:

   - `vsl_001`
   - `vsl_002`
   - `vsl_003`
   - `vsl_004`
   - etc.

2. Copie o `.mp4` para a **raiz do repositório** (mesma pasta do `player.html`), por exemplo:

   - `meu_video.mp4`

3. Crie a pasta da nova VSL (exemplo `vsl_004`):

       mkdir vsl_004

---

### 4.2. Quebrar o vídeo em HLS com FFmpeg (1 linha)

Na raiz do repositório, rode:

    ffmpeg -i meu_video.mp4 -codec:v libx264 -codec:a aac -hls_time 6 -hls_playlist_type vod -hls_segment_filename "vsl_004/segment_%03d.ts" vsl_004/index.m3u8

Isso vai:

- Ler `meu_video.mp4`
- Criar a playlist HLS: `vsl_004/index.m3u8`
- Gerar os segmentos:

  - `vsl_004/segment_000.ts`
  - `vsl_004/segment_001.ts`
  - `vsl_004/segment_002.ts`
  - ...

Confere depois:

- Em `vsl_004` deve ter:
  - `index.m3u8`
  - vários `segment_XXX.ts`

---

### 4.3. Atualizar o `player.html` para reconhecer a nova VSL

Abra o arquivo `player.html` na raiz do repositório e procure a linha:

    const allowed = ['vsl_001', 'vsl_002', 'vsl_003'];

Inclua a nova VSL na lista. Exemplo, se criou `vsl_004`:

    const allowed = ['vsl_001', 'vsl_002', 'vsl_003', 'vsl_004'];

Salve o arquivo.

---

### 4.4. Comitar e enviar as mudanças para o GitHub

Na raiz do repositório:

    git add vsl_004
    git add player.html
    git commit -m "Add nova VSL vsl_004"
    git push origin main

O GitHub Pages vai atualizar o site automaticamente após o `push`.

---

## 5. Como usar a VSL publicada

### 5.1. Via iframe (usando `player.html`)

URL base do site:

    https://dev-txt.github.io/vsl/

URL do player para uma VSL específica (exemplo `vsl_004`):

    https://dev-txt.github.io/vsl/player.html?v=vsl_004

Exemplo de uso com `<iframe>` em qualquer página HTML:

    <iframe
      src="https://dev-txt.github.io/vsl/player.html?v=vsl_004"
      width="100%"
      height="360"
      frameborder="0"
      allow="autoplay; fullscreen"
      allowfullscreen>
    </iframe>

### 5.2. Via player próprio (HLS direto)

Playlist HLS pública (exemplo `vsl_004`):

    https://dev-txt.github.io/vsl/vsl_004/index.m3u8

Você pode usar essa URL em qualquer player compatível com HLS (`hls.js`, players nativos, etc).

---

Modo preguiçoso e eficiente: seção 3 (script).
Modo raiz e manual: seção 4 (sem script).
