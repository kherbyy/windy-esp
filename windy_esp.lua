-- Windy ESP — Rimuru UI Edition v1.9.7
-- For Windy Bee Simulator / FTF
-- v1.9.6: Full optimization - Door ESP & Freeze Pod ESP no longer lag
-- v1.9.6b: Ragdoll Tracker bar moved inside panel
-- v1.9.7: Reverted :IsA("BasePart") to IsRealPart() in door functions

local RIM_URL = "https://raw.githubusercontent.com/kherbyy/rem-ui/main/rem.lua"
local UI = _G.Rimuru or _G.Rem
if not UI then
    loadstring(game:HttpGet(RIM_URL))()
    UI = _G.Rimuru or _G.Rem
end
if not UI then
    error("[WindyESP] rimuru framework failed to load from " .. RIM_URL)
end

local waiter = (task and task.wait) or wait

local function GetMatchaService(name)
    local service = nil
    pcall(function() service = game[name] end)
    if service then return service end
    pcall(function() service = game:GetService(name) end)
    if service then return service end
    return nil
end

local function WaitForMatchaService(name, timeout)
    local startTime = tick()
    local service = GetMatchaService(name)
    while not service do
        if timeout and (tick() - startTime) > timeout then
            warn("[WindyESP] Timed out waiting for service: " .. name)
            return nil
        end
        waiter(0.1)
        service = GetMatchaService(name)
    end
    return service
end

local Players = WaitForMatchaService("Players", 15)
if not Players then error("[WindyESP] Could not acquire Players service.") end

local RunService = WaitForMatchaService("RunService", 15)
local ReplicatedStorage = WaitForMatchaService("ReplicatedStorage", 15)

local LocalPlayer = nil
local startTime = tick()
while not LocalPlayer do
    if (tick() - startTime) > 15 then
        warn("[WindyESP] Timed out waiting for LocalPlayer.")
        break
    end
    waiter(0.1)
    pcall(function()
        if Players then LocalPlayer = Players.LocalPlayer end
    end)
end
if not LocalPlayer then error("[WindyESP] LocalPlayer is nil after 15s — aborting.") end

if not math.clamp then
    math.clamp = function(val, min, max)
        return math.min(math.max(val, min), max)
    end
end

print("[WindyESP] Services ready.")

local State = {
    npc_player_esp = false,
    npc_beast_esp = false,
    pc_esp = false,
    freeze_pod_esp = false,
    exit_door_esp = false,
    door_only_open = false,
    hide_completed_pcs = false,
    door_show_state = true,
    show_boxes = true,
    show_labels = true,
    show_distance = false,
    show_player_progress = true,
    show_tracers = false,
    player_show_state = true,
    player_state_color = true,
    show_power_name = true,
    show_power_bar = true,
    show_power_percent = true,
    show_beast_label = true,
    bar_height = 6,
    bar_width = 100,
    power_font_size = 16,
    isRunning = true,
}

local function isVector3(v)
    if v == nil then return false end
    local ok, x = pcall(function() return v.X end)
    return ok and type(x) == "number"
end

local function CreateEspText()
    local t = Drawing.new("Text")
    t.Center = true; t.Outline = true; t.Font = 2; t.Size = 13
    t.Transparency = 1; t.ZIndex = 0; t.Visible = false
    t.Color = Color3.fromRGB(255, 255, 255)
    return t
end

local EspObjects = {}
local ActiveEspKeys = { npc = {}, pc = {}, fp = {}, ed = {}, sd = {}, dd = {}, dw = {} }
local TracerObjects = {}
local ActiveTracerKeys = {}

local function GetTracerEntry(key)
    local t = TracerObjects[key]
    if t then return t end
    t = Drawing.new("Line")
    t.From = Vector2.new(0, 0)
    t.To = Vector2.new(1, 1)
    t.Color = Color3.fromRGB(80, 255, 80)
    t.Thickness = 3
    t.Transparency = 1
    t.ZIndex = 999
    t.Visible = false
    TracerObjects[key] = t
    return t
end

local function HideTracerEntry(t)
    if t then t.Visible = false end
end

local function GetEspEntry(key)
    local e = EspObjects[key]
    if e then return e end
    e = {
        box = Drawing.new("Square"),
        label = CreateEspText(),
        percentLabel = Drawing.new("Text"),
        barBg = Drawing.new("Square"),
        barFill = Drawing.new("Square"),
        borderBar = Drawing.new("Square"),
    }
    e.box.Visible = false; e.box.Filled = false; e.box.Thickness = 1; e.box.Transparency = 1; e.box.ZIndex = 0
    e.percentLabel.Center = true; e.percentLabel.Outline = true; e.percentLabel.Font = 2
    e.percentLabel.Size = 14; e.percentLabel.Visible = false; e.percentLabel.Transparency = 1
    e.percentLabel.Color = Color3.fromRGB(255, 255, 255); e.percentLabel.ZIndex = 2
    e.barBg.Filled = true; e.barBg.Transparency = 0.2; e.barBg.ZIndex = 0; e.barBg.Visible = false
    e.barFill.Filled = true; e.barFill.Transparency = 0.4; e.barFill.ZIndex = 1; e.barFill.Visible = false
    e.borderBar.Visible = false; e.borderBar.Filled = false; e.borderBar.Thickness = 1
    e.borderBar.Transparency = 0.5; e.borderBar.ZIndex = 0; e.borderBar.Color = Color3.fromRGB(255, 255, 255)
    EspObjects[key] = e
    return e
end

local function HideEspEntry(e)
    if not e then return end
    if e.box then e.box.Visible = false end
    if e.label then e.label.Visible = false end
    if e.percentLabel then e.percentLabel.Visible = false end
    if e.barBg then e.barBg.Visible = false end
    if e.barFill then e.barFill.Visible = false end
    if e.borderBar then e.borderBar.Visible = false end
end

local function DestroyEspEntry(e)
    if not e then return end
    if e.box and e.box.Remove then pcall(function() e.box:Remove() end) end
    if e.label and e.label.Remove then pcall(function() e.label:Remove() end) end
    if e.percentLabel and e.percentLabel.Remove then pcall(function() e.percentLabel:Remove() end) end
    if e.barBg and e.barBg.Remove then pcall(function() e.barBg:Remove() end) end
    if e.barFill and e.barFill.Remove then pcall(function() e.barFill:Remove() end) end
    if e.borderBar and e.borderBar.Remove then pcall(function() e.borderBar:Remove() end) end
end

local function FullCleanupBucket(bucketKey)
    if not ActiveEspKeys[bucketKey] then return end
    for k, _ in pairs(ActiveEspKeys[bucketKey]) do
        local e = EspObjects[k]
        if e then DestroyEspEntry(e); EspObjects[k] = nil end
    end
    ActiveEspKeys[bucketKey] = {}
end

local function CleanupTrackedEspKeys(bucketKey, seen)
    if not ActiveEspKeys[bucketKey] then ActiveEspKeys[bucketKey] = {}; return end
    local tracked = ActiveEspKeys[bucketKey]
    for key, _ in pairs(tracked) do
        if not seen[key] then
            local e = EspObjects[key]
            if e then HideEspEntry(e) end
            tracked[key] = nil
        end
    end
end

local function GetWorldToScreen(position)
    if not isVector3(position) then return nil, false end
    if type(WorldToScreen) == "function" then
        local ok, sp, on = pcall(WorldToScreen, position)
        if ok then return sp, on == true end
    end
    local cam = workspace and workspace.CurrentCamera or nil
    if cam and cam.WorldToViewportPoint then
        local ok, v, vis = pcall(function() return cam:WorldToViewportPoint(position) end)
        if ok and v then return Vector2.new(v.X, v.Y), vis == true end
    end
    return nil, false
end

