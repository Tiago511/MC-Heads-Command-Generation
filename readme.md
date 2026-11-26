# MC Heads Visual Gallery & Command Generator

A lightweight PowerShell utility for Minecraft mapmakers and builders to fetch the entire custom heads database (all 11 categories) from the **Minecraft-Heads.com API v2** and generate a standalone, high-performance **local HTML visual gallery**. Preview 3D isometric head renders, filter by category or keywords, select your favorite heads, and batch-export ready-to-paste `/give` commands for **Minecraft Java Edition 1.21.5+**.

## Features
- **Full Database Support:** Fetches all 11 official categories (`Alphabet`, `Animals`, `Blocks`, `Decoration`, `Food & Drinks`, `Humans`, `Humanoids`, `Miscellaneous`, `Monsters`, `Plants`, and `Helmets`) into a single unified gallery
- **Interactive 3D Visual Selector:** Renders isometric 3D head previews directly in your browser using Mojang's official texture servers (`textures.minecraft.net`)
- **High-Performance Local HTML:** Handles tens of thousands of heads smoothly with client-side pagination, sorting (`Default`, `A → Z`, `Z → A`), and instant filtering
- **Advanced Search:** Combine multiple keywords (`dragon red`) or exclude terms using `-` (`book -enchanted`)
- **API-Compliant Caching:** Local 24-hour JSON caching per category, strict input validation, and built-in pagination rate-limiting
- **Flexible Export:** Copy selected `/give` commands directly to your clipboard or download them as a clean `.txt` file

## Tutorial (How to Use)

### 1. Get your credentials
Register an application and obtain your **API Key** and **App UUID** at [Minecraft-Heads.com](https://minecraft-heads.com).

### 2. Download the script
Download the `generate-all-heads.ps1` file from this repository and save it to a folder on your computer (for example, your `Downloads` folder).

### 3. Open Windows PowerShell
Press the **Windows** key, type `PowerShell`, open **Windows PowerShell**, and navigate to the folder where you saved the script:

```powershell
cd "$env:USERPROFILE\Downloads"
```

### 4. Generate the Visual Gallery
Run the command below, replacing the placeholder values with your own `AppUuid` and `ApiKey`:

```powershell
powershell -ExecutionPolicy Bypass -File .\generate-all-heads.ps1 -AppUuid "YOUR-APP-UUID" -ApiKey "YOUR-API-KEY"
```

> **Note:** Using `-ExecutionPolicy Bypass` allows Windows to run the local script without changing your system's global security settings. Once finished, the script saves `mc_heads_full_gallery.html` in your `Downloads` folder and opens it automatically in your default browser.

#### Optional Examples
* **Fetch only specific categories** (e.g., `4` Decoration and `11` Helmets):
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\generate-all-heads.ps1 -AppUuid "YOUR-APP-UUID" -ApiKey "YOUR-API-KEY" -Categories 4,11
  ```
* **Force a fresh API update** (ignoring the 24-hour local cache):
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\generate-all-heads.ps1 -AppUuid "YOUR-APP-UUID" -ApiKey "YOUR-API-KEY" -ForceRefresh
  ```

### Available Parameters

| Parameter | Required | Default | Description |
| :--- | :---: | :--- | :--- |
| `-AppUuid` | Yes | — | Your registered Minecraft-Heads App UUID |
| `-ApiKey` | Yes | — | Your personal Minecraft-Heads API v2 Key |
| `-Categories` | No | `1..11` | Comma-separated list of category IDs to fetch (all 11 by default) |
| `-CacheHours` | No | `24` | Hours to keep the local category cache before querying the API again |
| `-ForceRefresh` | No | `false` | Ignores the local cache and fetches fresh data from the API |
| `-OutputPath` | No | `Downloads\mc_heads_full_gallery.html` | Custom file path for the generated `.html` gallery |

### Category IDs Reference

| ID | Category | ID | Category |
| :---: | :--- | :---: | :--- |
| `1` | Alphabet | `7` | Humanoids |
| `2` | Animals | `8` | Miscellaneous |
| `3` | Blocks | `9` | Monsters |
| `4` | Decoration | `10` | Plants |
| `5` | Food & Drinks | `11` | Helmets |
| `6` | Humans | | |

### 5. Select Heads & Use Commands in Minecraft
1. In the generated `mc_heads_full_gallery.html` page, filter by **Category** or use the **Search** bar to find the heads you want.
2. Click on any head card to select it (highlighted with a green border). You can use **Apenas Selecionadas** (*Selected Only*) at any time to review your picks.
3. Click **Copiar Comandos** (*Copy Commands*) to copy all selected `/give` commands to your clipboard, or **Baixar .TXT** (*Download .TXT*) to save them as a text file.
4. In **Minecraft Java Edition (1.21.5+)**, paste any command into a **Command Block** and activate it with a button or lever.

## Credits & Data Source
All custom head textures and metadata are provided by **Minecraft-Heads.com**.

<a href="https://minecraft-heads.com" target="_blank">
  <img src="./minecraft-heads.webp" alt="Minecraft-Heads.com">
</a>