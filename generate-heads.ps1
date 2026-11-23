<#
.SYNOPSIS
    Minecraft Custom Heads /give Command Generator (API v2)
.DESCRIPTION
    Fetches custom head textures from Minecraft-Heads.com API v2 with local 24-hour caching,
    strict input validation, and built-in request rate-limiting. Filters out duplicate variations
    and exports ready-to-use Minecraft Java 1.21.5+ /give commands to a text file.
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$AppUuid,

    [Parameter(Mandatory = $false)]
    [ValidateLength(8, 256)]
    [string]$ApiKey,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 1000)]
    [int]$CategoryId = 1,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 5000)]
    [int]$Amount = 50,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 168)]
    [int]$CacheHours = 24,

    [Parameter(Mandatory = $false)]
    [switch]$ForceRefresh,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "$env:USERPROFILE\Downloads\mc_heads_cat$CategoryId.txt"
)

# Input validation to prevent invalid or placeholder API calls
if ([string]::IsNullOrWhiteSpace($AppUuid) -or [string]::IsNullOrWhiteSpace($ApiKey)) {
    Write-Host "Error: You must provide both -AppUuid and -ApiKey parameters." -ForegroundColor Red
    Write-Host "Example: .\generate-heads.ps1 -AppUuid 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' -ApiKey 'your-key' -CategoryId 1 -Amount 50" -ForegroundColor Yellow
    exit 1
}

if ($ApiKey -match 'YOUR-API-KEY') {
    Write-Host "Error: Replace the placeholder with your real Minecraft-Heads API key." -ForegroundColor Red
    exit 1
}

# Local cache setup (stored in system temp folder, never embedded in the repository)
$cacheDir = Join-Path $env:TEMP "mc-heads-api-cache"
if (-not (Test-Path $cacheDir)) {
    New-Item -ItemType Directory -Path $cacheDir | Out-Null
}
$cacheFile = Join-Path $cacheDir "category_$CategoryId.json"

$allHeads = @()
$useCache = $false

if (-not $ForceRefresh -and (Test-Path $cacheFile)) {
    $cacheAge = (Get-Date) - (Get-Item $cacheFile).LastWriteTime
    if ($cacheAge.TotalHours -lt $CacheHours) {
        $useCache = $true
    }
}

try {
    if ($useCache) {
        Write-Host "Using local cache for Category ID $CategoryId (updated $([Math]::Round($cacheAge.TotalHours, 1))h ago)..." -ForegroundColor Green
        $cachedContent = Get-Content -Path $cacheFile -Raw -Encoding utf8
        $allHeads = @($cachedContent | ConvertFrom-Json)
    }
    else {
        Write-Host "Fetching custom heads from Minecraft-Heads.com API v2 (Category ID: $CategoryId)..." -ForegroundColor Cyan
        $headers = @{ "api-key" = $ApiKey }
        $page = 1
        $maxPages = 20
        $rateLimitMs = 1500

        while ($page -le $maxPages) {
            $url = "https://minecraft-heads.com/api/heads/custom-heads?app_uuid=$AppUuid&category_id=$CategoryId&page=$page&value=true"
            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get

            if (-not $response.data -or $response.data.Count -eq 0) {
                break
            }

            $allHeads += @($response.data)
            Write-Host "Loaded page $page ($($allHeads.Count) heads fetched so far)..." -ForegroundColor DarkCyan

            if ($response.meta.demo_mode -eq $true -or $response.data.Count -lt 100) {
                break
            }

            $page++
            # Rate-limiting delay between paginated requests to protect server resources
            Start-Sleep -Milliseconds $rateLimitMs
        }

        if ($allHeads.Count -gt 0) {
            $allHeads | ConvertTo-Json -Depth 5 -Compress | Out-File -FilePath $cacheFile -Encoding utf8
            Write-Host "Cached $($allHeads.Count) heads locally for $CacheHours hours at: $cacheFile" -ForegroundColor DarkGray
        }
    }

    # Filter out redundant variations (parentheses and trailing numbers/roman numerals)
    $seen = [System.Collections.Generic.HashSet[string]]::new()
    $uniqueHeads = @(foreach ($head in $allHeads) {
        $baseName = ($head.n -replace '\s*\(.*?\)', '' -replace '\s+(I|II|III|IV|V|VI|VII|VIII|IX|X|\d+)$', '').Trim().ToLower()
        if ($seen.Add($baseName)) {
            $head
        }
    })

    $availableCount = $uniqueHeads.Count
    if ($availableCount -eq 0) {
        Write-Host "No heads found for this category." -ForegroundColor Yellow
        exit 0
    }

    $finalCount = [Math]::Min($Amount, $availableCount)
    $selectedHeads = @($uniqueHeads | Get-Random -Count $finalCount)

    $outputLines = @()
    $counter = 1

    foreach ($head in $selectedHeads) {
        $safeName = $head.n -replace '"', '\"'

        if ($head.v) {
            $textureValue = $head.v
        }
        else {
            $textureJson = "{`"textures`":{`"SKIN`":{`"url`":`"https://textures.minecraft.net/texture/$($head.u)`"}}}"
            $textureValue = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($textureJson))
        }

        $command = "/give @p minecraft:player_head[minecraft:custom_name={text:`"$safeName`",color:`"gold`",underlined:true,bold:true,italic:false},minecraft:lore=[{text:`"www.minecraft-heads.com`",color:`"blue`",italic:false}],profile={properties:[{name:`"textures`",value:`"$textureValue`"}]}] 1"

        $outputLines += "### $counter. $($head.n)"
        $outputLines += $command
        $outputLines += ""
        $counter++
    }

    $outputLines | Out-File -FilePath $OutputPath -Encoding utf8
    Write-Host "Success! Saved $finalCount unique commands (from $availableCount available) to: $OutputPath" -ForegroundColor Green
}
catch {
    Write-Host "API Request Error: $_" -ForegroundColor Red
}