local MAX_ESP_DISTANCE_SQ = 6000 * 6000
local function IsTooFar(camPos, targetPos)
    local dx = targetPos.X - camPos.X
    local dy = targetPos.Y - camPos.Y
    local dz = targetPos.Z - camPos.Z
    return (dx*dx + dy*dy + dz*dz) > MAX_ESP_DISTANCE_SQ
end

local function IsRealPart(inst)
    if not inst then return false end
    local ok, pos = pcall(function() return inst.Position end)
    if not ok or not pos then return false end
    local okX, x = pcall(function() return pos.X end)
    if not okX or type(x) ~= "number" then return false end
    local okY, y = pcall(function() return pos.Y end)
    if not okY or type(y) ~= "number" then return false end
    local okZ, z = pcall(function() return pos.Z end)
    if not okZ or type(z) ~= "number" then return false end
    return true
end

local PlayerProgressCache = {}
local LastProgressCacheRefresh = 0

local function GetIndividualPlayerProgress(player)
    if not player or not player:IsA("Player") then return 0 end
    local progress = 0
    pcall(function()
        local mod = player:FindFirstChild("TempPlayerStatsModule")
        if mod then
            local ap = mod:FindFirstChild("ActionProgress")
            if ap and type(ap.Value) == "number" then
                progress = math.clamp(ap.Value, 0, 1)
            end
        end
    end)
    return progress
end

local function RefreshPlayerProgressCache(force)
    local now = tick()
    if not force and (now - LastProgressCacheRefresh) < 0.15 then
        return PlayerProgressCache
    end
    local cache = {}
    for _, player in ipairs(Players:GetPlayers()) do
        cache[player] = {
            progress = GetIndividualPlayerProgress(player),
            player = player,
            name = player.Name,
        }
    end
    PlayerProgressCache = cache
    LastProgressCacheRefresh = now
    return cache
end

local function GetPlayerProgress(player)
    if not player then return 0 end
    if player == Players.LocalPlayer then
        return GetIndividualPlayerProgress(player)
    end
    RefreshPlayerProgressCache(false)
    local cached = PlayerProgressCache[player]
    if cached then return cached.progress end
    return GetIndividualPlayerProgress(player)
end

local PLAYER_STATE_CACHE = {}
local PLAYER_STATE_INTERVAL = 0.15

local function GetPlayerState(player)
    if not player then return nil, nil end
    local now = tick()
    local cached = PLAYER_STATE_CACHE[player]
    if cached and (now - cached.t) < PLAYER_STATE_INTERVAL then
        return cached.state, cached.color
    end
    local state = nil
    local color = nil
    local statsModule = player:FindFirstChild("TempPlayerStatsModule")
    if statsModule then
        local ragdoll = statsModule:FindFirstChild("Ragdoll")
        if ragdoll then
            local ok, val = pcall(function() return ragdoll.Value end)
            if ok and val == true then state = "DOWN"; color = Color3.fromRGB(255, 60, 60) end
        end
        if not state then
            local captured = statsModule:FindFirstChild("Captured")
            if captured then
                local ok, val = pcall(function() return captured.Value end)
                if ok and val == true then state = "CAPTURED"; color = Color3.fromRGB(255, 130, 0) end
            end
        end
        if not state then
            local crawling = statsModule:FindFirstChild("IsCrawling")
            if crawling then
                local ok, val = pcall(function() return crawling.Value end)
                if ok and val == true then state = "CRAWLING"; color = Color3.fromRGB(255, 220, 60) end
            end
        end
        if not state then
            local anim = statsModule:FindFirstChild("CurrentAnimation")
            if anim then
                local ok, val = pcall(function() return anim.Value end)
                if ok and type(val) == "string" then
                    if val == "Typing" then state = "TYPING"; color = Color3.fromRGB(100, 180, 255)
                    elseif val == "Carry" then state = "CARRY"; color = Color3.fromRGB(180, 100, 255) end
                end
            end
        end
    end
    PLAYER_STATE_CACHE[player] = { state = state, color = color, t = now }
    return state, color
end

local RagdollTracker = {
    active = {},
    pollInterval = 0.1,
    lastPoll = 0,
    drawn = {},
    visible = false,
    maxDisplay = 8,
}
local DOWN_GRACE_TIME = 0.5

local function ReadPlayerDownState(player)
    if not player then return nil, nil, nil end
    local stats = player:FindFirstChild("TempPlayerStatsModule")
    if not stats then return nil, nil, nil end
    local ragdollVal = false
    local capturedVal = false
    local progressVal = 0
    local hasStats = false
    local ragdoll = stats:FindFirstChild("Ragdoll")
    if ragdoll then
        hasStats = true
        local ok, val = pcall(function() return ragdoll.Value end)
        if ok then ragdollVal = (val == true) end
    end
    local captured = stats:FindFirstChild("Captured")
    if captured then
        hasStats = true
        local ok, val = pcall(function() return captured.Value end)
        if ok then capturedVal = (val == true) end
    end
    local progress = stats:FindFirstChild("ActionProgress")
    if progress then
        local ok, val = pcall(function() return progress.Value end)
        if ok and type(val) == "number" then progressVal = math.clamp(val, 0, 1) end
    end
    if not hasStats then return nil, nil, nil end
    if ragdollVal then return true, "DOWN", progressVal end
    if capturedVal then return true, "CAPTURED", progressVal end
    return false, nil, 0
end

local function PollRagdollTracker()
    local now = tick()
    if (now - RagdollTracker.lastPoll) < RagdollTracker.pollInterval then return end
    RagdollTracker.lastPoll = now
    local seenThisTick = {}
    for _, player in ipairs(Players:GetPlayers()) do
        seenThisTick[player] = true
        if player ~= LocalPlayer then
            local isDown, reason, progress = ReadPlayerDownState(player)
            local record = RagdollTracker.active[player]
            if isDown == true then
                if not record then
                    RagdollTracker.active[player] = {
                        name = player.Name, startTime = now,
                        reason = reason or "DOWN", lastDownTick = now, progress = progress or 0,
                    }
                else
                    record.lastDownTick = now
                    record.progress = progress or 0
                    if reason and reason ~= record.reason then record.reason = reason end
                end
            elseif isDown == false then
                if record and (now - record.lastDownTick) >= DOWN_GRACE_TIME then
                    RagdollTracker.active[player] = nil
                end
            elseif isDown == nil and record then
                if (now - (record.lastDownTick or 0)) >= DOWN_GRACE_TIME then
                    RagdollTracker.active[player] = nil
                end
            end
        end
    end
    for player, _ in pairs(RagdollTracker.active) do
        if not seenThisTick[player] then RagdollTracker.active[player] = nil end
    end
end

local function EnsureTrackerSlot(idx)
    while #RagdollTracker.drawn < idx + 5 do
        local cur = #RagdollTracker.drawn + 1
        local slotInGroup = (cur - 1) % 6
        local obj
        if slotInGroup == 0 then
            obj = Drawing.new("Square"); obj.Filled = false; obj.Thickness = 1
            obj.Transparency = 0.7; obj.Color = Color3.fromRGB(80, 30, 30); obj.ZIndex = 0
        elseif slotInGroup == 1 then
            obj = Drawing.new("Text"); obj.Center = false; obj.Outline = true; obj.Font = 2
            obj.Size = 16; obj.Color = Color3.fromRGB(255, 255, 255); obj.ZIndex = 7
        elseif slotInGroup == 2 then
            obj = Drawing.new("Text"); obj.Center = false; obj.Outline = true; obj.Font = 2
            obj.Size = 14; obj.Color = Color3.fromRGB(255, 255, 255); obj.ZIndex = 7
        elseif slotInGroup == 3 then
            obj = Drawing.new("Square"); obj.Filled = true; obj.Transparency = 0.2
            obj.Color = Color3.fromRGB(20, 20, 25); obj.ZIndex = 1
        elseif slotInGroup == 4 then
            obj = Drawing.new("Square"); obj.Filled = true; obj.Transparency = 0.4
            obj.Color = Color3.fromRGB(255, 180, 0); obj.ZIndex = 2
        else
            obj = Drawing.new("Square"); obj.Filled = false; obj.Thickness = 1
            obj.Transparency = 0.5; obj.Color = Color3.fromRGB(255, 255, 255); obj.ZIndex = 3
        end
        obj.Visible = false
        table.insert(RagdollTracker.drawn, obj)
    end
