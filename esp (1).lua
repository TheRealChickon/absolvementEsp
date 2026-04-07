dx9.ShowConsole(false)

local DataModel = dx9.GetDatamodel()
local WorkSpace = dx9.FindFirstChild(DataModel, "Workspace")
local w2s       = dx9.WorldToScreen or WorldToScreen

-- ── Helpers ──────────────────────────────────────────────────
local function safeChildren(inst)
    if not inst or inst == 0 then return {} end
    return dx9.GetChildren(inst) or {}
end

local function cleanName(name)
    local clean = string.gsub(name, "%d+", "")
    clean = string.match(clean, "^%s*(.-)%s*$")
    return (clean ~= "" and clean) or "?"
end

-- ── Rarity Colors ─────────────────────────────────────────────
local RC = {
    Void     = {255, 255, 255},  -- white
    Relic    = {255, 165,   0},  -- orange
    Unique   = {180,   0, 255},  -- purple
    Mythical = {255, 215,   0},  -- gold
    Rare     = { 80, 140, 255},  -- blue
    Uncommon = {100, 220, 180},  -- teal
    Common   = {180, 180, 180},  -- grey
    Unknown  = { 80, 255, 120},  -- green
}

-- ── Full Item → Rarity Map ────────────────────────────────────
-- ── Item Rarity Table (loaded from GitHub) ──────────────────
local ITEM_RARITY = (function()
    local src = dx9.Get("https://raw.githubusercontent.com/TheRealChickon/absolvementEsp/refs/heads/main/items.lua")
    if src and src ~= "" then
        local ok, result = pcall(loadstring(src))
        if ok and type(result) == "table" then return result end
    end
    return {}
end)()

-- ── Rarity lookup ─────────────────────────────────────────────
local function getRarity(name)
    return ITEM_RARITY[name] or "Unknown"
end

local function rarityColor(name)
    local t = getRarity(name)
    local c = RC[t] or RC.Unknown
    return c[1], c[2], c[3], t
end

-- ── Draw helpers ──────────────────────────────────────────────
local function drawESP(instance, label, r, g, b, radius)
    if not instance or instance == 0 then return end
    local p = dx9.GetPosition(instance)
    if not p or p.x == 0 then return end
    local sp = w2s({ p.x, p.y, p.z })
    if sp and sp.x then
        dx9.DrawCircle({sp.x, sp.y}, {r, g, b}, radius or 6)
        dx9.DrawString({sp.x, sp.y + 10}, {r, g, b}, label)
    end
end

local function drawHealthBar(sp, hp, maxhp)
    if not hp or not maxhp or maxhp <= 0 then return end
    local pct = math.max(0, math.min(1, hp / maxhp))
    local bw, bh = 44, 5
    local x = sp.x - bw / 2
    local y = sp.y - 22
    dx9.DrawFilledBox({x, y}, {x + bw, y + bh}, {40, 40, 40})
    local fr = math.floor(255 * (1 - pct))
    local fg = math.floor(255 * pct)
    if pct > 0 then
        dx9.DrawFilledBox({x, y}, {x + bw * pct, y + bh}, {fr, fg, 0})
    end
    dx9.DrawBox({x, y}, {x + bw, y + bh}, {150, 150, 150})
    dx9.DrawString({x, y - 12}, {fr, fg, 0}, math.floor(hp) .. "/" .. math.floor(maxhp))
end

-- ── Chest classifier ──────────────────────────────────────────
local function classifyChest(obj)
    if not obj or obj == 0 then return "Chest", 255, 200, 0 end
    local inner = dx9.FindFirstChild(obj, dx9.GetName(obj))
    if not inner or inner == 0 then inner = obj end

    local subModelCount = 0
    local hasCylinder   = false
    local hasTorus      = false
    local cubeCount     = 0

    for _, child in next, safeChildren(inner) do
        if child and child ~= 0 then
            local kind  = dx9.GetType(child) or ""
            local cname = string.lower(dx9.GetName(child) or "")
            if kind == "Model" then subModelCount = subModelCount + 1 end
            if string.find(cname, "cylinder") then hasCylinder = true end
            if string.find(cname, "torus")    then hasTorus    = true end
            if string.find(cname, "cube")     then cubeCount   = cubeCount + 1 end
        end
    end

    if subModelCount >= 2 then
        return "Multi [" .. subModelCount .. "]", 80, 180, 255
    end
    if hasCylinder or hasTorus then
        return "Barrel", 255, 140, 60
    end
    if cubeCount == 1 and subModelCount == 0 then
        return "Small", 200, 200, 80
    end
    return "Box", 255, 220, 0
end

-- ════════════════════════════════════════════════════════════
--  MAIN RENDER LOOP
-- ════════════════════════════════════════════════════════════

-- Refresh WorkSpace pointer each frame (handles lobby→dungeon transitions)
WorkSpace = dx9.FindFirstChild(DataModel, "Workspace")
if not WorkSpace or WorkSpace == 0 then return end

