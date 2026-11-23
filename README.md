# MC Heads Command Generator

A lightweight PowerShell utility for Minecraft mapmakers and builders to batch-generate `/give` commands (Minecraft Java Edition 1.21.5+) for decorative custom heads using the **Minecraft-Heads.com API v2**.

## Features
- Connects directly to the official Minecraft-Heads API v2 (`/api/heads/custom-heads`)
- Supports automatic pagination across large categories
- Deduplicates minor color/numbered variations to provide a clean, diverse selection
- Exports ready-to-paste Command Block `/give` commands into a `.txt` file

## Usage
1. Register an application and obtain your **API Key** and **App UUID** at [Minecraft-Heads.com](https://minecraft-heads.com).
2. Run the script in Windows PowerShell:
```powershell
.\generate-heads.ps1 -AppUuid "YOUR-APP-UUID" -ApiKey "YOUR-API-KEY" -CategoryId 1 -Amount 50
```

## Credits & Data Source
All custom head textures and metadata are provided by **Minecraft-Heads.com**.

<a href="https://minecraft-heads.com" target="_blank">
  <img src="./minecraft-heads.webp" alt="Minecraft-Heads.com">
</a>
