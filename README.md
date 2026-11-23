# MC Heads Command Generator

A lightweight PowerShell utility for Minecraft mapmakers and builders to batch-generate `/give` commands (Minecraft Java Edition 1.21.5+) for decorative custom heads using the **Minecraft-Heads.com API v2**. Featuring local 24h response caching, strict input validation, and pagination rate-limiting.

## Features
- Connects directly to the official Minecraft-Heads API v2 (`/api/heads/custom-heads`)
- Supports automatic pagination across large categories
- Deduplicates minor color/numbered variations to provide a clean, diverse selection
- Exports ready-to-paste Command Block `/give` commands into a `.txt` file

## Tutorial (How to Use)

### 1. Get your credentials
Register an application and obtain your **API Key** and **App UUID** at [Minecraft-Heads.com](https://minecraft-heads.com).

### 2. Download the script
Download the `generate-heads.ps1` file from this repository and save it to a folder on your computer (for example, your `Downloads` folder).

### 3. Open Windows PowerShell
Press the **Windows** key, type `PowerShell`, open **Windows PowerShell**, and navigate to the folder where you saved the script:

```powershell
cd "$env:USERPROFILE\Downloads"
```

### 4. Run the script with your parameters
Execute the command below, replacing the placeholder values with your own `AppUuid`, `ApiKey`, desired `CategoryId`, and `Amount`:

```powershell
powershell -ExecutionPolicy Bypass -File .\generate-heads.ps1 -AppUuid "YOUR-APP-UUID" -ApiKey "YOUR-API-KEY" -CategoryId 1 -Amount 50
```

> **Note:** Using `-ExecutionPolicy Bypass` allows Windows to run the local script without changing your system's global security settings.

### Available Parameters

| Parameter | Required | Default | Description |
| :--- | :---: | :--- | :--- |
| `-AppUuid` | Yes | — | Your registered Minecraft-Heads App UUID |
| `-ApiKey` | Yes | — | Your personal Minecraft-Heads API v2 Key |
| `-CategoryId` | No | `1` | Numeric ID of the head category to fetch |
| `-Amount` | No | `50` | Number of unique heads to export |
| `-CacheHours` | No | `24` | Hours to keep the local cache before querying the API again |
| `-ForceRefresh` | No | `false` | Ignores the local cache and fetches fresh data from the API |
| `-OutputPath` | No | `Downloads\mc_heads_cat<ID>.txt` | Custom file path for the generated `.txt` file |

### 5. Use the commands in Minecraft
1. Open the generated `.txt` file inside your `Downloads` folder.
2. Copy any `/give` command line.
3. In Minecraft Java Edition (1.21.5+), paste the command into a **Command Block** and activate it with a button or lever.

## Credits & Data Source
All custom head textures and metadata are provided by **Minecraft-Heads.com**.

<a href="https://minecraft-heads.com" target="_blank">
  <img src="./minecraft-heads.webp" alt="Minecraft-Heads.com">
</a>
