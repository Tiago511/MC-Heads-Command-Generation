<#
.SYNOPSIS
    Minecraft Custom Heads Full Database Visual Gallery (API v2)
.DESCRIPTION
    Fetches all 11 categories from Minecraft-Heads.com API v2 with local 24-hour caching per category,
    strict input validation, and built-in request rate-limiting. Generates a single optimized
    local HTML gallery with category filtering, advanced search, pagination, and /give export.
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$AppUuid,

    [Parameter(Mandatory = $false)]
    [ValidateLength(8, 256)]
    [string]$ApiKey,

    # Padrão: todas as 11 categorias do Minecraft-Heads
    [Parameter(Mandatory = $false)]
    [int[]]$Categories = @(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11),

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 168)]
    [int]$CacheHours = 24,

    [Parameter(Mandatory = $false)]
    [switch]$ForceRefresh,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "$env:USERPROFILE\Downloads\mc_heads_full_gallery.html"
)

if ([string]::IsNullOrWhiteSpace($AppUuid) -or [string]::IsNullOrWhiteSpace($ApiKey)) {
    Write-Host "Error: You must provide both -AppUuid and -ApiKey parameters." -ForegroundColor Red
    Write-Host "Example: .\generate-all-heads.ps1 -AppUuid 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' -ApiKey 'your-key'" -ForegroundColor Yellow
    exit 1
}

if ($ApiKey -match 'YOUR-API-KEY') {
    Write-Host "Error: Replace the placeholder with your real Minecraft-Heads API key." -ForegroundColor Red
    exit 1
}

# Chaves em string para compatibilidade com ConvertTo-Json no PowerShell 5.1
$categoryNames = @{
    "1"  = "Alphabet"
    "2"  = "Animals"
    "3"  = "Blocks"
    "4"  = "Decoration"
    "5"  = "Food & Drinks"
    "6"  = "Humans"
    "7"  = "Humanoids"
    "8"  = "Miscellaneous"
    "9"  = "Monsters"
    "10" = "Plants"
    "11" = "Helmets"
}

$cacheDir = Join-Path $env:TEMP "mc-heads-api-cache"
if (-not (Test-Path $cacheDir)) {
    New-Item -ItemType Directory -Path $cacheDir | Out-Null
}

$headers = @{ "api-key" = $ApiKey }
$rateLimitMs = 1500
$maxPages = 50

$galleryItems = [System.Collections.Generic.List[object]]::new()
$globalCounter = 1