end

local function RenderRagdollTracker()
    if not RagdollTracker.visible then
        for _, obj in ipairs(RagdollTracker.drawn) do obj.Visible = false end
        return
    end
    local entries = {}
    for _, rec in pairs(RagdollTracker.active) do
        table.insert(entries, { name = rec.name, reason = rec.reason or "DOWN",
            progress = rec.progress or 0, elapsed = tick() - rec.startTime })
    end
    table.sort(entries, function(a, b) return a.progress < b.progress end)
    if #entries > RagdollTracker.maxDisplay then
        local trimmed = {}
        for i = 1, RagdollTracker.maxDisplay do trimmed[i] = entries[i] end
        entries = trimmed
    end
    local cam = workspace.CurrentCamera
    local vpSize = (cam and cam.ViewportSize) or Vector2.new(1920, 1080)
    local xStart = 20
    local yStart = math.floor(vpSize.Y * 0.35)
    local lineHeight = 48
    local panelW = 280
    local panelH = 40
    for i = 1, #entries do
        local entry = entries[i]
        local baseIdx = (i - 1) * 6 + 1
        local y = yStart + (i - 1) * lineHeight
        EnsureTrackerSlot(baseIdx)
        local bg = RagdollTracker.drawn[baseIdx]
        local nameText = RagdollTracker.drawn[baseIdx + 1]
        local pctText = RagdollTracker.drawn[baseIdx + 2]
        local barBg = RagdollTracker.drawn[baseIdx + 3]
        local barFill = RagdollTracker.drawn[baseIdx + 4]
        local borderBar = RagdollTracker.drawn[baseIdx + 5]
        bg.ZIndex = 0; nameText.ZIndex = 7; pctText.ZIndex = 7
        barBg.ZIndex = 1; barFill.ZIndex = 2; borderBar.ZIndex = 3
        local p = math.clamp(entry.progress or 0, 0, 1)
        local r, g, b
        if p < 0.5 then
            local t = p / 0.5; r = 255; g = math.floor(70 + (180 - 70) * t); b = math.floor(70 * (1 - t))
        elseif p < 0.8 then
            local t = (p - 0.5) / 0.3; r = 255; g = math.floor(180 + (230 - 180) * t); b = 0
        else
            local t = (p - 0.8) / 0.2; r = math.floor(230 * (1 - t)); g = 255; b = math.floor(60 * t)
        end
        local labelColor = Color3.fromRGB(r, g, b)
        bg.Position = Vector2.new(xStart, y); bg.Size = Vector2.new(panelW, panelH)
        bg.Filled = false; bg.Thickness = 1; bg.Transparency = 0.7
        if p >= 0.8 then bg.Color = Color3.fromRGB(60, 200, 60)
        elseif entry.reason == "CAPTURED" then bg.Color = Color3.fromRGB(200, 120, 30)
        else bg.Color = Color3.fromRGB(200, 60, 60) end
        bg.Visible = true
        if p >= 0.9 then
            local pulse = (math.sin(tick() * 12) + 1) * 0.5
            local boost = 0.3 + 0.7 * pulse
            labelColor = Color3.fromRGB(
                math.min(255, math.floor(r + (255 - r) * boost)),
                math.min(255, math.floor(g + (255 - g) * boost)),
                math.min(255, math.floor(b + (255 - b) * boost)))
        end
        local stateLabel = entry.reason
        if p >= 0.9 then stateLabel = entry.reason .. " (ALMOST UP)" end
        nameText.Text = "[" .. stateLabel .. "] " .. entry.name
        nameText.Position = Vector2.new(xStart + 8, y + 5)
        nameText.Color = labelColor
        nameText.Visible = true
        pctText.Text = string.format("%.0f%%", p * 100)
        pctText.Position = Vector2.new(xStart + panelW - 52, y + 6)
        pctText.Color = labelColor
        pctText.Visible = true

        local barY = y + panelH - 12
        local barW = panelW - 20
        local barH = 8
        local barX = xStart + 10

        barBg.Position = Vector2.new(barX, barY)
        barBg.Size = Vector2.new(barW, barH)
        barBg.Color = Color3.fromRGB(20, 20, 25)
        barBg.Transparency = 0.2
        barBg.Filled = true
        barBg.Visible = true

        local fillW = math.max(2, math.floor(barW * p))
        barFill.Position = Vector2.new(barX, barY)
        barFill.Size = Vector2.new(fillW, barH)
        barFill.Color = labelColor
        barFill.Transparency = 0.4
        barFill.Filled = true
        barFill.Visible = true

        borderBar.Position = Vector2.new(barX - 1, barY - 1)
        borderBar.Size = Vector2.new(barW + 2, barH + 2)
        borderBar.Color = Color3.fromRGB(255, 255, 255)
        borderBar.Transparency = 0.5
        borderBar.Thickness = 1
        borderBar.Filled = false
        borderBar.Visible = true
    end
    local usedSlots = #entries * 6
    for i = usedSlots + 1, #RagdollTracker.drawn do RagdollTracker.drawn[i].Visible = false end
end

local function GetBeastPowerInfo(beastCharacter)
    if not beastCharacter or not beastCharacter:IsA("Model") then return "Unknown", 0 end
    local powerName = "Unknown"; local percent = 0
    pcall(function()
        local cp = ReplicatedStorage:FindFirstChild("CurrentPower")
        if cp then powerName = cp.Value or "Unknown" end
    end)
    pcall(function()
        local bp = beastCharacter:FindFirstChild("BeastPowers")
        if bp then
            local pp = bp:FindFirstChild("PowerProgressPercent") or bp:FindFirstChild("Progress") or bp:FindFirstChild("Power")
            if pp and pp.Value ~= nil then percent = tonumber(pp.Value) or 0 end
        end
    end)
    if percent == 0 then
        pcall(function()
            local a = beastCharacter:GetAttribute("PowerProgress")
            if a then percent = tonumber(a) or 0 end
        end)
    end
    return powerName, percent
end

local function GetPowerColor(powerName, progress)
    if powerName == "Runner" then return Color3.fromRGB(100, 255, 100) end
    if powerName == "Stalker" then return Color3.fromRGB(255, 100, 100) end
    if powerName == "Seer" then return Color3.fromRGB(100, 100, 255) end
    if progress >= 0.95 then return Color3.fromRGB(0, 255, 50) end
    if progress > 0 then return Color3.fromRGB(255, 180, 0) end
    return Color3.fromRGB(150, 150, 150)
end

local function GetComputerScreenState(color)
    if not color then return "idle" end
    local r, g, b = color.R, color.G, color.B
    if r <= 1 and g <= 1 and b <= 1 then
        r = math.floor(r * 255 + 0.5); g = math.floor(g * 255 + 0.5); b = math.floor(b * 255 + 0.5)
    else
        r = math.floor(r + 0.5); g = math.floor(g + 0.5); b = math.floor(b + 0.5)
    end
    if r == 13 and g == 105 and b == 172 then return "idle" end
    if r == 196 and g == 40 and b == 28 then return "errored" end
    return "done"
end

local CurrentMapRoot = nil
local DoorCache = { sd = {}, dd = {}, dw = {}, ed = {} }
local ComputerCache = {}
local ComputerAnchorCache = {}
local FreezePodCache = {}
local ExitDoorColorCache = {}
local DoorSlabParts = {}
local DoorBaselinePos = {}
local DoorStateCache = {}
local ComputerProgressCache = {}
local ComputerHackerCache = {}
local ComputerProgressMap = nil

