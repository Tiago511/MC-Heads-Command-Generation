<#
.SYNOPSIS
    Minecraft Custom Heads /give Command Generator (API v2)
.DESCRIPTION
    Fetches custom head textures from Minecraft-Heads.com API v2, filters out duplicate variations,
    shuffles the selection, and exports ready-to-use Minecraft Java 1.21.5+ /give commands to a text file.
#>

param(
    [string]$AppUuid = "YOUR-APP-UUID-HERE",
    [string]$ApiKey = "YOUR-API-KEY-HERE",
    [int]$CategoryId = 1,
    [int]$Amount = 50,
    [string]$OutputPath = "$env:USERPROFILE\Downloads\mc_heads_cat$CategoryId.txt"
)

$headers = @{ "api-key" = $ApiKey }
Write-Host "Fetching custom heads from Minecraft-Heads.com API v2 (Category ID: $CategoryId)..." -ForegroundColor Cyan

try {
    $allHeads = @()
    $page = 1

    while ($true) {
        $url = "https://minecraft-heads.com/api/heads/custom-heads?app_uuid=$AppUuid&category_id=$CategoryId&page=$page&value=true"
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get

        if (-not $response.data -or $response.data.Count -eq 0) {
            break
        }

        $allHeads += $response.data
        Write-Host "Loaded page $page ($($allHeads.Count) heads fetched so far)..." -ForegroundColor DarkCyan

        if ($response.meta.demo_mode -eq $true -or $response.data.Count -lt 100) {
            break
        }

        $page++
    }

    # Filter out redundant variations (parentheses and trailing numbers/roman numerals)
    $seen = [System.Collections.Generic.HashSet[string]]::new()
    $uniqueHeads = foreach ($head in $allHeads) {
        $baseName = ($head.n -replace '\s*\(.*?\)', '' -replace '\s+(I|II|III|IV|V|VI|VII|VIII|IX|X|\d+)$', '').Trim().ToLower()
        if ($seen.Add($baseName)) {
            $head
        }
    }

    $availableCount = $uniqueHeads.Count
    if ($availableCount -eq 0) {
        Write-Host "No heads found for this category." -ForegroundColor Yellow
        exit
    }

    $finalCount = [Math]::Min($Amount, $availableCount)
    $selectedHeads = $uniqueHeads | Get-Random -Count $finalCount

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
