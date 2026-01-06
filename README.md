# 🗡️ Dark Mists Item Tracker

A **Mudlet addon + web item browser** for the Dark Mists MUD.

This project provides:

- **In-game clickable item identification** via Mudlet
- **Cursor-anchored tooltips** with full item details
- **Fast item lookup command**
- **Standalone HTML item viewer** for filtering, sorting, and browsing item data offline

Designed to be:
- Lightweight
- Non-intrusive
- Safe against false matches (no more `egg` inside `leggings`)
- Easy to customize

---

## ✨ Features

### In-Game (Mudlet)
- Detects item names **only at the end of output lines**
- Clickable item links in normal MUD output
- Tooltip popup near your cursor
- Shift+Click to print full item details to chat
- Supports duplicate item names
- Automatically sizes tooltips to content
- Fully configurable colors, fonts, and layout

### Web Viewer (HTML)
- Load the same item JSON file used by Mudlet
- Powerful text search across item stats and descriptions
- Advanced filters:
  - Area
  - Weapon type & damage
  - Wear slot
  - Item level
  - Flags & materials
- Sortable columns
- Dark / Light theme toggle
- No server required — runs locally in your browser

---

## 📁 Repository Contents

```
├── item_tracker.lua        # Mudlet addon
├── darkmists_items.json    # Item database (shared)
├── index.html              # Standalone item viewer
└── README.md
```

---

## 🧩 Mudlet Installation

1. **Copy files**
   - Download the [Latest Item Tracker Files](https://github.com/mudzereli/DM-Item-Tracker-Releases/archive/refs/tags/Latest.zip)
   - Copy the `DM-Item-Tracker-Releases-Latest` folder (and its contents) into your Mudlet Profile directory
     - Example: `C:\Users\<your_username>\.config\mudlet\profiles\<your_mudlet_profile_name>\`

2. **Load the script**
   - Create a new Trigger `Triggers > Add Trigger`
     - Name = `dmid newline`
     - Line 1 (Text to find) = `^(.*)$`
     - Line 1 Type (Far Right - change from substring) = `perl regex`
     - Lua Code = `if ItemTracker and ItemTracker.renderLineWithLinks then ItemTracker.renderLineWithLinks(matches[2]) end`
   - Create a new Lua script `Scripts > Add Script` in Mudlet and Either:
     - (Preferred) `dofile()` it from an existing script: `dofile(getMudletHomeDir() .. "/DM-Item-Tracker-Releases-Latest/item_tracker.lua" )` or
     - (Not Preferred) paste everything from `item_tracker.lua` in there

3. **Reload Mudlet**
   - You should see:
     ```
     [ID] Loading DM Item Tracker v1.0.0 by mudzereli
     [ID] Loaded XXXX items
     ```

---

## 🎮 In-Game Usage

### Command
```
dmid <item name or partial>
```

(The alias can be changed in `ItemTracker.settings.alias`.)

### Examples
```
dmid bracelet
dmid an oversized lumber axe
```

### Mouse Interaction
- **Click item name** → show tooltip near cursor
- **Shift + Click** → print full item details to chat
- **Click anywhere else** → close tooltip

### Detection Rules
- Only matches item names at the **end of a line**
- Longest names are matched first
- Prevents accidental matches like:
  - ❌ `egg` in `leggings`

---

## 🧠 Tooltip Design

Tooltips are composed of:
- Optional header (larger font item name)
- Scroll-free content window
- Pixel-perfect border using layered miniconsoles

All sizing and positioning:
- Anchors to cursor
- Flips above cursor if it would go off-screen
- Clamps safely inside the main Mudlet window

---

## ⚙️ Configuration

All customization lives in:

```lua
ItemTracker.settings
```

You can change:
- Fonts & font sizes
- Colors (text, background, border)
- Tooltip width limits
- Cursor offset
- Screen margins
- Alias command name

No code edits required beyond settings.

---

## 🌐 HTML Item Viewer

The `index.html` file is a **standalone item browser**.

### How to Use
1. Open `index.html` in any modern browser
2. Click **Load JSON**
3. Select `darkmists_items.json`

### Why It Exists
- Compare items
- Explore stats on items easier in-game and out-of-game
- Find upgrades faster
- Filter large item pools efficiently

No backend, no tracking, no uploads.

---

## ⚠️ Notes & Limitations

- This addon **does not modify gameplay**
- It only reads output already sent by the MUD
- Tooltip borders are implemented using nested miniconsoles (by design)
- Item data quality depends entirely on the JSON source

---

## 🛠️ Development Notes

- Written for Mudlet Lua
- No external dependencies
- Web viewer uses Bootstrap 5 (CDN)
- Designed to be forked and customized

---

## ❤️ Credits

- **Author:** mudzereli  
- **MUD:** Dark Mists  
- **Client:** Mudlet  