local function ClearMapCaches()
    DoorCache.sd = {}; DoorCache.dd = {}; DoorCache.dw = {}; DoorCache.ed = {}
    ComputerCache = {}; ComputerAnchorCache = {}; FreezePodCache = {}
    ExitDoorColorCache = {}; DoorSlabParts = {}; DoorBaselinePos = {}
    DoorStateCache = {}; ComputerProgressCache = {}; ComputerHackerCache = {}
    ComputerProgressMap = nil; PLAYER_STATE_CACHE = {}; RagdollTracker.active = {}
end

local function FindMapRoot()
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj and obj:FindFirstChild("ComputerTable") then return obj end
    end
    return nil
end

local function PickDoorAnchor(model)
    for _, name in ipairs({ "DoorTrigger", "ExitDoorTrigger", "ExitArea" }) do
        local trig = model:FindFirstChild(name)
        if trig and IsRealPart(trig) then return trig end
    end
    for _, slabName in ipairs({ "Door", "DoorR", "DoorL" }) do
        local slab = model:FindFirstChild(slabName)
        if slab then
            for _, child in ipairs(slab:GetDescendants()) do
                if IsRealPart(child) then return child end
            end
        end
    end
    for _, child in ipairs(model:GetDescendants()) do
        if IsRealPart(child) then return child end
    end
    return nil
end

local function RebuildMapCaches()
    local root = FindMapRoot()
    if root ~= CurrentMapRoot then CurrentMapRoot = root; ClearMapCaches() end
    if not CurrentMapRoot then return end
    for _, obj in ipairs(CurrentMapRoot:GetChildren()) do
        if obj:IsA("Model") then
            local n = obj.Name
            if n == "SingleDoor" then
                local anchor = PickDoorAnchor(obj)
                if anchor then table.insert(DoorCache.sd, { anchor = anchor, model = obj }) end
            elseif n == "DoubleDoor" then
                local anchor = PickDoorAnchor(obj)
                if anchor then table.insert(DoorCache.dd, { anchor = anchor, model = obj }) end
            elseif n == "Doorway" or n == "DoorWAY" then
                local anchor = PickDoorAnchor(obj)
                if anchor then table.insert(DoorCache.dw, { anchor = anchor, model = obj }) end
            elseif n == "ExitDoor" then
                local anchor = PickDoorAnchor(obj)
                if anchor then
                    table.insert(DoorCache.ed, { anchor = anchor, model = obj })
                    local light = obj:FindFirstChild("Light")
                    if light and IsRealPart(light) then
                        local ok, col = pcall(function() return light.Color end)
                        ExitDoorColorCache[anchor] = (ok and col) or Color3.fromRGB(255, 255, 0)
                    else
                        ExitDoorColorCache[anchor] = Color3.fromRGB(255, 255, 0)
                    end
                end
            elseif n == "ComputerTable" then
                local screen = obj:FindFirstChild("Screen")
                if screen and IsRealPart(screen) then
                    table.insert(ComputerCache, screen)
                    local trig = obj:FindFirstChild("Trigger")
                    ComputerAnchorCache[screen] = (trig and IsRealPart(trig)) and trig or screen
                end
            elseif n == "FreezePod" then
                local anchor = obj:FindFirstChild("BasePart")
                if anchor and IsRealPart(anchor) then table.insert(FreezePodCache, anchor) end
            end
        end
    end
end

RebuildMapCaches()
local LastMapCheckTick = 0
local MAP_CHECK_INTERVAL = 0.5

local function CheckForMapChange()
    local now = tick()
    if (now - LastMapCheckTick) < MAP_CHECK_INTERVAL then return end
    LastMapCheckTick = now
    if not CurrentMapRoot or CurrentMapRoot.Parent ~= workspace then RebuildMapCaches(); return end
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj and obj:FindFirstChild("ComputerTable") and obj ~= CurrentMapRoot then RebuildMapCaches(); return end
    end
end

local FtfCharacterCache = {}
local LastFtfCharacterCacheRefresh = 0
local FtfCharacterMeta = {}

local function IsFtfCharacterModel(m)
    if not m or not m:IsA("Model") then return false end
    return m:FindFirstChild("HumanoidRootPart") ~= nil
end

local function IsBeastModel(m)
    local h = m and m:FindFirstChild("Hammer")
    return h and h:FindFirstChild("Handle") ~= nil or false
end

local function RefreshFtfCharacterCache(force)
    local now = tick()
    if not force and (now - LastFtfCharacterCacheRefresh) < 0.5 then return FtfCharacterCache end
    local results, seen = {}, {}
    local meta = {}
    for _, p in ipairs(Players:GetPlayers()) do
        local m = p.Character
        if not m or not m:IsDescendantOf(workspace) then m = workspace:FindFirstChild(p.Name) end
        if m and IsFtfCharacterModel(m) and not seen[m] then
            seen[m] = true
            table.insert(results, m)
            local root = m:FindFirstChild("HumanoidRootPart")
            local head = m:FindFirstChild("Head") or root
            meta[m] = { root = root, head = head, isBeast = IsBeastModel(m), player = p }
        end
    end
    FtfCharacterCache = results; FtfCharacterMeta = meta; LastFtfCharacterCacheRefresh = now
    return results
end

local function GetFtfCharacterTargets() return RefreshFtfCharacterCache(false) end

-- ============================================================================
-- DOOR ESP
-- ============================================================================
local DOOR_STATE_INTERVAL = 0.3

local function GetDoorSlabParts(model)
    local cached = DoorSlabParts[model]
    if cached and #cached > 0 then
        local stillValid = true
        for _, part in ipairs(cached) do
            if not part.Parent then stillValid = false; break end
        end
        if stillValid then return cached end
    end
    
    local parts = {}
    for _, slabName in ipairs({ "Door", "DoorR", "DoorL" }) do
        local slab = model:FindFirstChild(slabName)
        if slab then
            for _, child in ipairs(slab:GetChildren()) do
                if IsRealPart(child) then table.insert(parts, child) end
            end
        end
    end
    
    if #parts > 0 then
        DoorSlabParts[model] = parts
        return parts
    end
    
    for _, child in ipairs(model:GetDescendants()) do
        if IsRealPart(child) then
            local ignore = { DoorTrigger = true, ExitDoorTrigger = true, ExitArea = true,
                Frame = true, Light = true, Hinge = true, DoorBarrier = true }
            if not ignore[child.Name] then table.insert(parts, child) end
            if #parts >= 8 then break end
        end
    end
    
    DoorSlabParts[model] = parts
    return parts
end

