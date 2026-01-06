-- ============================================================================
-- ItemTracker
-- ----------------------------------------------------------------------------
-- Clickable item identification with tooltip support.
-- Loads item data from JSON and detects item names at the END of output lines.
--
-- Key behaviors (do not change unless you mean to):
--   • Items are indexed by lowercase name (duplicates stored as a list)
--   • Matching is END-OF-LINE only (prevents "egg" in "leggings" problems)
--   • Longest names are tried first (prevents partial shadowing)
--   • Normal click -> tooltip
--   • Shift+click -> full output in main window
--   • Any mouse click anywhere -> hides tooltip
-- ============================================================================

ItemTracker = {
  name = "DM Item Tracker",
  version = "1.0.1",
  author = "mudzereli",

  -- -------------------------------------------------------------------------
  -- Runtime item data
  -- -------------------------------------------------------------------------
  items = {},            -- flat list of all items
  by_name = {},          -- lower(name) -> { item, item, ... }
  sorted_names = {},     -- lowercase names, longest-first

  -- -------------------------------------------------------------------------
  -- User / UI configuration (tweak freely)
  -- -------------------------------------------------------------------------
  settings = {
    alias              = "dmid",
    
    tooltipHeaderFontSize = 14,
    tooltipFontSize       = 12,

    tooltipMinChars    = 30,
    tooltipMaxChars    = 90,

    tooltipBorderSize  = 2,     -- total border size (px)

    cursorOffset       = 15,    -- distance from mouse cursor
    screenMargin       = 10,    -- clamp margin from screen edges

    wrapWidth          = 400,   -- setWindowWrap width

    -- Tooltip Color Scheme
    tooltipHeaderBGColor    = {255, 255, 255, 255}, -- RGBA
    tooltipTextColor        = {255, 255, 255, 255}, -- RGBA (Alpha not actually used in FG Color)
    tooltipBGColor          = {000, 000, 000, 255}, -- RGBA
    tooltipBorderColor      = {255, 255, 255, 255}, -- RGBA

    -- MUD Color Scheme
    -- Colors Found Online Here: https://wiki.mudlet.org/images/c/c3/ShowColors.png
    -- Or In Mudlet By Typing:   lua showColors(3)
    itemLinkColor           = "light_goldenrod",
    tooltipItemNameColor    = "black",
    tooltipItemDetailsColor = "white"
  },

  -- -------------------------------------------------------------------------
  -- Tooltip runtime state (do not edit manually)
  -- -------------------------------------------------------------------------
  tooltip = {
    win    = nil,
    border = nil,
    width  = 0,
    height = 0,
  },
}
ItemTracker.settings.itemLinkColor = string.format("<%s>",ItemTracker.settings.itemLinkColor)
ItemTracker.settings.tooltipItemNameColor = string.format("<%s>",ItemTracker.settings.tooltipItemNameColor)
ItemTracker.settings.tooltipItemDetailsColor = string.format("<%s>",ItemTracker.settings.tooltipItemDetailsColor)

-- ============================================================================
-- Local helpers (pure functions only)
-- ============================================================================

local function trim(s)
  return s:gsub("^%s+", ""):gsub("%s+$", "")
end

local function is_valid_item_name(name)
  if type(name) ~= "string" then return false end
  name = trim(name)
  return #name >= 2 and name:match("%a") ~= nil
end