try {
    foreach ($catId in $Categories) {
        $catKey = "$catId"
        $catLabel = if ($categoryNames.ContainsKey($catKey)) { $categoryNames[$catKey] } else { "Category $catId" }
        $cacheFile = Join-Path $cacheDir "category_$catId.json"
        $catHeads = [System.Collections.Generic.List[object]]::new()
        $useCache = $false

        if (-not $ForceRefresh -and (Test-Path $cacheFile)) {
            $cacheAge = (Get-Date) - (Get-Item $cacheFile).LastWriteTime
            if ($cacheAge.TotalHours -lt $CacheHours) {
                $useCache = $true
            }
        }

        if ($useCache) {
            Write-Host "[$catLabel] Using local cache (updated $([Math]::Round($cacheAge.TotalHours, 1))h ago)..." -ForegroundColor Green
            $cachedContent = Get-Content -Path $cacheFile -Raw -Encoding UTF8
            foreach ($item in @($cachedContent | ConvertFrom-Json)) {
                $catHeads.Add($item)
            }
        }
        else {
            Write-Host "[$catLabel] Fetching from Minecraft-Heads.com API v2 (ID: $catId)..." -ForegroundColor Cyan
            $page = 1
            $seenHeadIds = [System.Collections.Generic.HashSet[string]]::new()

            while ($page -le $maxPages) {
                $url = "https://minecraft-heads.com/api/heads/custom-heads?app_uuid=$AppUuid&category_id=$catId&page=$page&value=true"
                $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get

                if (-not $response.data -or $response.data.Count -eq 0) {
                    break
                }

                $newItemsAdded = 0
                foreach ($item in $response.data) {
                    $itemKey = if ($item.id) { "$($item.id)" } else { "$($item.n)|$($item.u)" }
                    if ($seenHeadIds.Add($itemKey)) {
                        $catHeads.Add($item)
                        $newItemsAdded++
                    }
                }

                if ($newItemsAdded -eq 0) {
                    break
                }

                Write-Host "  Loaded page $page ($($catHeads.Count) heads)..." -ForegroundColor DarkCyan

                if ($response.meta.demo_mode -eq $true) {
                    break
                }

                if ($response.meta.pagination) {
                    if ($response.meta.pagination.last_page -and $page -ge $response.meta.pagination.last_page) {
                        break
                    }
                    if ($response.meta.pagination.total_pages -and $page -ge $response.meta.pagination.total_pages) {
                        break
                    }
                }

                $page++
                Start-Sleep -Milliseconds $rateLimitMs
            }

            if ($catHeads.Count -gt 0) {
                $catHeads | ConvertTo-Json -Depth 5 -Compress | Out-File -FilePath $cacheFile -Encoding UTF8
            }

            Start-Sleep -Milliseconds $rateLimitMs
        }

        foreach ($head in $catHeads) {
            $hash = ""
            if ($head.u) {
                $hash = $head.u
            }
            elseif ($head.v) {
                try {
                    $decodedJson = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($head.v)) | ConvertFrom-Json
                    $skinUrl = $decodedJson.textures.SKIN.url
                    if ($skinUrl -match '/texture/([0-9a-fA-F]+)$') {
                        $hash = $Matches[1]
                    }
                }
                catch { }
            }

            if ($hash) {
                $galleryItems.Add([PSCustomObject]@{
                    id  = $globalCounter
                    n   = [string]$head.n
                    h   = [string]$hash
                    cat = [int]$catId
                })
                $globalCounter++
            }
        }
    }

    if ($galleryItems.Count -eq 0) {
        Write-Host "No heads found." -ForegroundColor Yellow
        exit 0
    }

    Write-Host "Building unified HTML gallery with $($galleryItems.Count) total heads..." -ForegroundColor Cyan

    $jsonPayload = $galleryItems | ConvertTo-Json -Depth 4 -Compress
    $catMapJson = $categoryNames | ConvertTo-Json -Compress

    $htmlTemplate = @'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