local function AveragePosition(parts)
    if #parts == 0 then return nil end
    local sumX, sumY, sumZ, n = 0, 0, 0, 0
    local limit = math.min(#parts, 8)
    for i = 1, limit do
        local part = parts[i]
        if part.Parent then
            local ok, pos = pcall(function() return part.Position end)
            if ok then
                sumX = sumX + pos.X; sumY = sumY + pos.Y; sumZ = sumZ + pos.Z; n = n + 1
            end
        end
    end
    if n == 0 then return nil end
    return { X = sumX / n, Y = sumY / n, Z = sumZ / n }
end

local function IsDoorOpen(model, camPos)
    if not model or not model.Parent then return false end
    
    local anchor = nil
    pcall(function()
        for _, name in ipairs({ "DoorTrigger", "ExitDoorTrigger" }) do
            local t = model:FindFirstChild(name)
            if t and IsRealPart(t) then anchor = t; break end
        end
    end)
    
    if anchor and (anchor.Position - camPos).Magnitude > 6500 then
        return false
    end
    
    local now = tick()
    local cached = DoorStateCache[model]
    if cached and (now - cached.t) < DOOR_STATE_INTERVAL then
        return cached.open
    end
    
    local parts = GetDoorSlabParts(model)
    if #parts == 0 then
        DoorStateCache[model] = { open = false, t = now }
        return false
    end
    
    local avgPos = AveragePosition(parts)
    if not avgPos then
        DoorStateCache[model] = { open = false, t = now }
        return false
    end
    
    local baseline = DoorBaselinePos[model]
    if not baseline then
        DoorBaselinePos[model] = avgPos
        DoorStateCache[model] = { open = false, t = now }
        return false
    end
    
    local dx = avgPos.X - baseline.X
    local dy = avgPos.Y - baseline.Y
    local dz = avgPos.Z - baseline.Z
    local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
    local isOpen = dist > 0.3
    DoorStateCache[model] = { open = isOpen, t = now }
    return isOpen
end

local function UpdateFreezePodEsp()
    if not State.freeze_pod_esp then
        FullCleanupBucket("fp")
        return
    end
    
    local seen = {}
    local cam = workspace.CurrentCamera
    local camPos = cam and cam.CFrame.Position or Vector3.new(0, 0, 0)
    local targets = FreezePodCache
    
    for i = 1, #targets do
        local part = targets[i]
        if part and part.Parent then
            local key = "fp:" .. tostring(i)
            local pos = part.Position
            
            if IsTooFar(camPos, pos) then
                local e = EspObjects[key]
                if e then HideEspEntry(e) end
                ActiveEspKeys.fp[key] = nil
            else
                local sp, vis = GetWorldToScreen(pos + Vector3.new(0, 1.5, 0))
                seen[key] = true
                ActiveEspKeys.fp[key] = true
                
                if vis and sp then
                    local e = GetEspEntry(key)
                    e.box.Visible = false
                    e.label.Text = "FreezePod"
                    e.label.Position = Vector2.new(math.floor(sp.X), math.floor(sp.Y - 15))
                    e.label.Color = Color3.fromRGB(0, 0, 245)
                    e.label.Visible = true
                    e.barBg.Visible = false
                    e.barFill.Visible = false
                    e.percentLabel.Visible = false
                    e.borderBar.Visible = false
                else
                    local e = EspObjects[key]
                    if e then HideEspEntry(e) end
                end
            end
        end
    end
    
    CleanupTrackedEspKeys("fp", seen)
end

local function RenderDoorBucket(kind, bucketKey, targets, defaultColor, onlyOpen)
    local seen = {}
    local cam = workspace.CurrentCamera
    local camPos = cam and cam.CFrame.Position or Vector3.new(0, 0, 0)
    
    for i = 1, #targets do
        local entry = targets[i]
        local anchor = entry.anchor
        local model = entry.model
        
        if anchor and anchor.Parent then
            local pos = anchor.Position
            local key = bucketKey .. ":" .. tostring(i)
            
            if IsTooFar(camPos, pos) then
                local e = EspObjects[key]
                if e then HideEspEntry(e) end
                ActiveEspKeys[bucketKey][key] = nil
            else
                local isOpen = false
                if kind ~= "Doorway" then
                    isOpen = IsDoorOpen(model, camPos)
                end
                
                if onlyOpen and kind ~= "Doorway" and not isOpen then
                    local e = EspObjects[key]
                    if e then HideEspEntry(e) end
                    ActiveEspKeys[bucketKey][key] = nil
                else
                    local sp, vis = GetWorldToScreen(pos + Vector3.new(0, 1.5, 0))
                    seen[key] = true
                    ActiveEspKeys[bucketKey][key] = true
                    
                    if vis and sp then
                        local e = GetEspEntry(key)
                        local color = defaultColor
                        
                        if kind == "ExitDoor" and not State.door_show_state then
                            color = ExitDoorColorCache[anchor] or defaultColor
                        end
                        
                        if State.door_show_state and kind ~= "Doorway" then
                            color = isOpen and Color3.fromRGB(80, 255, 120) or Color3.fromRGB(255, 80, 80)
                        end
                        
                        local label = kind
                        if State.door_show_state and kind ~= "Doorway" then
                            label = label .. (isOpen and " [OPEN]" or " [CLOSED]")
                        end
                        
                        if State.show_boxes then
                            e.box.Position = Vector2.new(math.floor(sp.X - 15), math.floor(sp.Y - 15))
                            e.box.Size = Vector2.new(30, 30)
                            e.box.Color = color
                            e.box.Visible = true
                        else
                            e.box.Visible = false
                        end
                        
                        if State.show_labels then
                            e.label.Text = label
                            e.label.Position = Vector2.new(math.floor(sp.X), math.floor(sp.Y - 30))
                            e.label.Color = color
                            e.label.Size = 13
                            e.label.Visible = true
                        else
                            e.label.Visible = false
                        end
                        
                        e.barBg.Visible = false
                        e.barFill.Visible = false
                        e.percentLabel.Visible = false
                        e.borderBar.Visible = false
                    else
                        local e = EspObjects[key]
                        if e then HideEspEntry(e) end
                    end
                end
            end
        end
    end
    
    CleanupTrackedEspKeys(bucketKey, seen)
end

local function UpdateDoorEsp()
    if not State.exit_door_esp then
        for _, key in ipairs({ "sd", "dd", "dw", "ed" }) do
            FullCleanupBucket(key)
        end
        return
    end
    
    local onlyOpen = State.door_only_open == true
    RenderDoorBucket("SingleDoor", "sd", DoorCache.sd, Color3.fromRGB(0, 220, 255), onlyOpen)
    RenderDoorBucket("DoubleDoor", "dd", DoorCache.dd, Color3.fromRGB(255, 140, 0), onlyOpen)
    RenderDoorBucket("Doorway",    "dw", DoorCache.dw, Color3.fromRGB(180, 100, 255), onlyOpen)
    RenderDoorBucket("ExitDoor",   "ed", DoorCache.ed, Color3.fromRGB(255, 255, 0), onlyOpen)
end

-- ============================================================================
-- NPC ESP
-- ============================================================================
local function UpdateNpcEsp()
    local playerEspEnabled = State.npc_player_esp
    local beastEspEnabled = State.npc_beast_esp
    local tracersEnabled = State.show_tracers
    if not playerEspEnabled and not beastEspEnabled and not tracersEnabled then
        FullCleanupBucket("npc")
        for k, t in pairs(TracerObjects) do
            if t and t.Remove then pcall(function() t:Remove() end) end
            TracerObjects[k] = nil
        end
        ActiveTracerKeys = {}
        return
    end
    local localCharacter = LocalPlayer and LocalPlayer.Character or nil
    local seen = {}; local seenTracers = {}
    local cam = workspace.CurrentCamera
    local camPos = cam and cam.CFrame.Position or Vector3.new(0, 0, 0)
    local targets = GetFtfCharacterTargets()
    RefreshPlayerProgressCache(false)
    local vpSize = (cam and cam.ViewportSize) or Vector2.new(1920, 1080)
    local tracerOriginX = vpSize.X / 2
    local tracerOriginY = 0
    for i = 1, #targets do
        local obj = targets[i]
        local isLocalModel = obj == localCharacter or (LocalPlayer and tostring(obj.Name) == tostring(LocalPlayer.Name))
        if not isLocalModel then
            local meta = FtfCharacterMeta[obj]
            if meta then
                local isBeast = meta.isBeast
                local showEsp = (isBeast and beastEspEnabled) or ((not isBeast) and playerEspEnabled)
                local showTracer = tracersEnabled and not isBeast
                if showEsp or showTracer then
                    local root = meta.root; local head = meta.head
                    if root and head and cam then
                        local hp, hv = GetWorldToScreen(head.Position + Vector3.new(0, 0.6, 0))
                        local fp, fv = GetWorldToScreen(root.Position - Vector3.new(0, 3.2, 0))
                        if hv and fv and hp and fp then
                            local key = tostring(obj)
                            local e = GetEspEntry(key)
                            seen[key] = true
                            ActiveEspKeys.npc[key] = true
                            local bh = math.max(36, math.abs(fp.Y - hp.Y) * 1.25)
                            local bw = math.max(22, math.floor(bh * 0.62))
                            local bx = math.floor(hp.X - bw / 2)
                            local by = math.floor(hp.Y)
                            local espColor = isBeast and Color3.fromRGB(255, 88, 88) or Color3.fromRGB(54, 248, 87)
                            if showEsp and State.show_boxes then
                                e.box.Position = Vector2.new(bx, by); e.box.Size = Vector2.new(bw, bh)
                                e.box.Color = espColor; e.box.Thickness = isBeast and 1 or 2; e.box.Visible = true
                            else e.box.Visible = false end
                            if showTracer then
                                local tracerKey = "tr:" .. key
                                local tr = GetTracerEntry(tracerKey)
                                seenTracers[tracerKey] = true; ActiveTracerKeys[tracerKey] = true
                                tr.From = Vector2.new(tracerOriginX, tracerOriginY)
                                tr.To = Vector2.new(bx + bw / 2, by)
                                tr.Color = Color3.fromRGB(80, 255, 80); tr.Thickness = 3
                                tr.Transparency = 1; tr.ZIndex = 999; tr.Visible = true
                            else
                                local tracerKey = "tr:" .. key
                                local tr = TracerObjects[tracerKey]
                                if tr then HideTracerEntry(tr) end
                                ActiveTracerKeys[tracerKey] = nil
                            end
                            if showEsp then
                                if isBeast then
                                    local pName, pPct = GetBeastPowerInfo(obj)
                                    local pColor = GetPowerColor(pName, pPct)
                                    local displayText = ""
                                    if State.show_power_name and pName and pName ~= "Unknown" then displayText = pName end
                                    if State.show_beast_label and displayText ~= "" then displayText = displayText .. " | " .. (obj.Name or "Beast")
                                    elseif State.show_beast_label then displayText = obj.Name or "Beast" end
                                    if State.show_distance then
                                        local d = math.floor((camPos - root.Position).Magnitude)
                                        displayText = (displayText ~= "" and (displayText .. " [" .. d .. "m]")) or ("[" .. d .. "m]")
                                    end
                                    if State.player_show_state and meta.player then
                                        local stateText, stateColor = GetPlayerState(meta.player)
                                        if stateText then
                                            displayText = displayText .. " [" .. stateText .. "]"
                                            if State.player_state_color and stateColor then pColor = stateColor end
                                        end
                                    end
                                    if displayText ~= "" then
                                        e.label.Text = displayText
                                        e.label.Position = Vector2.new(math.floor(hp.X), math.floor(by - 20))
                                        e.label.Color = pColor; e.label.Size = State.power_font_size; e.label.Visible = true
                                    else e.label.Visible = false end
                                    if State.show_power_bar then
                                        local barY = by + bh + 4
                                        local barW = math.max(20, math.floor(bw * (State.bar_width / 100)))
                                        local barH = math.max(4, State.bar_height)
                                        local barX = math.floor(hp.X - barW / 2)
                                        e.barBg.Position = Vector2.new(barX, barY); e.barBg.Size = Vector2.new(barW, barH)
                                        e.barBg.Color = Color3.fromRGB(20, 20, 25); e.barBg.Transparency = 0.2; e.barBg.Visible = true
                                        local fw = math.max(1, math.floor(barW * math.clamp(pPct, 0, 1)))
                                        local fc = pPct >= 0.95 and Color3.fromRGB(0,255,50) or (pPct > 0 and Color3.fromRGB(255,180,0) or Color3.fromRGB(100,100,100))
                                        e.barFill.Position = Vector2.new(barX, barY); e.barFill.Size = Vector2.new(fw, barH)
                                        e.barFill.Color = fc; e.barFill.Transparency = 0.4; e.barFill.Visible = true
                                        e.borderBar.Position = Vector2.new(barX - 1, barY - 1); e.borderBar.Size = Vector2.new(barW + 2, barH + 2)
                                        e.borderBar.Color = Color3.fromRGB(255, 255, 255); e.borderBar.Transparency = 0.5
                                        e.borderBar.Thickness = 1; e.borderBar.Visible = true
                                        if State.show_power_percent then
                                            e.percentLabel.Text = string.format("%.0f%%", pPct * 100)
                                            e.percentLabel.Position = Vector2.new(math.floor(hp.X), math.floor(barY + barH + 10))
                                            e.percentLabel.Color = Color3.fromRGB(255, 255, 255)
                                            e.percentLabel.Size = math.max(13, State.power_font_size - 1); e.percentLabel.Visible = true
                                        else e.percentLabel.Visible = false end
                                    else
                                        e.barBg.Visible = false; e.barFill.Visible = false
                                        e.percentLabel.Visible = false; e.borderBar.Visible = false
                                    end
                                else
                                    local player = meta.player
                                    local playerProgress = player and GetPlayerProgress(player) or 0
                                    if State.show_labels then
                                        local text = obj.Name or "NPC"
                                        if State.show_distance then
                                            local d = math.floor((camPos - root.Position).Magnitude)
                                            text = text .. " [" .. d .. "m]"
                                        end
                                        if State.player_show_state and player then
                                            local stateText, stateColor = GetPlayerState(player)
                                            if stateText then
                                                text = text .. " [" .. stateText .. "]"
                                                if State.player_state_color and stateColor then e.label.Color = stateColor
                                                else e.label.Color = espColor end
                                            else e.label.Color = espColor end
                                        else e.label.Color = espColor end
                                        e.label.Text = text
                                        e.label.Position = Vector2.new(math.floor(hp.X), math.floor(by - 16))
                                        e.label.Size = 14; e.label.Visible = true
                                    else e.label.Visible = false end
                                    if State.show_player_progress then
                                        local pBarY = by + bh + 4
                                        local pBarW = math.max(20, math.floor(bw * 1.2))
                                        local pBarH = math.max(4, State.bar_height)
                                        local pBarX = math.floor(hp.X - pBarW / 2)
                                        local pProg = math.clamp(playerProgress, 0, 1)
                                        e.barBg.Position = Vector2.new(pBarX, pBarY)
                                        e.barBg.Size = Vector2.new(pBarW, pBarH)
                                        e.barBg.Color = Color3.fromRGB(20, 20, 25)
                                        e.barBg.Transparency = 0.2
                                        e.barBg.Visible = true
                                        local pFill = math.max(2, math.floor(pBarW * pProg))
                                        local pCol
                                        if pProg >= 0.95 then pCol = Color3.fromRGB(0, 255, 50)
                                        elseif pProg > 0.5 then pCol = Color3.fromRGB(255, 180, 0)
                                        elseif pProg > 0 then pCol = Color3.fromRGB(255, 100, 100)
                                        else pCol = Color3.fromRGB(60, 60, 60); pFill = 2 end
                                        e.barFill.Position = Vector2.new(pBarX, pBarY)
                                        e.barFill.Size = Vector2.new(pFill, pBarH)
                                        e.barFill.Color = pCol
                                        e.barFill.Transparency = 0.4
                                        e.barFill.Visible = true
                                        e.borderBar.Position = Vector2.new(pBarX - 1, pBarY - 1)
                                        e.borderBar.Size = Vector2.new(pBarW + 2, pBarH + 2)
                                        e.borderBar.Color = Color3.fromRGB(255, 255, 255)
                                        e.borderBar.Transparency = 0.5
                                        e.borderBar.Thickness = 1
                                        e.borderBar.Visible = true
                                        e.percentLabel.Text = (pProg >= 1) and "DONE" or string.format("%.0f%%", pProg * 100)
                                        e.percentLabel.Position = Vector2.new(math.floor(hp.X), math.floor(pBarY + pBarH + 10))
                                        e.percentLabel.Color = pProg > 0 and Color3.fromRGB(255,255,255) or Color3.fromRGB(100,100,100)
                                        e.percentLabel.Size = 13
                                        e.percentLabel.Visible = true
                                    else
                                        e.barBg.Visible = false
                                        e.barFill.Visible = false
                                        e.percentLabel.Visible = false
                                        e.borderBar.Visible = false
                                    end
                                end
                            else
                                e.label.Visible = false; e.barBg.Visible = false; e.barFill.Visible = false
                                e.percentLabel.Visible = false; e.borderBar.Visible = false
                            end
                        else
                            local key = tostring(obj)
                            local e = EspObjects[key]
                            if e then HideEspEntry(e) end
                            ActiveEspKeys.npc[key] = nil
                            local tkey = "tr:" .. key
                            local tr = TracerObjects[tkey]
                            if tr then HideTracerEntry(tr) end
                            ActiveTracerKeys[tkey] = nil
                        end
                    end
                else
                    local key = tostring(obj)
                    local existing = EspObjects[key]
                    if existing then HideEspEntry(existing) end
                    local tkey = "tr:" .. key
                    local tr = TracerObjects[tkey]
                    if tr then HideTracerEntry(tr) end
                    ActiveTracerKeys[tkey] = nil
                end
            end
        end
    end
    for key, e in pairs(EspObjects or {}) do
        if ActiveEspKeys.npc[key] and not seen[key] then
            HideEspEntry(e); ActiveEspKeys.npc[key] = nil
        end
    end
    for tkey, _ in pairs(ActiveTracerKeys) do
        if not seenTracers[tkey] then
            local tr = TracerObjects[tkey]
            if tr then HideTracerEntry(tr) end
            ActiveTracerKeys[tkey] = nil
        end
    end
end

-- ============================================================================
-- COMPUTER ESP
-- ============================================================================
local function GetComputerProgressKey(trigger)
    if not trigger then return nil end
    local addr = nil; pcall(function() addr = trigger.Address end)
    if addr ~= nil then return "pcaddr:" .. tostring(addr) end
    local full = nil; pcall(function() full = trigger:GetFullName() end)
    if full then return "pcname:" .. tostring(full) end
    return "pcobj:" .. tostring(trigger)
end

local function UpdateComputerEsp()
    if not State.pc_esp then
        FullCleanupBucket("pc")
        return
    end
    local seen = {}
    local targets = ComputerCache
    local cam = workspace.CurrentCamera
    local camPos = cam and cam.CFrame.Position or Vector3.new(0, 0, 0)
    if ComputerProgressMap ~= CurrentMapRoot then
        ComputerProgressCache = {}; ComputerHackerCache = {}; ComputerProgressMap = CurrentMapRoot
    end
    RefreshPlayerProgressCache(false)
    local pcAssignment = {}
    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if char and char:IsDescendantOf(workspace) then
            local meta = FtfCharacterMeta[char]
            local isBeast = meta and meta.isBeast or false
            local rootPart = meta and meta.root or char:FindFirstChild("HumanoidRootPart")
            if rootPart and not isBeast then
                local raw = GetPlayerProgress(player)
                if raw > 0 then
                    local playerPos = rootPart.Position
                    local bestIdx, bestDist = nil, math.huge
                    for idx = 1, #targets do
                        local comp = targets[idx]
                        if comp and comp:IsDescendantOf(workspace) then
                            local anchor = ComputerAnchorCache[comp]
                            if anchor then
                                local d = (playerPos - anchor.Position).Magnitude
                                if d < bestDist and d <= 8 then bestDist = d; bestIdx = idx end
                            end
                        end
                    end
                    if bestIdx then
                        local ex = pcAssignment[bestIdx]
                        if not ex or bestDist < ex.dist then
                            pcAssignment[bestIdx] = { player = player, raw = raw, dist = bestDist }
                        end
                    end
                end
            end
        end
    end
    for index = 1, #targets do
        local trigger = targets[index]
        if trigger and trigger.Parent and trigger:IsDescendantOf(workspace) then
            local pcKey = GetComputerProgressKey(trigger) or tostring(index)
            local key = "pc:" .. tostring(pcKey)
            local e = GetEspEntry(key)
            local sp, vis = GetWorldToScreen(trigger.Position + Vector3.new(0, 1.5, 0))
            seen[key] = true; ActiveEspKeys.pc[key] = true
            local assign = pcAssignment[index]
            local currentRaw = assign and assign.raw or 0
            local currentHackerName = assign and assign.player.Name or nil
            local saved = ComputerProgressCache[pcKey] or 0
            local lastHacker = ComputerHackerCache[pcKey]
            if assign then
                if currentRaw > saved then saved = currentRaw; ComputerProgressCache[pcKey] = saved end
                ComputerHackerCache[pcKey] = assign.player.Name
            end
            local screenState = GetComputerScreenState(trigger.Color)
            if screenState == "done" then saved = 1; ComputerProgressCache[pcKey] = 1 end
            if State.hide_completed_pcs and saved >= 1 then
                HideEspEntry(e); ActiveEspKeys.pc[key] = nil; seen[key] = nil
            else
                local pos = trigger.Position
                if IsTooFar(camPos, pos) then HideEspEntry(e)
                else
                    if vis and sp then
                        local w, h = 30, 30
                        local bx = math.floor(sp.X - w / 2)
                        local by = math.floor(sp.Y - h / 2)
                        local sc = trigger.Color
                        local r, g, b = sc.R, sc.G, sc.B
                        if r <= 1 and g <= 1 and b <= 1 then
                            r = math.floor(r * 255 + 0.5); g = math.floor(g * 255 + 0.5); b = math.floor(b * 255 + 0.5)
                        else
                            r = math.floor(r + 0.5); g = math.floor(g + 0.5); b = math.floor(b + 0.5)
                        end
                        local labelText = "PC"
                        local espColor = Color3.fromRGB(r, g, b)
                        if r == 196 and g == 40 and b == 28 then
                            labelText = "PC Errored"; espColor = Color3.fromRGB(255, 50, 50)
                        end
                        local hackerName = currentHackerName or lastHacker
                        e.box.Position = Vector2.new(bx, by); e.box.Size = Vector2.new(w, h)
                        e.box.Color = espColor; e.box.Visible = true
                        if State.show_labels then
                            if screenState == "done" then
                                e.label.Text = "PC (HACKED)"; e.label.Color = Color3.fromRGB(0, 255, 80)
                            elseif hackerName then
                                local nm = hackerName
                                if #nm > 8 then nm = string.sub(nm, 1, 6) .. ".." end
                                e.label.Text = labelText .. " (" .. nm .. ")"; e.label.Color = espColor
                            else
                                e.label.Text = labelText .. " (IDLE)"; e.label.Color = Color3.fromRGB(150, 150, 150)
                            end
                            e.label.Position = Vector2.new(math.floor(sp.X), math.floor(by - 15)); e.label.Visible = true
                        else e.label.Visible = false end
                        if State.show_player_progress then
                            local barY = by + h + 4
                            local barW = math.max(20, math.floor(w * (State.bar_width / 100)))
                            local barH = math.max(4, State.bar_height)
                            local barX = math.floor(sp.X - barW / 2)
                            e.barBg.Position = Vector2.new(barX, barY); e.barBg.Size = Vector2.new(barW, barH)
                            e.barBg.Color = Color3.fromRGB(20, 20, 25); e.barBg.Transparency = 0.2; e.barBg.Visible = true
                            local fw = math.max(2, math.floor(barW * math.clamp(saved, 0, 1)))
                            local fc
                            if saved >= 0.95 then fc = Color3.fromRGB(0, 255, 50)
                            elseif saved > 0.5 then fc = Color3.fromRGB(255, 180, 0)
                            elseif saved > 0 then fc = Color3.fromRGB(255, 100, 100)
                            else fc = Color3.fromRGB(60, 60, 60) end
                            e.barFill.Position = Vector2.new(barX, barY); e.barFill.Size = Vector2.new(fw, barH)
                            e.barFill.Color = fc; e.barFill.Transparency = 0.4; e.barFill.Visible = true
                            e.borderBar.Position = Vector2.new(barX - 1, barY - 1); e.borderBar.Size = Vector2.new(barW + 2, barH + 2)
                            e.borderBar.Color = Color3.fromRGB(255, 255, 255); e.borderBar.Transparency = 0.5
                            e.borderBar.Thickness = 1; e.borderBar.Visible = true
                            local percentText
                            if saved >= 1 then percentText = "DONE"
                            else
                                percentText = string.format("%.0f%%", saved * 100)
                                local displayHacker = currentHackerName or lastHacker
                                if displayHacker then
                                    local nm = displayHacker
                                    if #nm > 10 then nm = string.sub(nm, 1, 8) .. ".." end
                                    percentText = nm .. " " .. percentText
                                end
                            end
                            e.percentLabel.Text = percentText
                            e.percentLabel.Position = Vector2.new(math.floor(sp.X), math.floor(barY + barH + 10))
                            e.percentLabel.Color = Color3.fromRGB(255, 255, 255)
                            e.percentLabel.Size = 13; e.percentLabel.Visible = true
                        else
                            e.barBg.Visible = false; e.barFill.Visible = false
                            e.percentLabel.Visible = false; e.borderBar.Visible = false
                        end
                    else HideEspEntry(e) end
                end
            end
        end
    end
    CleanupTrackedEspKeys("pc", seen)
end

-- ============================================================================
-- UI SETUP
-- ============================================================================
local EspTab = UI:AddTab({ Title = "ESP", Icon = "script" })
local BeastTab = UI:AddTab({ Title = "Beast", Icon = "script" })

EspTab:AddToggle({ Id = "windy_player_esp", Title = "Player ESP", Default = false, Callback = function(v) State.npc_player_esp = v end })
EspTab:AddToggle({ Id = "windy_beast_esp", Title = "Beast ESP", Default = false, Callback = function(v) State.npc_beast_esp = v end })
EspTab:AddToggle({ Id = "windy_show_state", Title = "Show Player State", Default = true, Callback = function(v) State.player_show_state = v end })
EspTab:AddToggle({ Id = "windy_state_colors", Title = "State Colors", Default = true, Callback = function(v) State.player_state_color = v end })
EspTab:AddToggle({ Id = "windy_tracers", Title = "Player Tracers", Default = false, Callback = function(v) State.show_tracers = v end })
EspTab:AddToggle({ Id = "windy_ragdoll_tracker", Title = "Ragdoll Tracker", Default = false, Callback = function(v) RagdollTracker.visible = v end })
EspTab:AddToggle({ Id = "windy_pc_esp", Title = "PC ESP", Default = false, Callback = function(v) State.pc_esp = v end })
EspTab:AddToggle({ Id = "windy_hide_done_pcs", Title = "Hide Completed PCs", Default = false, Callback = function(v) State.hide_completed_pcs = v end })
EspTab:AddToggle({ Id = "windy_freeze_pod", Title = "Freeze Pod ESP", Default = false, Callback = function(v) State.freeze_pod_esp = v end })
EspTab:AddToggle({ Id = "windy_door_esp", Title = "Door ESP", Default = false, Callback = function(v) State.exit_door_esp = v end })
EspTab:AddToggle({ Id = "windy_only_open_doors", Title = "Only Show Open Doors", Default = false, Callback = function(v) State.door_only_open = v end })
EspTab:AddToggle({ Id = "windy_door_state", Title = "Show Open/Closed State", Default = true, Callback = function(v) State.door_show_state = v end })
EspTab:AddToggle({ Id = "windy_show_boxes", Title = "Show Boxes", Default = true, Callback = function(v) State.show_boxes = v end })
EspTab:AddToggle({ Id = "windy_show_labels", Title = "Show Labels", Default = true, Callback = function(v) State.show_labels = v end })
EspTab:AddToggle({ Id = "windy_show_distance", Title = "Show Distance", Default = false, Callback = function(v) State.show_distance = v end })
EspTab:AddToggle({ Id = "windy_player_progress", Title = "Player Progress Bars", Default = true, Callback = function(v) State.show_player_progress = v end })

BeastTab:AddToggle({ Id = "windy_power_name", Title = "Power Name", Default = true, Callback = function(v) State.show_power_name = v end })
BeastTab:AddToggle({ Id = "windy_power_bar", Title = "Power Bar", Default = true, Callback = function(v) State.show_power_bar = v end })
BeastTab:AddToggle({ Id = "windy_power_percent", Title = "Power Percent", Default = true, Callback = function(v) State.show_power_percent = v end })
BeastTab:AddToggle({ Id = "windy_beast_label", Title = "Beast Label", Default = true, Callback = function(v) State.show_beast_label = v end })
BeastTab:AddSlider({ Id = "windy_bar_height", Title = "Bar Height", Min = 3, Max = 12, Step = 1, Default = 6, Callback = function(v) State.bar_height = v end })
BeastTab:AddSlider({ Id = "windy_bar_width", Title = "Bar Width", Min = 80, Max = 150, Step = 5, Default = 100, Callback = function(v) State.bar_width = v end })
BeastTab:AddSlider({ Id = "windy_power_font", Title = "Power Font Size", Min = 10, Max = 24, Step = 1, Default = 16, Callback = function(v) State.power_font_size = v end })

EspTab:Select()

local LastFrameTick = 0
local MinUpdateDelta = 1 / 60

RunService.RenderStepped:Connect(function(dt)
    if not State.isRunning then return end
    local now = tick()
    local lastTick = LastFrameTick
    if lastTick > 0 and (now - lastTick) < MinUpdateDelta then return end
    if lastTick > 0 then dt = now - lastTick end
    LastFrameTick = now

    pcall(CheckForMapChange)
    pcall(PollRagdollTracker)
    pcall(RenderRagdollTracker)

    if State.npc_player_esp or State.npc_beast_esp or State.show_tracers then
        pcall(UpdateNpcEsp)
    elseif next(ActiveEspKeys.npc) ~= nil then
        pcall(function()
            FullCleanupBucket("npc")
            for k, t in pairs(TracerObjects) do
                if t and t.Remove then pcall(function() t:Remove() end) end
                TracerObjects[k] = nil
            end
            ActiveTracerKeys = {}
        end)
    end

    if State.pc_esp then
        pcall(UpdateComputerEsp)
    elseif next(ActiveEspKeys.pc) ~= nil then
        pcall(function() FullCleanupBucket("pc") end)
    end

    if State.freeze_pod_esp then
        pcall(UpdateFreezePodEsp)
    elseif next(ActiveEspKeys.fp) ~= nil then
        pcall(function() FullCleanupBucket("fp") end)
    end

    if State.exit_door_esp then
        pcall(UpdateDoorEsp)
    elseif next(ActiveEspKeys.sd) ~= nil or next(ActiveEspKeys.dd) ~= nil
        or next(ActiveEspKeys.dw) ~= nil or next(ActiveEspKeys.ed) ~= nil then
        pcall(function()
            for _, key in ipairs({ "sd", "dd", "dw", "ed" }) do
                FullCleanupBucket(key)
            end
        end)
    end
end)

UI:Notify({
    Title = "Windy ESP v1.9.7",
    Content = "Loaded. Doors fixed.",
    Type = "success",
    Duration = 4,
})