-- Compute tooltip size from plain text lines
local function tooltipSizeFromText(lines, fontSize, minChars, maxChars)
  local longest = minChars

  for _, line in ipairs(lines) do
    longest = math.max(longest, #line)
  end

  if maxChars then
    longest = math.min(longest, maxChars)
  end

  local charW, charH = calcFontSize(fontSize)
  return longest * charW, #lines * charH
end

-- ============================================================================
-- Tooltip lifecycle
-- ============================================================================

function ItemTracker.initTooltip()
  if ItemTracker.tooltip.win then return end

  local s = ItemTracker.settings

  local border = "itemTooltipBorder"
  local inner  = "itemTooltip"
  local header = "itemTooltipHeader"

  createMiniConsole(border, 0, 0, 1, 1)
  setBackgroundColor(border, s.tooltipBorderColor[1], s.tooltipBorderColor[2], s.tooltipBorderColor[3], s.tooltipBorderColor[4])
  hideWindow(border)

  createMiniConsole(header, 0, 0, 1, 1)
  setMiniConsoleFontSize(header, s.tooltipHeaderFontSize)
  setBackgroundColor(
    header,
    s.tooltipHeaderBGColor[1],
    s.tooltipHeaderBGColor[2],
    s.tooltipHeaderBGColor[3],
    s.tooltipHeaderBGColor[4]
  )
  setFgColor(header,255,255,255)
  hideWindow(header)

  createMiniConsole(inner, s.tooltipBorderSize, s.tooltipBorderSize, 1, 1)
  setMiniConsoleFontSize(inner, s.tooltipFontSize)
  setBackgroundColor(inner, s.tooltipBGColor[1], s.tooltipBGColor[2], s.tooltipBGColor[3], s.tooltipBGColor[4])
  setFgColor(inner, s.tooltipTextColor[1], s.tooltipTextColor[2], s.tooltipTextColor[3])
  setWindowWrap(inner, s.wrapWidth)
  hideWindow(inner)

  ItemTracker.tooltip.border = border
  ItemTracker.tooltip.header = header
  ItemTracker.tooltip.win    = inner
end

function ItemTracker.hideTooltip()
  if ItemTracker.tooltip.win then
    hideWindow(ItemTracker.tooltip.header)
    hideWindow(ItemTracker.tooltip.win)
    hideWindow(ItemTracker.tooltip.border)
  end
end

-- ============================================================================
-- Data loading / indexing
-- ============================================================================

function ItemTracker.load(path)
  cecho(string.format(
    "<green>[ID] <white>Loading %s v%s by %s\n",
    ItemTracker.name,
    ItemTracker.version,
    ItemTracker.author
  ))

  local f, err = io.open(path, "r")
  if not f then
    cecho("<red>[ID] Failed to open JSON: " .. tostring(err) .. "\n")
    return false
  end

  local data = yajl.to_value(f:read("*a"))
  f:close()

  if type(data) ~= "table" then
    cecho("<red>[ID] JSON root is not a list\n")
    return false
  end

  -- Reset runtime indices
  ItemTracker.items = {}
  ItemTracker.by_name = {}
  ItemTracker.sorted_names = {}

  local dropped = 0

  for _, item in ipairs(data) do
    if is_valid_item_name(item.name) then
      item.name = trim(item.name)
      local key = item.name:lower()

      ItemTracker.items[#ItemTracker.items + 1] = item
      ItemTracker.by_name[key] = ItemTracker.by_name[key] or {}
      table.insert(ItemTracker.by_name[key], item)
      table.insert(ItemTracker.sorted_names, key)
    else
      dropped = dropped + 1
    end
  end

  -- Longest names first to prevent partial shadowing
  table.sort(ItemTracker.sorted_names, function(a, b)
    return #a > #b
  end)

  cecho(string.format(
    "<green>[ID]<white> Loaded %d items (%d dropped)\n",
    #ItemTracker.items, dropped
  ))

  return true
end

-- ============================================================================
-- Searching / matching
-- ============================================================================

function ItemTracker.find(query)
  if not query or query == "" then return nil end
  query = query:lower()

  -- 1) Exact match
  local exact = ItemTracker.by_name[query]
  if exact then return exact end

  -- 2) Partial matches (search across keys, returning item objects)
  local hits = {}
  for name, list in pairs(ItemTracker.by_name) do
    if name:find(query, 1, true) then
      for _, item in ipairs(list) do
        hits[#hits + 1] = item
      end
    end
  end

  table.sort(hits, function(a, b) return a.name < b.name end)
  return hits
end

-- Detect an item name that appears exactly at the END of a line.
-- Returns: normalized name, start index, end index (in the trimmed-lower string)
function ItemTracker.findFirstItemInLine(line)
  local lower = line:lower():gsub("%s+$", "")

  for _, name in ipairs(ItemTracker.sorted_names) do
    local nlen = #name
    if nlen <= #lower and lower:sub(-nlen) == name then
      local s = #lower - nlen + 1
      return name, s, #lower
    end
  end

  return nil
end

-- ============================================================================
-- Line rendering
-- ============================================================================

function ItemTracker.renderLineWithLinks(line)
  -- Ignore prompts / exits lines
  if line:match("^<%d") then return false end
  if line:find("^%[Exits:") then return false end

  local _, s, e = ItemTracker.findFirstItemInLine(line)
  if not s then return false end

  -- Select the original item substring in the CURRENT line buffer
  selectCurrentLine()
  local itemText = line:sub(s, e)
  if not selectString(itemText, 1) then
    resetFormat()
    return false
  end

  -- Remove item text, preserving existing colors on the line
  replace("", true)

  -- Insert clickable link in its place
  cechoLink(
    ItemTracker.settings.itemLinkColor .. itemText .. "<white>",
    function() ItemTracker.handleClick(itemText) end,
    "Click: tooltip | Shift+Click: full identify",
    true
  )

  resetFormat()
  return true
end

-- ============================================================================
-- Output display
-- ============================================================================

function ItemTracker.show(item)
  cecho("\n"..ItemTracker.settings.itemLinkColor.."===[ " .. item.name .. " ]===<white>\n")

  if item.details then
    for line in item.details:gmatch("[^\n]+") do
      cecho("<white>" .. line .. "\n")
    end
  else
    cecho("<grey>(no details)<white>\n")
  end

  cecho(ItemTracker.settings.itemLinkColor.."===[ " .. item.name .. " ]===<white>\n\n")
end

-- Print ALL items matching the exact name (handles duplicates)
function ItemTracker.click(name)
  local list = ItemTracker.by_name[name:lower()]
  if not list then return end
  for _, item in ipairs(list) do
    ItemTracker.show(item)
  end
end

-- ============================================================================
-- Tooltip rendering
-- ============================================================================

function ItemTracker.showTooltip(name)
  local list = ItemTracker.by_name[name:lower()]
  if not list then return end

  local s = ItemTracker.settings
  local t = ItemTracker.tooltip
  local _, headerCharH = calcFontSize(s.tooltipHeaderFontSize)
  
  local headerHeight = headerCharH

  local preview = {}
  for idx, item in ipairs(list) do
    if item.details then
      for line in item.details:gmatch("[^\n]+") do
        preview[#preview + 1] = line
      end
    end
    if idx < #list then
      preview[#preview+1] = "\n"
    end
  end

  local w, h = tooltipSizeFromText(
    preview,
    s.tooltipFontSize,
    s.tooltipMinChars,
    s.tooltipMaxChars
  )
  -- Combine header + content + border into final tooltip size
  local contentW, contentH = w, h
  
  local totalWidth =
    contentW + (s.tooltipBorderSize * 2)
  
  local totalHeight =
    headerHeight +
    contentH +
    (s.tooltipBorderSize * 2)
  
  resizeWindow(t.border, totalWidth, totalHeight)
  resizeWindow(t.header, contentW, headerHeight)
  resizeWindow(t.win, contentW, contentH)
  
  t.width  = totalWidth
  t.height = totalHeight
  
  clearWindow(t.win)
  
  for idx, item in ipairs(list) do
    clearWindow(t.header)
    cecho(
        t.header,
        s.tooltipItemNameColor .. item.name
    )
    if item.details then
      cecho(
        t.win, 
        s.tooltipItemDetailsColor .. item.details .. "\n")
    end
    if idx < #list then
      cecho(t.win,"\n")
    end
  end

  local mx, my = getMousePosition()
  local winW, winH = getMainWindowSize()

  local px = mx + s.cursorOffset
  local py = my + s.cursorOffset

  if px + t.width > winW then
    px = winW - t.width - s.screenMargin
  end
  if py + t.height > winH then
    py = my - t.height - s.cursorOffset
  end

  px = math.max(px, s.screenMargin)
  py = math.max(py, s.screenMargin)

-- Position tooltip relative to cursor
  local mx, my = getMousePosition()
  local winW, winH = getMainWindowSize()
  
  local px = mx + s.cursorOffset
  local py = my + s.cursorOffset
  
  -- Horizontal clamp
  if px + t.width > winW then
    px = winW - t.width - s.screenMargin
  end
  px = math.max(px, s.screenMargin)
  
  -- Vertical flip if needed
  if py + t.height > winH then
    py = my - t.height - s.cursorOffset
  end
  py = math.max(py, s.screenMargin)
  
  -- Stack windows: border → header → content
  moveWindow(t.border, px, py)
  
  moveWindow(
    t.header,
    px + s.tooltipBorderSize,
    py + s.tooltipBorderSize
  )
  
  moveWindow(
    t.win,
    px + s.tooltipBorderSize,
    py + s.tooltipBorderSize + headerHeight
  )
  
  showWindow(t.border)
  showWindow(t.header)
  showWindow(t.win)

end

-- ============================================================================
-- Click handling
-- ============================================================================

function ItemTracker.handleClick(name)
  -- Shift held → full identify in chat
  if holdingModifiers(mudlet.keymodifier.Shift) then
    ItemTracker.hideTooltip()
    ItemTracker.click(name)
    return
  end

  -- Normal click → tooltip
  ItemTracker.showTooltip(name)
end

-- ============================================================================
-- User command
-- ============================================================================
tempAlias(string.format("^%s$",ItemTracker.settings.alias), function()
  local s = ItemTracker.settings

  cecho(string.format("\n<light_goldenrod>[%s v%s by %s]<white>\n",ItemTracker.name,ItemTracker.version,ItemTracker.author))
  cecho("<grey>Clickable item identification & lookup system\n\n")

  cecho("<white>Usage:\n")
  cecho(string.format("  <cyan>%s <white><item name or partial>\n\n",ItemTracker.settings.alias))

  cecho("<white>Examples:\n")
  cecho(string.format("  <cyan>%s bracelet<white>                – search for items containing 'bracelet'\n",ItemTracker.settings.alias))
  cecho(string.format("  <cyan>%s an oversized lumber axe<white> – exact name lookup\n\n",ItemTracker.settings.alias))

  cecho("<white>In-game interaction:\n")
  cecho("  <cyan>• Click an item name<white>       – show tooltip near your cursor\n")
  cecho("  <cyan>• Shift + Click<white>            – print full item details to chat\n")
  cecho("  <cyan>• Click anywhere else<white>      – close the tooltip\n\n")

  cecho("<white>Detection rules:\n")
  cecho("  <grey>• Only matches item names at the END of a line\n")
  cecho("  <grey>• Longest names are matched first\n")
  cecho("  <grey>• Prevents false matches (e.g. 'egg' in 'leggings')\n\n")

  cecho("<white>Notes:\n")
  cecho("  <grey>• Duplicate item names are supported and shown together\n")
  cecho("  <grey>• Tooltip size auto-adjusts to item details\n")
  cecho("  <grey>• Colors and layout can be customized in ItemTracker.settings\n\n")

end)

tempAlias(string.format("^%s\\s+(.+)$",ItemTracker.settings.alias), function()
  local query = matches[2]
  local results = ItemTracker.find(query)

  if not results or #results == 0 then
    cecho("<red>[ID] No items found for: " .. query .. "\n")
    return
  end

  if #results == 1 then
    ItemTracker.show(results[1])
    return
  end

  cecho("<light_goldenrod>[ID] Multiple matches:<white>\n")
  for i, item in ipairs(results) do
    cecho(string.format("   <white>%d) ", i))
      -- Insert clickable link in its place
    cechoLink(
        ItemTracker.settings.itemLinkColor .. item.name .. "<white>\n",
        function() ItemTracker.handleClick(item.name) end,
        "Click: tooltip | Shift+Click: full identify",
        true
    )
  end
  cecho("<light_goldenrod>Refine your search.<white>\n")
end)

-- ============================================================================
-- Global hide handler
-- ============================================================================

if not ItemTracker._mouseHandler then
  ItemTracker._mouseHandler =
    registerAnonymousEventHandler("sysWindowMousePressEvent", function()
      ItemTracker.hideTooltip()
    end)
end

-- ============================================================================
-- Startup
-- ============================================================================

ItemTracker.load(getMudletHomeDir() .. "/DM-Item-Tracker-Releases-Latest/darkmists_items.json")
ItemTracker.initTooltip()