-- ── NPCs (red + health bar) ───────────────────────────────────
local npcCount = 0
local NPCs = dx9.FindFirstChild(WorkSpace, "NPCs")
if NPCs and NPCs ~= 0 then
    for _, npc in next, safeChildren(NPCs) do
        if npc and npc ~= 0 then
            local hrp = dx9.FindFirstChild(npc, "HumanoidRootPart")
            if hrp and hrp ~= 0 then
                npcCount = npcCount + 1
                local name = cleanName(dx9.GetName(npc))
                local p    = dx9.GetPosition(hrp)
                if p and p.x ~= 0 then
                    local sp = w2s({ p.x, p.y, p.z })
                    if sp and sp.x then
                        dx9.DrawCircle({sp.x, sp.y}, {255, 80, 80}, 6)
                        dx9.DrawString({sp.x, sp.y + 10}, {255, 80, 80}, name)
                        local hum = dx9.FindFirstChild(npc, "Humanoid")
                        if hum and hum ~= 0 then
                            drawHealthBar(sp, dx9.GetHealth(hum), dx9.GetMaxHealth(hum))
                        end
                    end
                end
            end
        end
    end
end

dx9.DrawString({20, 1050}, {255, 80, 80}, "Enemies: " .. npcCount)

-- ── Chests / OtherChars (classified + rarity-colored) ────────
-- Chests are Models; their actual parts are the children (skip Humanoid)
local OtherChars = dx9.FindFirstChild(WorkSpace, "OtherChars")
if OtherChars and OtherChars ~= 0 then
    for _, obj in next, safeChildren(OtherChars) do
        if obj and obj ~= 0 then
            local label, r, g, b = classifyChest(obj)
            for _, child in next, safeChildren(obj) do
                if child and child ~= 0 then
                    if dx9.GetName(child) ~= "Humanoid" then
                        drawESP(child, label, r, g, b, 7)
                    end
                end
            end
        end
    end
end

-- ── Potentials (cyan) ─────────────────────────────────────────
local Potentials = dx9.FindFirstChild(WorkSpace, "Potentials")
if Potentials and Potentials ~= 0 then
    for _, pot in next, safeChildren(Potentials) do
        if pot and pot ~= 0 then
            drawESP(pot, cleanName(dx9.GetName(pot)), 0, 220, 255)
        end
    end
end

-- ── Teleports / Portals (purple) ──────────────────────────────
local Teleports = dx9.FindFirstChild(WorkSpace, "Teleports")
if Teleports and Teleports ~= 0 then
    for _, tp in next, safeChildren(Teleports) do
        if tp and tp ~= 0 then
            drawESP(tp, "Portal", 200, 80, 255)
        end
    end
end

-- ── Vendors (orange) ──────────────────────────────────────────
local Vendors = dx9.FindFirstChild(WorkSpace, "Vendors")
if Vendors and Vendors ~= 0 then
    for _, v in next, safeChildren(Vendors) do
        if v and v ~= 0 then
            drawESP(v, "Vendor", 255, 140, 0)
        end
    end
end

-- ── MAP: doors only ───────────────────────────────────────────
local MAP = dx9.FindFirstChild(WorkSpace, "MAP")
if MAP and MAP ~= 0 then
    for _, obj in next, safeChildren(MAP) do
        if obj and obj ~= 0 then
            local nameLow = string.lower(dx9.GetName(obj))
            if string.find(nameLow, "door") and not string.find(nameLow, "wall") then
                local p = dx9.GetPosition(obj)
                if p and p.x and p.x ~= 0 then
                    local sp = w2s({ p.x, p.y, p.z })
                    if sp and sp.x then
                        if string.find(nameLow, "boss") then
                            local x, y, s = sp.x, sp.y, 14
                            dx9.DrawLine({x,   y-s}, {x+s, y  }, {255, 30, 30})
                            dx9.DrawLine({x+s, y  }, {x,   y+s}, {255, 30, 30})
                            dx9.DrawLine({x,   y+s}, {x-s, y  }, {255, 30, 30})
                            dx9.DrawLine({x-s, y  }, {x,   y-s}, {255, 30, 30})
                            dx9.DrawString({x, y - s - 14}, {255, 30, 30}, "!! BOSS !!")
                        else
                            dx9.DrawCircle({sp.x, sp.y}, {220, 220, 220}, 5)
                            dx9.DrawString({sp.x, sp.y + 10}, {220, 220, 220}, "Door")
                        end
                    end
                end
            end
        end
    end
end

-- ── Pickupables / Dropped Items (rarity-colored) ─────────────
local skipFolders = {
    NPCs=true, OtherChars=true, Chests=true, Potentials=true,
    Teleports=true, Vendors=true, MAP=true, Rooms=true,
    Characters=true, Projectiles=true, projectiledebug=true,
    Camera=true, Terrain=true,
}

for _, obj in next, safeChildren(WorkSpace) do
    if obj and obj ~= 0 then
        local raw = dx9.GetName(obj)
        if not skipFolders[raw] and not string.match(raw, "^%d") then
            if dx9.FindFirstChild(obj, "HumanoidRootPart") == 0 then
                local clean = cleanName(raw)
                if clean ~= "Part" and clean ~= "?" then
                    local r, g, b, tier = rarityColor(raw)
                    local displayLabel  = clean .. " [" .. tier .. "]"
                    local p = dx9.GetPosition(obj)
                    if p and not (p.x == 0 and p.y == 0 and p.z == 0) then
                        drawESP(obj, displayLabel, r, g, b)
                    else
                        for _, child in next, safeChildren(obj) do
                            if child and child ~= 0 then
                                local cp = dx9.GetPosition(child)
                                if cp and not (cp.x == 0 and cp.y == 0 and cp.z == 0) then
                                    drawESP(child, displayLabel, r, g, b)
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end