<meta charset="UTF-8">
<title>MC Heads - Catálogo Completo</title>
<style>
  * { box-sizing: border-box; }
  body { font-family: 'Segoe UI', sans-serif; background: #0d1117; color: #e6edf3; margin: 0; padding: 0; }
  header { position: sticky; top: 0; z-index: 100; background: #161b22; padding: 14px 24px; border-bottom: 1px solid #30363d; display: flex; flex-direction: column; gap: 12px; }
  .top-row, .filter-row { display: flex; flex-wrap: wrap; gap: 10px; align-items: center; justify-content: space-between; }
  .group { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
  input[type="text"], select { background: #0d1117; border: 1px solid #30363d; color: #e6edf3; padding: 8px 12px; border-radius: 6px; font-size: 14px; }
  input[type="text"] { width: 300px; max-width: 100%; }
  input[type="text"]:focus, select:focus { outline: none; border-color: #58a6ff; }
  button { background: #238636; color: #fff; border: none; padding: 8px 14px; border-radius: 6px; font-weight: 600; font-size: 13px; cursor: pointer; transition: 0.15s; }
  button:hover { background: #2ea043; }
  button:disabled { opacity: 0.4; cursor: not-allowed; }
  button.secondary { background: #21262d; border: 1px solid #30363d; color: #c9d1d9; }
  button.secondary:hover:not(:disabled) { background: #30363d; }
  button.active-toggle { background: #1f6feb; border-color: #388bfd; color: #fff; }
  .badge { font-size: 14px; font-weight: bold; color: #3fb950; }
  .hint { font-size: 12px; color: #8b949e; }
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(155px, 1fr)); gap: 14px; padding: 20px 24px; min-height: 60vh; align-items: start; }
  .card { background: #161b22; border: 2px solid #30363d; border-radius: 10px; padding: 12px 10px; text-align: center; cursor: pointer; transition: 0.12s; user-select: none; display: flex; flex-direction: column; align-items: center; justify-content: flex-start; min-height: 150px; }
  .card:hover { border-color: #58a6ff; transform: translateY(-2px); }
  .card.selected { border-color: #3fb950; background: #12261a; box-shadow: 0 0 12px rgba(63,185,80,0.25); }
  canvas { display: block; width: 84px; height: 84px; flex: 0 0 84px; image-rendering: pixelated; margin-bottom: 8px; }
  .name { width: 100%; font-size: 13px; font-weight: 600; word-break: break-word; color: #c9d1d9; line-height: 1.25; }
  .cat-tag { width: 100%; font-size: 11px; color: #8b949e; margin-top: 4px; }
  .pagination { display: flex; justify-content: center; align-items: center; gap: 12px; padding: 16px 24px 28px; }
  .empty { grid-column: 1 / -1; text-align: center; padding: 60px 20px; color: #8b949e; font-size: 16px; }
  footer { text-align: center; padding: 18px; border-top: 1px solid #21262d; color: #8b949e; font-size: 13px; }
  footer a { color: #58a6ff; text-decoration: none; }
</style>
</head>
<body>
<header>
  <div class="top-row">
    <div>
      <strong>MC Heads Full Database</strong> &bull;
      <span class="badge"><span id="selectedCount">0</span> selecionadas</span> &bull;
      <span id="filteredCount">0</span> exibidas de <span id="totalCount">0</span>
    </div>
    <div class="group">
      <button class="secondary" onclick="clearSelection()">Limpar Seleção</button>
      <button class="secondary" onclick="downloadSelected()">Baixar .TXT</button>
      <button onclick="copySelected()">Copiar Comandos</button>
    </div>
  </div>
  <div class="filter-row">
    <div class="group">
      <select id="categorySelect" onchange="applyFilters()">
        <option value="all">Todas as Categorias</option>
      </select>
      <input type="text" id="search" placeholder="Pesquisar (ex: dragon red -blue)...">
      <button class="secondary" id="toggleSelectedBtn" onclick="toggleOnlySelected()">Apenas Selecionadas</button>
      <select id="sortSelect" onchange="applyFilters()">
        <option value="default">Ordem: Padrão</option>
        <option value="az">Nome: A &rarr; Z</option>
        <option value="za">Nome: Z &rarr; A</option>
      </select>
      <select id="pageSizeSelect" onchange="changePageSize()">
        <option value="60">60 / pág</option>
        <option value="120" selected>120 / pág</option>
        <option value="240">240 / pág</option>
        <option value="500">500 / pág</option>
      </select>
    </div>
    <span class="hint">Dica: use espaços para combinar palavras e <code>-palavra</code> para excluir.</span>
  </div>
</header>

<div class="grid" id="grid"></div>

<div class="pagination" id="pagination">
  <button class="secondary" id="prevBtn" onclick="changePage(-1)">&larr; Anterior</button>
  <span id="pageInfo">Página 1 de 1</span>
  <button class="secondary" id="nextBtn" onclick="changePage(1)">Próxima &rarr;</button>
</div>

<footer>
  Custom head textures provided by <a href="https://minecraft-heads.com" target="_blank">Minecraft-Heads.com</a>
</footer>

<script>
const HEADS = __JSON_PAYLOAD__;
const CAT_MAP = __CAT_MAP__;

const selectedIds = new Set();
let filteredHeads = HEADS;
let currentPage = 1;
let pageSize = 120;
let onlySelected = false;

const grid = document.getElementById('grid');
const categorySelect = document.getElementById('categorySelect');
const selectedCountEl = document.getElementById('selectedCount');
const filteredCountEl = document.getElementById('filteredCount');
const totalCountEl = document.getElementById('totalCount');
const pageInfoEl = document.getElementById('pageInfo');
const prevBtn = document.getElementById('prevBtn');
const nextBtn = document.getElementById('nextBtn');

totalCountEl.textContent = HEADS.length.toLocaleString('pt-BR');

const catCounts = {};
for (const h of HEADS) {
  catCounts[h.cat] = (catCounts[h.cat] || 0) + 1;
}
Object.keys(catCounts).sort((a, b) => Number(a) - Number(b)).forEach(catId => {
  const opt = document.createElement('option');
  opt.value = catId;
  const label = CAT_MAP[catId] || `Categoria ${catId}`;
  opt.textContent = `${label} (${catCounts[catId].toLocaleString('pt-BR')})`;
  categorySelect.appendChild(opt);
});

function buildCommand(head) {
  const safeName = head.n.replace(/"/g, '\\"');
  const skinUrl = `https://textures.minecraft.net/texture/${head.h}`;
  const textureValue = btoa(`{"textures":{"SKIN":{"url":"${skinUrl}"}}}`);
  return `/give @p minecraft:player_head[minecraft:custom_name={text:"${safeName}",color:"gold",underlined:true,bold:true,italic:false},minecraft:lore=[{text:"www.minecraft-heads.com",color:"blue",italic:false}],profile={properties:[{name:"textures",value:"${textureValue}"}]}] 1`;
}

function renderIsoHead(canvas, hash) {
  if (!hash) return;
  const ctx = canvas.getContext('2d');
  ctx.imageSmoothingEnabled = false;
  const img = new Image();
  img.crossOrigin = 'Anonymous';
  img.onload = () => {
    ctx.clearRect(0, 0, 96, 96);
    ctx.save();
    ctx.setTransform(1, 0.5, -1, 0.5, 48, 8);
    ctx.drawImage(img, 8, 0, 8, 8, 0, 0, 32, 32);
    ctx.drawImage(img, 40, 0, 8, 8, 0, 0, 32, 32);
    ctx.restore();

    ctx.save();
    ctx.setTransform(1, 0.5, 0, 1.15, 16, 24);
    ctx.drawImage(img, 8, 8, 8, 8, 0, 0, 32, 32);
    ctx.drawImage(img, 40, 8, 8, 8, 0, 0, 32, 32);
    ctx.fillStyle = 'rgba(0,0,0,0.12)';
    ctx.fillRect(0, 0, 32, 32);
    ctx.restore();

    ctx.save();
    ctx.setTransform(1, -0.5, 0, 1.15, 48, 40);
    ctx.drawImage(img, 16, 8, 8, 8, 0, 0, 32, 32);
    ctx.drawImage(img, 48, 8, 8, 8, 0, 0, 32, 32);
    ctx.fillStyle = 'rgba(0,0,0,0.28)';
    ctx.fillRect(0, 0, 32, 32);
    ctx.restore();
  };
  img.src = `https://textures.minecraft.net/texture/${hash}`;
}

function applyFilters() {
  const selectedCat = categorySelect.value;
  const rawQuery = document.getElementById('search').value.trim().toLowerCase();
  const tokens = rawQuery ? rawQuery.split(/\s+/) : [];
  const includeTerms = tokens.filter(t => !t.startsWith('-') && t.length > 0);
  const excludeTerms = tokens.filter(t => t.startsWith('-') && t.length > 1).map(t => t.slice(1));

  filteredHeads = HEADS.filter(h => {
    if (selectedCat !== 'all' && String(h.cat) !== selectedCat) return false;
    if (onlySelected && !selectedIds.has(h.id)) return false;
    if (tokens.length === 0) return true;
    const lowerName = h.n.toLowerCase();
    for (const term of includeTerms) {
      if (!lowerName.includes(term)) return false;
    }
    for (const term of excludeTerms) {
      if (lowerName.includes(term)) return false;
    }
    return true;
  });

  const sortMode = document.getElementById('sortSelect').value;
  if (sortMode === 'az') {
    filteredHeads = [...filteredHeads].sort((a, b) => a.n.localeCompare(b.n));
  } else if (sortMode === 'za') {
    filteredHeads = [...filteredHeads].sort((a, b) => b.n.localeCompare(a.n));
  }

  currentPage = 1;
  renderPage();
}

function renderPage() {
  grid.innerHTML = '';
  filteredCountEl.textContent = filteredHeads.length.toLocaleString('pt-BR');

  const totalPages = Math.max(1, Math.ceil(filteredHeads.length / pageSize));
  if (currentPage > totalPages) currentPage = totalPages;

  pageInfoEl.textContent = `Página ${currentPage} de ${totalPages}`;
  prevBtn.disabled = currentPage <= 1;
  nextBtn.disabled = currentPage >= totalPages;

  if (filteredHeads.length === 0) {
    grid.innerHTML = '<div class="empty">Nenhuma cabeça encontrada com os filtros atuais.</div>';
    return;
  }

  const start = (currentPage - 1) * pageSize;
  const pageItems = filteredHeads.slice(start, start + pageSize);
  const fragment = document.createDocumentFragment();

  pageItems.forEach(head => {
    const card = document.createElement('div');
    card.className = 'card' + (selectedIds.has(head.id) ? ' selected' : '');

    const canvas = document.createElement('canvas');
    canvas.width = 96;
    canvas.height = 96;
    renderIsoHead(canvas, head.h);

    const label = document.createElement('div');
    label.className = 'name';
    label.textContent = head.n;

    const catTag = document.createElement('div');
    catTag.className = 'cat-tag';
    catTag.textContent = CAT_MAP[head.cat] || `Cat. ${head.cat}`;

    card.appendChild(canvas);
    card.appendChild(label);
    card.appendChild(catTag);

    card.onclick = () => {
      if (selectedIds.has(head.id)) {
        selectedIds.delete(head.id);
        card.classList.remove('selected');
        if (onlySelected) applyFilters();
      } else {
        selectedIds.add(head.id);
        card.classList.add('selected');
      }
      selectedCountEl.textContent = selectedIds.size;
    };
    fragment.appendChild(card);
  });

  grid.appendChild(fragment);
}

function changePage(delta) {
  currentPage += delta;
  renderPage();
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

function changePageSize() {
  pageSize = parseInt(document.getElementById('pageSizeSelect').value, 10);
  currentPage = 1;
  renderPage();
}

function toggleOnlySelected() {
  onlySelected = !onlySelected;
  document.getElementById('toggleSelectedBtn').classList.toggle('active-toggle', onlySelected);
  applyFilters();
}

function getSelectedText() {
  const chosen = HEADS.filter(h => selectedIds.has(h.id));
  if (chosen.length === 0) return '';
  return chosen.map((h, i) => `### ${i + 1}. ${h.n} (${CAT_MAP[h.cat] || 'Cat ' + h.cat})\n${buildCommand(h)}\n`).join('\n');
}

function copySelected() {
  const text = getSelectedText();
  if (!text) { alert('Selecione pelo menos uma cabeça primeiro!'); return; }
  navigator.clipboard.writeText(text).then(() => {
    alert(`${selectedIds.size} comandos copiados para a área de transferência!`);
  });
}

function downloadSelected() {
  const text = getSelectedText();
  if (!text) { alert('Selecione pelo menos uma cabeça primeiro!'); return; }
  const blob = new Blob([text], { type: 'text/plain;charset=utf-8' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = 'mc_heads_selected.txt';
  a.click();
}

function clearSelection() {
  selectedIds.clear();
  selectedCountEl.textContent = 0;
  if (onlySelected) {
    applyFilters();
  } else {
    renderPage();
  }
}

let searchTimeout;
document.getElementById('search').addEventListener('input', () => {
  clearTimeout(searchTimeout);
  searchTimeout = setTimeout(applyFilters, 180);
});

applyFilters();
</script>
</body>
</html>
'@

    $finalHtml = $htmlTemplate.Replace('__JSON_PAYLOAD__', $jsonPayload).Replace('__CAT_MAP__', $catMapJson)
    [System.IO.File]::WriteAllText($OutputPath, $finalHtml, [System.Text.UTF8Encoding]::new($false))

    Write-Host "Success! Full visual gallery with $($galleryItems.Count) heads saved to: $OutputPath" -ForegroundColor Green
    Start-Process $OutputPath
}
catch {
    Write-Host "API Request Error: $_" -ForegroundColor Red
}
