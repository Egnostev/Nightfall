--[[
    Violence District Hub v3 | io-lib (MacLib fork) edition
    gitbook: io-lib | real executor
    Loader (one line, loads maclib from GitHub):
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Egnostev/Nightfall/main/VDHub_io.luau", true))()
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- ============ unload previous ============
if getgenv and type(getgenv().VDHubIO_Unload) == "function" then
    pcall(getgenv().VDHubIO_Unload)
end
local alive = true

-- ============ io-lib load (per gitbook getting-started) ============
-- Maclib is fetched from GitHub; local readfile("maclib.lua") kept as fallback.
local MACLIB_URL = "https://raw.githubusercontent.com/Egnostev/Nightfall/main/maclib.lua"
local function fetchMacLib()
    -- 1) fresh download from GitHub (noCache)
    local ok, src = pcall(function() return game:HttpGet(MACLIB_URL, true) end)
    if ok and type(src) == "string" and #src > 1000 then
        pcall(writefile, "maclib.lua", src) -- cache locally for offline/fallback
        local lib = loadstring(src)()
        if lib then return lib end
    end
    -- 2) previously cached local copy
    local ok2, localSrc = pcall(readfile, "maclib.lua")
    if ok2 and type(localSrc) == "string" and #localSrc > 1000 then
        local lib = loadstring(localSrc)()
        if lib then return lib end
    end
    error("[VDHub_io] failed to load maclib.lua from GitHub or local cache")
end
local MacLib = fetchMacLib()
MacLib:SetFolder("VDHub_io")

local Window = MacLib:Window({
    Title = "Violence District",
    Subtitle = "v3 io-lib",
    Size = UDim2.fromOffset(860, 560),
    DragStyle = 1,
    ShowUserInfo = true,
    Keybind = Enum.KeyCode.RightShift,
    AcrylicBlur = true,
})
Window:GlobalSetting({
    Name = "Notifications",
    Default = true,
    Callback = function(state) Window:SetNotificationsState(state) end,
})

local tabs = Window:TabGroup()
local tCombat  = tabs:Tab({ Name = "Combat", Icon = "bolt" })
local tKiller  = tabs:Tab({ Name = "Killer", Icon = "eye" })
local tESP     = tabs:Tab({ Name = "ESP", Icon = "lens" })
local tMove    = tabs:Tab({ Name = "Move", Icon = "code" })
local tVisual  = tabs:Tab({ Name = "Visual", Icon = "sun" })
local tTele    = tabs:Tab({ Name = "Teleport", Icon = "folder" })
local tMisc    = tabs:Tab({ Name = "Misc", Icon = "sliders" })
local tAnim    = tabs:Tab({ Name = "Anim", Icon = "user" })
local tConfig  = tabs:Tab({ Name = "Config", Icon = "sliders" })

-- ============ STATE ============
local S = {
    Parry = { Enabled=false, Dist=18, Humanize=0.05, Visual=true },
    Skill = { Enabled=false, Lead=1.5, Debug=true },
    Moonwalk = { Enabled=false, Mode="Classic", Smooth=16 },
    Dagger = { SpinBack=true, Speed=1.5 },
    Crouch = { Enabled=false, Radius=20 },
    VaultMod = { Enabled=false, AnyAngle=true, AnySpeed=true, AlwaysFast=false, Finesse=false },
    -- Tidal ports (strict list)
    FloatMod = { Enabled=false, Method="Part", UpOffset=0, DownOffset=0, Color=Color3.fromRGB(163,162,165), UpSpeed=20, DownSpeed=20, UpKey=Enum.KeyCode.E, DownKey=Enum.KeyCode.Q },
    SpiderMod = { Speed=20, Radius=2.5, MaxAngleDeg=10, Method="Velocity", ResetVel=false },
    FreecamAdv = { Speed=1, ShiftMult=2, Sens=1, Limits=true },
    CapeMod = { Enabled=false, Texture="rbxassetid://14637958134" },
    AnimMod = { Speed=1, UseMulti=false, Multi=1, DanceR6="Dance", DanceR15="River Dance",
        BangSpeed=1, HeadThrowSpeed=1, JerkSpeed=1, OrbitSpeed=45, OrbitDist=5 },
    NoSlowdown = false,
    Heal = { Auto=false },
    AutoGen = { Enabled=false },
    Dodger = { Enabled=false, Radius=22 },
    KillerTools = { NoCD=false, AutoBreak=false, IgnoreFlash=false, NoStun=false }, -- AutoCarry/AutoHook removed: never read by any loop (dead state)
    ESP = {
        MaxDist=5000,
        Killer={Enabled=false, Name=true, Dist=true, Aura=false, AuraColor=Color3.fromRGB(255,0,0), Tracer=false, TracerColor=Color3.fromRGB(255,0,0)},
        Survivor={Enabled=false, Name=true, Dist=true, Status=true, Aura=false, AuraColor=Color3.fromRGB(0,255,0), Tracer=false, TracerColor=Color3.fromRGB(0,255,0)},
        Generator={Enabled=false, Dist=true, Color=Color3.fromRGB(255,200,0), Tracer=false, Cham=false},
        Pallet={Enabled=false, Dist=true, Color=Color3.fromRGB(0,170,255), Tracer=false, Cham=false},
        Vault={Enabled=false, Dist=true, Color=Color3.fromRGB(180,140,255), Tracer=false, Cham=false},
        Hook={Enabled=false, Dist=true, Color=Color3.fromRGB(255,0,0), Tracer=false, Cham=false},
        Gate={Enabled=false, Dist=true, Color=Color3.fromRGB(0,255,140), Tracer=false, Cham=false},
        Locker={Cham=false, Color=Color3.fromRGB(140,140,140)}, -- cham only (no ESP toggle yet)
    },
    Move = { Speed=false, SpeedVal=1.3, Noclip=false, Fly=false, FlySpeed=60, Jump=false, JumpPower=50, Spider=false, Fov=70, FovOn=false },
    Visual = { Fullbright=false, NoFog=false, AntiAFK=false, AntiFling=false, Freecam=false, CameraPhase=false },
    Cursor = { Unlock=true },
    TeleNoclipPallets = false, -- UI-only placeholder (feature not implemented)
}

-- ============ HELPERS (real executor safe) ============
local function hrpOf(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
end
local function headOf(char)
    if not char then return nil end
    return char:FindFirstChild("Head")
end
local function humOf(char)
    if not char then return nil end
    return char:FindFirstChildOfClass("Humanoid")
end
local function teamOf(plr)
    if plr and plr.Team then return plr.Team.Name end
    return "?"
end
local function isKiller(plr) return teamOf(plr) == "Killer" end
local function myHRP() return hrpOf(LocalPlayer.Character) end
local function w2v(pos)
    local v, on = Camera:WorldToViewportPoint(pos)
    return Vector2.new(v.X, v.Y), on
end
local function distTo(pos)
    local m = myHRP()
    if not m then return 1e9 end
    return (m.Position - pos).Magnitude
end
local function getRemote(path)
    local cur = ReplicatedStorage
    for part in string.gmatch(path, "[^%.]+") do
        cur = cur:FindFirstChild(part)
        if not cur then return nil end
    end
    return cur
end
local function fireRemote(path, ...)
    local args = {...}
    local r = typeof(path) == "Instance" and path or getRemote(path)
    if r and r:IsA("RemoteEvent") then
        pcall(function() r:FireServer(table.unpack(args)) end)
        return true
    end
    return false
end
local function survStatus(char, hum)
    if not char or not hum then return "?", Color3.fromRGB(255,255,255) end
    if char:GetAttribute("IsHooked") then return "Hooked", Color3.fromRGB(255,0,0) end
    if char:GetAttribute("IsCarried") then return "Carried", Color3.fromRGB(255,0,0) end
    if char:GetAttribute("Knocked") then return "Knocked", Color3.fromRGB(255,0,0) end
    if hum.Health <= hum.MaxHealth * 0.5 then return "Injured", Color3.fromRGB(255,255,0) end
    return "Healthy", Color3.fromRGB(0,255,0)
end
local function setAura(char, on, color)
    if not char then return end
    local h = char:FindFirstChildOfClass("Highlight")
    if on then
        if not h then
            h = Instance.new("Highlight")
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.FillTransparency = 0.6
            h.OutlineTransparency = 0
            h.Parent = char
        end
        h.FillColor = color
        h.Enabled = true
    elseif h then
        h.Enabled = false
    end
end
-- Chams for objects: one Highlight per model, cached
local chamCache = {}
local function setCham(model, on, color)
    if not model then return end
    local h = chamCache[model]
    if on then
        if not h or h.Parent == nil then
            h = Instance.new("Highlight")
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.FillTransparency = 0.55
            h.OutlineTransparency = 0
            h.Parent = model
            chamCache[model] = h
        else
            pcall(function() h.Parent = model end)
        end
        h.FillColor = color
        h.OutlineColor = color
        h.Enabled = true
        h.Adornee = model
    elseif h then
        h.Enabled = false
    end
end
local function clearChams()
    for m, h in pairs(chamCache) do
        pcall(function() h.Enabled = false end)
        if m == nil or m.Parent == nil then
            pcall(function() h:Destroy() end)
            chamCache[m] = nil
        end
    end
end
local function mapFolder(names)
    local map = Workspace:FindFirstChild("Map")
    if not map then return {} end
    if typeof(names) == "string" then names = {names} end
    for _, n in ipairs(names) do
        local f = map:FindFirstChild(n)
        if f then return f:GetChildren() end
    end
    return {}
end
local function notify(title, desc, style)
    pcall(function()
        Window:Notify({ Title = title, Description = desc, Style = style or "None", Lifetime = 3 })
    end)
end

-- ============ DRAW POOL ============
local pool = {}
local function clearPool(key)
    local p = pool[key]
    if p then for _, d in ipairs(p) do pcall(function() d:Remove() end) end end
    pool[key] = {}
end
local function clearAllDraw()
    for k in pairs(pool) do clearPool(k) end
end
local function push(key, d)
    pool[key] = pool[key] or {}
    table.insert(pool[key], d)
    return d
end
local function mk(key, cls, props)
    local d = Drawing.new(cls)
    for k, v in pairs(props or {}) do pcall(function() d[k] = v end) end
    d.Visible = true
    return push(key, d)
end

-- ============ ESP RENDER (single loop, no ghost boxes) ============
-- Auras are handled here too (they are an ESP visual). The old dead
-- `if not S.ESP.Master then return end` gate was removed: nothing ever set
-- Master to false, but it short-circuited the whole loop, so every ESP
-- toggle (players, auras, tracers, object labels) silently did nothing.
RunService:BindToRenderStep("VDHubIO_ESP", Enum.RenderPriority.Last.Value, function()
    if not alive then return end
    local my = myHRP()
    if not my then return end
    local camPos = Camera.CFrame.Position

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        local key = "plr_" .. plr.Name
        clearPool(key)
        local char = plr.Character or Workspace:FindFirstChild(plr.Name)
        local hrp = hrpOf(char)
        local hum = humOf(char)
        local head = headOf(char)
        if char then
            -- aura always managed
            if isKiller(plr) then setAura(char, S.ESP.Killer.Aura and S.ESP.Killer.Enabled, S.ESP.Killer.AuraColor)
            else setAura(char, S.ESP.Survivor.Aura and S.ESP.Survivor.Enabled, S.ESP.Survivor.AuraColor) end
        end
        if not hrp or not hum or hum.Health <= 0 then continue end
        local killer = isKiller(plr)
        local cfg = killer and S.ESP.Killer or S.ESP.Survivor
        if not cfg.Enabled then
            -- tracer lives inside the Enabled branch below; make sure a
            -- turned-off ESP never leaves its line behind
            clearPool(key)
            continue
        end
        local d = (hrp.Position - camPos).Magnitude
        if d > S.ESP.MaxDist then continue end
        local sp, on = w2v(hrp.Position)
        if not on then continue end
        local top = head and (w2v(head.Position + Vector3.new(0, 1.4, 0))) or sp - Vector2.new(0, 40)

        local parts = {}
        if cfg.Name then table.insert(parts, plr.Name) end
        if cfg.Dist then table.insert(parts, math.floor(d) .. "m") end
        if not killer and S.ESP.Survivor.Status then
            local txt = survStatus(char, hum)
            table.insert(parts, txt)
        end
        local txt = table.concat(parts, " | ")
        if txt == "" then txt = plr.Name end
        local tcol = killer and Color3.fromRGB(255,80,80) or select(2, survStatus(char, hum))
        local t = mk(key, "Text", { Text = txt, Size = 14, Center = true, Outline = true, Color = tcol })
        t.Position = Vector2.new(sp.X, top.Y - 7)
        if cfg.Tracer then
            local origin = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
            local l = mk(key, "Line", { Color = cfg.TracerColor, Thickness = 1, Transparency = 0 })
            l.From = origin
            l.To = sp
        end
    end

    local function drawList(key, models, label, color, showDist, tracerOn)
        clearPool("obj_" .. key)
        for _, m in ipairs(models) do
            local p = m:IsA("BasePart") and m or m:FindFirstChildWhichIsA("BasePart", true)
            if p then
                local d = (p.Position - camPos).Magnitude
                if d <= S.ESP.MaxDist then
                    local s, on = w2v(p.Position + Vector3.new(0, 2, 0))
                    if on then
                        local txt = label
                        if showDist then txt ..= " [" .. math.floor(d) .. "m]" end
                        local t = mk("obj_" .. key, "Text", { Text = txt, Size = 13, Center = true, Outline = true, Color = color })
                        t.Position = s
                        if tracerOn then
                            local l = mk("obj_" .. key, "Line", { Color = color, Thickness = 1, Transparency = 0.4 })
                            l.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                            l.To = s
                        end
                    end
                end
            end
        end
    end

    local E = S.ESP
    if E.Generator.Enabled then drawList("gen", mapFolder({"Generators","Gens"}), "GEN", E.Generator.Color, E.Generator.Dist, E.Generator.Tracer) else clearPool("obj_gen") end
    if E.Pallet.Enabled then
        local pals = {}
        local map = Workspace:FindFirstChild("Map")
        if map then for _, c in ipairs(map:GetChildren()) do if string.find(c.Name, "Pallet") then table.insert(pals, c) end end end
        drawList("pal", pals, "PALLET", E.Pallet.Color, E.Pallet.Dist, E.Pallet.Tracer)
    else clearPool("obj_pal") end
    if E.Vault.Enabled then
        local vs = {}
        local map = Workspace:FindFirstChild("Map")
        if map then for _, c in ipairs(map:GetChildren()) do if c.Name == "Window" then table.insert(vs, c) end end end
        drawList("vlt", vs, "WINDOW", E.Vault.Color, E.Vault.Dist, E.Vault.Tracer)
    else clearPool("obj_vlt") end
    if E.Hook.Enabled then
        local hs = {}
        local map = Workspace:FindFirstChild("Map")
        if map then for _, c in ipairs(map:GetChildren()) do if c.Name == "Hook" then table.insert(hs, c) end end end
        drawList("hk", hs, "HOOK", E.Hook.Color, E.Hook.Dist, E.Hook.Tracer)
    else clearPool("obj_hk") end
    if E.Gate.Enabled then
        local gs = {}
        local map = Workspace:FindFirstChild("Map")
        if map then for _, c in ipairs(map:GetChildren()) do if c.Name == "Gate" then table.insert(gs, c) end end end
        drawList("gt", gs, "GATE", E.Gate.Color, E.Gate.Dist, E.Gate.Tracer)
    else clearPool("obj_gt") end
end)

-- ============ CHAMS: independent Highlight loop (works with map folders + streaming) ============
-- Matches by name anywhere under Workspace (Map uses Gens/Pallets/Vaults/Hooks/Exit folders)
local function modelMatches(name)
    if string.find(name, "Generator") then return "Generator" end
    if string.find(name, "Pallet") then return "Pallet" end
    if name == "Window" then return "Vault" end
    if name == "Hook" then return "Hook" end
    if name == "Gate" or name == "Exit" or string.find(name, "Escape") then return "Gate" end
    if string.find(name, "Locker") then return "Locker" end
    return nil
end
local function chamColorFor(kind)
    local E = S.ESP
    if kind == "Generator" then return E.Generator.Color end
    if kind == "Pallet" then return E.Pallet.Color end
    if kind == "Vault" then return E.Vault.Color end
    if kind == "Hook" then return E.Hook.Color end
    if kind == "Gate" then return E.Gate.Color end
    return E.Locker.Color
end
local function chamOnFor(kind)
    local E = S.ESP
    if kind == "Generator" then return E.Generator.Cham end
    if kind == "Pallet" then return E.Pallet.Cham end
    if kind == "Vault" then return E.Vault.Cham end
    if kind == "Hook" then return E.Hook.Cham end
    if kind == "Gate" then return E.Gate.Cham end
    return E.Locker.Cham
end
task.spawn(function()
    while alive do
        task.wait(0.7)
        if not alive then break end
        pcall(function()
            local seen = {}
            for _, d in ipairs(Workspace:GetDescendants()) do
                if d:IsA("Model") then
                    local kind = modelMatches(d.Name)
                    if kind then
                        -- skip tiny prop copies: need a solid part
                        local solid = d:FindFirstChildWhichIsA("BasePart", true)
                        if solid and solid.Size.Magnitude >= 2 then
                            seen[d] = true
                            setCham(d, chamOnFor(kind) == true, chamColorFor(kind))
                        end
                    end
                end
            end
            -- turn off highlights whose model vanished / toggled off
            for m, h in pairs(chamCache) do
                if not seen[m] then
                    pcall(function() h.Enabled = false end)
                    if m.Parent == nil then
                        pcall(function() h:Destroy() end)
                        chamCache[m] = nil
                    end
                end
            end
        end)
    end
end)

-- ============ CURSOR: no custom cursor — native OS arrow only ============
-- Unlock mouse ONLY while menu open; always keep the system cursor visible.
local function menuOpen()
    local ok, st = pcall(function() return Window:GetState() end)
    return ok and st == true
end
RunService.RenderStepped:Connect(function()
    if not alive then return end
    if S.Cursor.Unlock and menuOpen() then
        pcall(function()
            if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
                UserInputService.MouseBehavior = Enum.MouseBehavior.Default
            end
        end)
    end
    -- restore the regular cursor whenever something else hid it (games/executors do);
    -- Freecam manages its own icon state while active, so leave it alone there
    if not S.Visual.Freecam then
        pcall(function()
            if not UserInputService.MouseIconEnabled then
                UserInputService.MouseIconEnabled = true
            end
        end)
    end
end)

-- ============ MOONWALK (rewritten): walk backward while facing forward ============
-- Why the old version failed in-game: it wrote hrp.CFrame directly on RenderStepped,
-- which fights the physics stepper and the game's own animation/motor60 system —
-- the character rubber-bands or snaps back to MoveDirection. This rewrite drives the
-- rotation through Humanoid.TwistC0 (the supported neck/torso twist channel that
-- Roblox's Animator blends with locomotion anims), so movement physics are untouched.
-- Modes: Classic (face camera, moonwalk any direction), Invert (W/S swapped),
-- Spin (continuous readable-only-to-you rotation). Position is NEVER modified.
local MW = { hookOK = nil, lastYaw = nil, restored = true }

local function mwGetController()
    local ok, pm = pcall(function()
        return require(LocalPlayer:FindFirstChildOfClass("PlayerScripts"):FindFirstChild("PlayerModule"))
    end)
    if not ok or type(pm) ~= "table" then return nil end
    local ctrl
    pcall(function() ctrl = pm:GetControls() end)
    if ctrl and typeof(ctrl) == "Instance" then return ctrl end
    return nil
end

-- One-time hook: force controller ResetVAE off so our TwistC0 isn't overwritten by VAE.
local function mwEnsureHook()
    if MW.hookOK ~= nil then return MW.hookOK end
    MW.hookOK = false
    local ctrl = mwGetController()
    if not ctrl then return false end
    pcall(function()
        if debug.getproperty(ctrl, "ResetVAE") then
            debug.setproperty(ctrl, "ResetVAE", false)
        end
    end)
    MW.hookOK = true
    return true
end

local function mwRestore()
    if MW.restored and not MW.hookOK then return end
    MW.restored = true
    MW.lastYaw = nil
    local char = LocalPlayer.Character
    local hum = char and humOf(char)
    if hum then
        pcall(function() hum.AutoRotate = true end)
        local torso = char:FindFirstChild("Torso")
        local neck = char:FindFirstChild("Neck")
        if torso and neck and neck:IsA("Motor6D") then
            pcall(function() torso.C0 = CFrame.new() end)
        end
        -- R15: reset waist/pelvis twist channels we may have touched
        for _, j in ipairs({ "RootJoint", "LowerTorso" }) do
            local part = char:FindFirstChild(j)
            if part and part:IsA("Motor6D") then pcall(function() part.C0 = CFrame.new() end) end
        end
    end
    -- restore inverted move function if active
    if MW.inverted then
        MW.inverted = false
        local ctrl = mwGetController()
        if ctrl then
            pcall(function()
                local moveFn = rawget(ctrl, "moveFunction") or debug.getproperty(ctrl, "moveFunction")
                if moveFn then
                    local orig = MW.origMoveFn
                    if orig then
                        pcall(function() ctrl.moveFunction = orig end)
                    end
                end
            end)
        end
    end
end

local function mwApply(dt)
    if not alive or not S.Moonwalk.Enabled then
        if MW.hookOK ~= nil then mwRestore() end
        return
    end
    local char = LocalPlayer.Character
    local hum = humOf(char)
    local hrp = hrpOf(char)
    if not hum or not hrp or hum.Health <= 0 then return end
    mwEnsureHook()
    MW.restored = false

    local mode = S.Moonwalk.Mode

    -- Invert mode: swap forward/back input, keep normal facing logic off
    if mode == "Invert" then
        if not MW.inverted then
            local ctrl = mwGetController()
            if ctrl then
                MW.origMoveFn = ctrl.moveFunction
                MW.inverted = true
                pcall(function()
                    ctrl.moveFunction = function(_, direction, relative)
                        if typeof(direction) == "Vector3" then
                            direction = -direction
                        end
                        MW.origMoveFn(ctrl, direction, relative)
                    end
                end)
            end
        end
        return
    elseif MW.inverted then
        mwRestore()
        MW.restored = false
    end

    local moving = hum.MoveDirection.Magnitude > 0.05
    if not moving then
        -- idle: let AutoRotate handle nothing; keep current yaw stable
        MW.lastYaw = nil
        return
    end

    pcall(function() hum.AutoRotate = false end)

    -- target yaw: face where the camera looks (Classic) or spin slowly (Spin)
    local targetYaw
    if mode == "Spin" then
        MW.spinAngle = (MW.spinAngle or hrp.Rotation.Y) + dt * 240
        targetYaw = MW.spinAngle
    else -- Classic: face camera forward even while moving opposite
        local look = Camera.CFrame.LookVector
        targetYaw = math.atan2(look.X, look.Z)
    end

    -- smooth toward target (prevents snap-fighting with the animator)
    local k = math.clamp(S.Moonwalk.Smooth * dt, 0, 1)
    if MW.lastYaw then
        local d = ((targetYaw - MW.lastYaw + math.pi) % (math.pi * 2)) - math.pi
        targetYaw = MW.lastYaw + d * k
    end
    MW.lastYaw = targetYaw

    -- apply via TwistC0 (neck/torso yaw offset relative to animated facing)
    local hrpYaw = math.rad(hrp.Rotation.Y)
    local twist = ((targetYaw - hrpYaw + math.pi) % (math.pi * 2)) - math.pi
    pcall(function() hum.TwistC0 = CFrame.Angles(0, twist, 0) end)
end

RunService:BindToRenderStep("VDHubIO_Moonwalk", Enum.RenderPriority.Camera.Value + 1, function(dt)
    local ok, err = pcall(mwApply, dt)
    if not ok and not MW.warned then
        MW.warned = true
        warn("[VDHub] Moonwalk error: " .. tostring(err))
    end
end)

-- ============ TIDAL PORTS (strict list) ============
-- FastVaultModifier / Float / Spider / Freecam / CameraPhase /
-- GameplayPausedDisabler / Cape / Animations. Source: Tidal-Wave.
local T = { conns = {}, vault = {}, spiderConn = nil, floatPart = nil, floatAttach = nil,
    floatLV = nil, floatConns = {}, fc = {}, cape = {}, anims = {}, animSpd = nil }
local AnimCtrl = nil
local function getAnimCtrl()
    if AnimCtrl then return AnimCtrl end
    local ok, mod = pcall(require, ReplicatedStorage.Modules.Survivors.SurvivorAnimationsController)
    if ok and mod then AnimCtrl = mod return mod end
    return nil
end
local function trackConn(c)
    table.insert(T.conns, c)
    return c
end
local function resolveTarget(name)
    if not name or name == "" then return nil end
    local ln = string.lower(name)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and (p.Name == name or p.DisplayName == name) then
            return p
        end
    end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and (string.find(string.lower(p.Name), ln, 1, true)
            or string.find(string.lower(p.DisplayName), ln, 1, true)) then
            return p
        end
    end
    return nil
end
local function targetRoot(name)
    local p = resolveTarget(name)
    local hrp = p and hrpOf(p.Character)
    return hrp, p
end
-- ---- FastVaultModifier (Tidal): patch facing+speed checks, not run-up ----
local function setVaultAngle(on)
    local ctrl = getAnimCtrl()
    if not ctrl then notify("Vault", "no AnimController") return end
    if on then
        if not T.vault.oldFacing then
            T.vault.oldFacing = ctrl._isFacingStraightEnough
            ctrl._isFacingStraightEnough = function(_) return true end
        end
    elseif T.vault.oldFacing then
        ctrl._isFacingStraightEnough = T.vault.oldFacing
        T.vault.oldFacing = nil
    end
end
local function setVaultSpeed(on)
    local ctrl = getAnimCtrl()
    if not ctrl or not debug.setconstant then notify("Vault", "no debug") return end
    if on then
        if T.vault.speedSaved == nil then
            local ok, cur = pcall(debug.getconstant, ctrl._onVaultAnimation, 51)
            T.vault.speedSaved = (ok and cur ~= -1) and cur or false
            pcall(debug.setconstant, ctrl._onVaultAnimation, 51, -1)
        end
    else
        if T.vault.speedSaved then
            pcall(debug.setconstant, ctrl._onVaultAnimation, 51, T.vault.speedSaved)
        end
        T.vault.speedSaved = nil
    end
end
-- ---- ALWAYS FAST VAULT (ported from the Matcha external hub, internal port) ----
-- The current controller calls SurvivorVault.evaluate on recent movement samples,
-- then sends its chosen tier with the normal vault request. Its old 40-degree yaw
-- test is no longer the decision point. We relax the approach distance / pace /
-- direction rules in that module's constants table while enabled. Sprinting,
-- grounding, movement locks and the game's allowed-speed gate still apply.
-- External original patched these numbers through raw memory (findgc + applygc);
-- internally we reach the same live table through Real's GC API
-- (docs.projectreal.gg: environment/getgc -- tables need includeTables=true)
-- and write it with debug.setconstant semantics via direct field assignment.
local FV_ORIGINAL = {
    DISTANCE = 3, REPEAT_DISTANCE = 3.5, DOT = 0.7071067811865476,
    MIN_SPEED = 12.5, ARRIVE_GRACE = 0.12,
}
-- A vault can sample zero displacement immediately before its windup. A negative
-- pace threshold accepts that sample and keeps the sampler's distance / MIN_SPEED
-- history calculation finite (zero would make 0/0).
local FV_PATCH = { DISTANCE = 0, REPEAT_DISTANCE = 0, DOT = -1, MIN_SPEED = -1 }
local FV_KEYS = { "DISTANCE", "REPEAT_DISTANCE", "DOT", "MIN_SPEED" }
local fvStat = { status = "Disabled", ready = false, holding = false, vaults = 0, fast = 0, scans = 0 }
local fvCache, fvResolving, fvAttemptedFor = nil, false, nil
local fvFault, fvCharId, fvLastCount = nil, nil, nil

local function fvSame(a, b)
    return type(a) == "number" and a == a and type(b) == "number"
        and math.abs(a - b) <= math.max(1, math.abs(b)) * 0.000001
end

-- Internal equivalent of the external build's findgc(): returns candidate rows
-- { key = "DISTANCE", t = <live constants table> }. The live table is captured
-- (never copied), so writes through row.t[key] patch the module itself.
local FV_ALL_KEYS = { "DISTANCE", "REPEAT_DISTANCE", "DOT", "MIN_SPEED", "ARRIVE_GRACE" }
local function fvFindTables()
    local candidates, seen = {}, {}
    local function consider(t)
        if type(t) ~= "table" or seen[t] then return end
        for _, k in ipairs(FV_ALL_KEYS) do
            if type(rawget(t, k)) ~= "number" then return end
        end
        seen[t] = true
        candidates[#candidates + 1] = t
    end
    if filtergc then
        local ok, res = pcall(filtergc, "table", {
            DISTANCE = "number", REPEAT_DISTANCE = "number", DOT = "number",
            MIN_SPEED = "number", ARRIVE_GRACE = "number",
        })
        if ok and type(res) == "table" then
            for _, t in ipairs(res) do consider(t) end
        end
    end
    if #candidates == 0 and getgc then
        -- getgc only returns tables when includeTables is true (per Real docs)
        local ok, res = pcall(getgc, true)
        if ok and type(res) == "table" then
            for _, t in ipairs(res) do consider(t) end
        end
    end
    local rows = {}
    for _, t in ipairs(candidates) do
        for _, k in ipairs(FV_ALL_KEYS) do
            if rawget(t, k) == FV_ORIGINAL[k] then
                rows[#rows + 1] = { key = k, t = t }
                break
            end
        end
    end
    return rows
end

local function fvBuildCache(rows)
    if type(rows) ~= "table" or #rows ~= 5 then return nil, "Vault module not uniquely resolved" end
    local cache = { rows = rows, byKey = {}, originals = {}, written = {}, job = game.JobId }
    for _, row in ipairs(rows) do
        local key = row.key
        if type(row) ~= "table" or type(key) ~= "string" or type(row.t) ~= "table"
           or not FV_ORIGINAL[key] or cache.byKey[key] then
            return nil, "Unexpected vault table layout"
        end
        cache.byKey[key] = row
        local value = row.t[key]
        if not fvSame(value, FV_ORIGINAL[key]) then return nil, "Vault rules differ from this build" end
        cache.originals[key] = value
    end
    for key in pairs(FV_ORIGINAL) do
        if not cache.byKey[key] then return nil, "Incomplete vault table" end
    end
    return cache
end

local function fvSetKey(cache, key, value)
    local row = cache.byKey[key]
    local ok = pcall(function() row.t[key] = value end)
    if fvSame(row.t[key], value) then
        cache.written[key] = not fvSame(value, cache.originals[key])
    end
    return ok and fvSame(row.t[key], value)
end

local function fvHasWrites()
    if fvCache then
        for _, key in ipairs(FV_KEYS) do if fvCache.written[key] then return true end end
    end
    return false
end

local function fvRestore()
    if not fvHasWrites() then fvStat.holding = false return true end
    if fvCache.job ~= game.JobId then
        -- The old DataModel is gone. Never touch stale tables in a new game.
        fvCache, T.vault.cacheSeed = nil, nil
        fvStat.holding, fvStat.ready = false, false
        return true
    end
    if not fvSame(fvCache.byKey.ARRIVE_GRACE.t.ARRIVE_GRACE, fvCache.originals.ARRIVE_GRACE) then
        return false
    end
    local restored = true
    for _, key in ipairs(FV_KEYS) do
        if fvCache.written[key] then
            local current = fvCache.byKey[key].t[key]
            if fvSame(current, FV_PATCH[key]) then
                if not fvSetKey(fvCache, key, fvCache.originals[key]) then restored = false end
            elseif type(current) == "number" then
                -- The game or another script already replaced our value.
                fvCache.written[key] = false
            else
                restored = false
            end
        end
    end
    fvStat.holding = fvHasWrites()
    return restored and not fvStat.holding
end

local function fvApply()
    if not fvCache or fvCache.job ~= game.JobId then return false, "Rejoin detected; reload the hub" end
    if not fvSame(fvCache.byKey.ARRIVE_GRACE.t.ARRIVE_GRACE, fvCache.originals.ARRIVE_GRACE) then
        return false, "Vault cache needs refreshing"
    end
    for _, key in ipairs(FV_KEYS) do
        local value = fvCache.byKey[key].t[key]
        if not fvSame(value, fvCache.originals[key])
           and not (fvCache.written[key] and fvSame(value, FV_PATCH[key])) then
            return false, "Vault rules changed"
        end
    end
    for _, key in ipairs(FV_KEYS) do
        if not fvSame(fvCache.byKey[key].t[key], FV_PATCH[key]) then
            if not fvSetKey(fvCache, key, FV_PATCH[key]) then
                fvRestore()
                return false, "Could not apply vault rules"
            end
        end
    end
    return true
end

local function fvResolve(characterId)
    if fvResolving or fvAttemptedFor == characterId then return end
    fvResolving, fvAttemptedFor = true, characterId
    fvStat.status = "Resolving vault module"
    task.spawn(function()
        task.wait(0.35)
        if not alive or not S.VaultMod.AlwaysFast then
            fvResolving, fvAttemptedFor = false, nil
            return
        end
        local ok, cache, err = pcall(function()
            if T.vault.cacheSeed and T.vault.cacheSeed.job == game.JobId then
                local reused = fvBuildCache(T.vault.cacheSeed.rows)
                T.vault.cacheSeed = nil
                if reused then return reused end
            end
            -- A scan happens only on first enable, or after a failed resolve and
            -- a new character. A healthy cache survives ordinary respawns.
            fvStat.scans = fvStat.scans + 1
            return fvBuildCache(fvFindTables())
        end)
        fvResolving = false
        if not alive then return end
        if ok and cache then
            fvCache = cache
            T.vault.cacheSeed = { job = game.JobId, rows = cache.rows }
            fvStat.ready, fvStat.error = true, nil
        else
            fvStat.error = tostring(ok and err or cache)
            fvStat.status = "Waiting for survivor module"
        end
    end)
end

local function fvObserveVault()
    local ch = LocalPlayer.Character
    if not ch then return nil end
    local id = tostring(ch)
    if id ~= fvCharId then
        fvCharId, fvLastCount = id, nil
        fvStat.tier, fvStat.reason = nil, nil
    end
    local count = ch:GetAttribute("__VaultFireCount")
    local tier, reason = ch:GetAttribute("VaultTier"), ch:GetAttribute("VaultReason")
    if type(count) == "number" then
        if fvLastCount and count > fvLastCount then
            local delta = count - fvLastCount
            fvStat.vaults = fvStat.vaults + delta
            if tier == "fast" then fvStat.fast = fvStat.fast + delta end
        end
        fvLastCount = count
    end
    if type(tier) == "string" then fvStat.tier = tier end
    if type(reason) == "string" then fvStat.reason = reason end
    return id
end

task.spawn(function()
    while alive do
        local ok, err = pcall(function()
            local id = fvObserveVault()
            if not S.VaultMod.AlwaysFast then
                local restored = fvRestore()
                if restored then fvFault = nil end
                fvStat.status = restored and "Disabled" or "Restore pending: re-enable the toggle"
            elseif not fvCache then
                if id then fvResolve(id) else fvStat.status = "Waiting for character" end
            elseif fvFault then
                fvStat.status = fvFault
            else
                local applied, why = fvApply()
                fvStat.holding = applied
                fvStat.status = applied and "Ready - sprint to vault" or why
                fvStat.error = applied and nil or why
                if not applied then fvFault = why end
            end
        end)
        if not ok then
            fvStat.error, fvStat.status = tostring(err), "Retrying after read error"
        end
        task.wait(0.2)
    end
end)

local function applyVaultMaster()
    local on = S.VaultMod.Enabled
    setVaultAngle(on and S.VaultMod.AnyAngle)
    if not on then setVaultAngle(false) end
    setVaultSpeed(on and S.VaultMod.AnySpeed)
    if not on then setVaultSpeed(false) end
    if not S.VaultMod.AlwaysFast then
        pcall(fvRestore)
    end
end
local function setFinesse(on)
    if T.vault.finesseConn then pcall(function() T.vault.finesseConn:Disconnect() end) T.vault.finesseConn = nil end
    if not on then return end
    local function apply()
        local char = LocalPlayer.Character
        if not char then return end
        local db = false
        T.vault.finesseConn = char:GetAttributeChangedSignal("Flowstate"):Connect(function()
            if db then return end
            db = true
            pcall(function() char:SetAttribute("Flowstate", true) end)
            db = false
        end)
        pcall(function() char:SetAttribute("Flowstate", true) end)
    end
    apply()
    if not T.vault.finesseCharConn then
        T.vault.finesseCharConn = trackConn(LocalPlayer.CharacterAdded:Connect(function()
            task.wait(0.5)
            if S.VaultMod.Finesse then setFinesse(true) end
        end))
    end
end

-- ============ MOVEMENT LOOPS ============
-- Speed via attributes: game drives WalkSpeed from char Speed/speedboost attrs
local baseWalk, baseJump
local function applySpeed(char, hum)
    if not char or not hum then return end
    if baseWalk == nil or baseWalk <= 0 then baseWalk = (hum.WalkSpeed > 0 and hum.WalkSpeed or 16) end
    if S.Move.Speed then
        -- server does not validate: push both attribute and WalkSpeed
        pcall(function()
            char:SetAttribute("Speed", 16 * S.Move.SpeedVal)
            char:SetAttribute("speedboost", S.Move.SpeedVal)
            char:SetAttribute("swift", S.Move.SpeedVal)
        end)
        hum.WalkSpeed = 16 * S.Move.SpeedVal
    elseif S.NoSlowdown then
        pcall(function()
            char:SetAttribute("Speed", 18.7)
            char:SetAttribute("speedboost", 1)
        end)
        if hum.WalkSpeed < 16 then hum.WalkSpeed = 16 end
    else
        -- hands off: let game own WalkSpeed, just resync base
        baseWalk = hum.WalkSpeed > 0 and hum.WalkSpeed or baseWalk
    end
end
RunService.Heartbeat:Connect(function()
    if not alive then return end
    local char = LocalPlayer.Character
    local hum = humOf(char)
    local hrp = hrpOf(char)
    if not hum or not hrp then return end
    if baseJump == nil then baseJump = hum.JumpPower end

    applySpeed(char, hum)
    -- Jump (legit-style: only raise JumpPower, keep humanoid physics)
    if S.Move.Jump then hum.JumpPower = S.Move.JumpPower else if hum.JumpPower ~= baseJump then hum.JumpPower = baseWalk and baseJump or 50 end end
    -- FOV
    if S.Move.FovOn then pcall(function() Camera.FieldOfView = S.Move.Fov end) end
    -- Noclip
    if S.Move.Noclip and char then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
    -- (Spider: Tidal raycast loop in PreSimulation below)
    -- Moonwalk restore is handled entirely inside its own RenderStep (mwRestore)
    -- (FastVault: Tidal controller hooks, no run-up teleport)
    -- Auto crouch: fire Crouch remote when killer in radius
    if S.Crouch.Enabled then
        S.Crouch._t = (S.Crouch._t or 0) + 1
        for _, p in ipairs(Players:GetPlayers()) do
            if isKiller(p) and p.Character and hrpOf(p.Character) then
                if (hrpOf(p.Character).Position - hrp.Position).Magnitude <= S.Crouch.Radius then
                    fireRemote("Remotes.Mechanics.Crouch", true)
                    break
                end
            end
        end
    end
    -- Dodger: step aside when killer swings in radius
    if S.Dodger.Enabled then
        for _, p in ipairs(Players:GetPlayers()) do
            if isKiller(p) and p.Character and hrpOf(p.Character) then
                local kp = hrpOf(p.Character).Position
                if (kp - hrp.Position).Magnitude <= S.Dodger.Radius then
                    local side = (hrp.Position - kp).Unit + Vector3.new(0, 0.1, 0)
                    hrp.CFrame = hrp.CFrame + side * 2
                    break
                end
            end
        end
    end
    -- Auto heal / autogen ticks (throttled)
    S._tick = (S._tick or 0) + 1
    if S._tick % 6 == 0 then
        if S.Heal.Auto and hum.Health < hum.MaxHealth then
            fireRemote("Remotes.Healing.HealEvent", hrp, true)
        end
        if S.AutoGen.Enabled then
            -- never fight the player's own movement: pressing WASD = walk away first
            local moving = UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.A)
                or UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.D)
            local now = os.clock()
            -- pause windows (after skillcheck / watchdog / rest phase): full release
            if S._genPauseUntil and now < S._genPauseUntil then
                -- holding release, do nothing
            elseif not moving then
                local _, pt = currentRepairTarget(30) -- fixed 30-stud scan cap;
                -- hard 12-stud repair limit is enforced inside currentRepairTarget
                -- stop firing at finished/dead generators (progress attr or gone model)
                local done = false
                if pt then
                    local g = pt:FindFirstAncestorOfClass("Model")
                    if g then
                        for k, v in pairs(g:GetAttributes()) do
                            local kl = string.lower(k)
                            if (string.find(kl, "progress") or string.find(kl, "repair") or string.find(kl, "complete"))
                                and tonumber(v) and tonumber(v) >= 100 then
                                done = true
                                break
                            end
                        end
                    end
                end
                if done then
                    if S._lastRepairPt and S._lastRepairPt.Parent then
                        fireRemote("Remotes.Generator.RepairEvent", S._lastRepairPt, true)
                    end
                    S._lastRepairPt = nil
                    notify("Gen", "done, released")
                else
                    -- episodic repair: 3s work / 1s rest so isRepairing can clear
                    local phase = (now % 4)
                    if phase < 3 then
                        if pt then
                            S._lastRepairPt = pt
                            fireRemote("Remotes.Generator.RepairEvent", pt, false)
                        end
                    elseif not S._genRested then
                        S._genRested = true
                        if S._lastRepairPt and S._lastRepairPt.Parent then
                            fireRemote("Remotes.Generator.RepairEvent", S._lastRepairPt, true)
                        end
                    end
                    if phase < 3 then S._genRested = false end
                end
            end
            -- stuck watchdog: rooted while autogen on and no input => force release + pause
            local rooted = hum.Sit or hrp.Anchored or hum.WalkSpeed <= 0.5
            if rooted and not moving then
                S._stuckT = (S._stuckT or 0) + 1
                if S._stuckT >= 25 then -- ~2.5s at 10Hz ticks
                    S._stuckT = 0
                    if S._lastRepairPt and S._lastRepairPt.Parent then
                        fireRemote("Remotes.Generator.RepairEvent", S._lastRepairPt, true)
                    end
                    pcall(function()
                        hrp.Anchored = false
                        hum.Sit = false
                        hum.PlatformStand = false
                        if hum.WalkSpeed < 8 then hum.WalkSpeed = 16 end
                    end)
                    S._genPauseUntil = now + 3
                    notify("Gen", "stuck -> released, 3s pause")
                end
            else
                S._stuckT = 0
            end
        end
        -- Killer loops
        if S.KillerTools.AutoBreak then
            fireRemote("Remotes.Pallet.Jason.Destroy", hrp)
        end
        if S.KillerTools.NoCD then
            fireRemote("Remotes.Killers.Killer.CooldownEvent", 0)
        end
    end
end)

-- Fly (CFrame-based, stable)
local flyConn
local function setFly(on)
    S.Move.Fly = on
    if flyConn then pcall(function() flyConn:Disconnect() end) flyConn = nil end
    if not on then return end
    flyConn = RunService.RenderStepped:Connect(function(dt)
        local hrp = myHRP()
        if not hrp then return end
        local cf = Camera.CFrame
        local mv = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then mv += cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then mv -= cf.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then mv -= cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then mv += cf.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then mv += Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.Q) then mv -= Vector3.new(0, 1, 0) end
        if mv.Magnitude > 0 then
            hrp.CFrame = hrp.CFrame + mv.Unit * S.Move.FlySpeed * dt
            hrp.Velocity = Vector3.zero
        else
            hrp.Velocity = Vector3.zero
        end
    end)
end

-- ---- Spider (Tidal): wall raycast at hip height, climb while facing wall ----
local spiderParams = RaycastParams.new()
spiderParams.RespectCanCollide = true
spiderParams.IgnoreWater = true
local function spiderMaxAngle()
    return 1 - math.cos(math.rad(S.SpiderMod.MaxAngleDeg or 10))
end
RunService.PreSimulation:Connect(function(dt)
    if not alive or not S.Move.Spider then T.spiderClimbed = nil return end
    local char = LocalPlayer.Character
    local hum = humOf(char)
    local hrp = hrpOf(char)
    if not hum or not hrp then return end
    pcall(function()
        spiderParams.FilterDescendantsInstances = { char }
        spiderParams.CollisionGroup = hrp.CollisionGroup
    end)
    local mv = hum.MoveDirection * (S.SpiderMod.Radius or 2.5)
    if mv.Magnitude < 0.05 then
        if T.spiderClimbed and S.SpiderMod.ResetVel and S.SpiderMod.Method == "Velocity" then
            local v = hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
        end
        T.spiderClimbed = nil
        return
    end
    local origin = hrp.Position - Vector3.new(0, hum.HipHeight - 0.5, 0)
    local hit = Workspace:Raycast(origin, mv, spiderParams)
    if hit and hit.Normal.Y <= spiderMaxAngle() then
        T.spiderClimbed = true
        if (S.SpiderMod.Method or "Velocity") == "Velocity" then
            hrp.AssemblyLinearVelocity += Vector3.new(0, S.SpiderMod.Speed or 20, 0)
        else
            char:TranslateBy(Vector3.new(0, (S.SpiderMod.Speed or 20) * dt, 0))
        end
    elseif T.spiderClimbed then
        if S.SpiderMod.ResetVel and S.SpiderMod.Method == "Velocity" then
            local v = hrp.AssemblyLinearVelocity
            hrp.AssemblyLinearVelocity = Vector3.new(v.X, 0, v.Z)
        end
        T.spiderClimbed = nil
    end
end)

-- ---- Float (Tidal): Part platform or LinearVelocity, E up / Q down (hold) ----
local function floatKeys()
    local upKey, dnKey = S.FloatMod.UpKey, S.FloatMod.DownKey
    local e = upKey and UserInputService:IsKeyDown(upKey)
    local q = dnKey and UserInputService:IsKeyDown(dnKey)
    return (e and 1 or 0), (q and 1 or 0), e, q
end
local function setFloat(on)
    S.FloatMod.Enabled = on
    for _, c in ipairs(T.floatConns) do pcall(function() c:Disconnect() end) end
    T.floatConns = {}
    if T.floatPart then pcall(function() T.floatPart:Destroy() end) T.floatPart = nil end
    if T.floatLV then pcall(function() T.floatLV:Destroy() end) T.floatLV = nil end
    if T.floatAttach then pcall(function() T.floatAttach:Destroy() end) T.floatAttach = nil end
    if not on then return end
    if (S.FloatMod.Method or "Part") == "Part" then
        local part = Instance.new("Part")
        part.Size = Vector3.new(2, 0.2, 2)
        part.Color = S.FloatMod.Color
        part.Anchored = true
        part.CanTouch = false
        part.CanQuery = false
        part.CastShadow = false
        part.Parent = Workspace
        T.floatPart = part
        table.insert(T.floatConns, RunService.PostSimulation:Connect(function()
            if not alive or not S.FloatMod.Enabled then return end
            local hrp = myHRP()
            local hum = humOf(LocalPlayer.Character)
            if not hrp or not hum or not T.floatPart then return end
            local e, q, eDown, qDown = floatKeys()
            local offset = hum.HipHeight - hrp.Size.Y
            local y = -(hum.HipHeight + 0.1) + ((e - q) * offset)
                + ((eDown and S.FloatMod.UpOffset or 0) - (qDown and S.FloatMod.DownOffset or 0))
            T.floatPart.CFrame = hrp.CFrame * CFrame.new(0, y, 0)
            T.floatPart.Color = S.FloatMod.Color
        end))
    else
        local function buildLV()
            local hrp = myHRP()
            if not hrp then return end
            local att = Instance.new("Attachment")
            att.Name = "VDFloatAttach"
            att.Position = hrp.AssemblyCenterOfMass - hrp.Position
            att.Parent = hrp
            T.floatAttach = att
            local lv = Instance.new("LinearVelocity")
            lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
            lv.LineDirection = Vector3.new(0, 1, 0)
            lv.ForceLimitsEnabled = false
            lv.LineVelocity = 0
            lv.Attachment0 = att
            lv.Enabled = false
            lv.Parent = Workspace
            T.floatLV = lv
        end
        buildLV()
        table.insert(T.floatConns, LocalPlayer.CharacterAdded:Connect(function()
            task.wait(0.5)
            if S.FloatMod.Enabled and S.FloatMod.Method == "LinearVelocity" then
                if T.floatAttach then pcall(function() T.floatAttach:Destroy() end) end
                if T.floatLV then pcall(function() T.floatLV:Destroy() end) end
                buildLV()
            end
        end))
        table.insert(T.floatConns, RunService.PreSimulation:Connect(function()
            if not alive or not S.FloatMod.Enabled then return end
            local hrp = myHRP()
            local hum = humOf(LocalPlayer.Character)
            local lv = T.floatLV
            if not hrp or not hum or not lv or not T.floatAttach then return end
            local e, q, eDown, qDown = floatKeys()
            if (eDown or qDown) or (hum.FloorMaterial == Enum.Material.Air and hrp.AssemblyLinearVelocity.Y <= 0) then
                local vel = e * S.FloatMod.UpSpeed - q * S.FloatMod.DownSpeed
                if vel < 0 and hum.FloorMaterial ~= Enum.Material.Air then
                    lv.LineVelocity = 0
                else
                    lv.LineVelocity = vel
                    T.floatAttach.Position = hrp.AssemblyCenterOfMass - hrp.Position
                    lv.Enabled = true
                end
            elseif hum.FloorMaterial ~= Enum.Material.Air then
                lv.Enabled = false
            else
                lv.LineVelocity = 0
            end
        end))
    end
end

-- ---- Freecam (Tidal): Scriptable camera + mouse look + WASD/E/Q/Shift ----
local function setFreecam(on)
    S.Visual.Freecam = on
    local F = T.fc
    if F.action then
        pcall(function() ContextActionService:UnbindAction("VDFreecamKeyboard_" .. F.action) end)
        pcall(function() ContextActionService:UnbindAction("VDFreecamMouse_" .. F.action) end)
        pcall(function() RunService:UnbindFromRenderStep("VDFreecamRender_" .. F.action) end)
        F.action = nil
    end
    for k in pairs(F.keys or {}) do F.keys[k] = 0 end
    if not on then
        if F.oldCameraType then pcall(function() Camera.CameraType = F.oldCameraType end) end
        if F.oldIcon ~= nil then pcall(function() UserInputService.MouseIconEnabled = F.oldIcon end) end
        if F.oldBehavior then pcall(function() UserInputService.MouseBehavior = F.oldBehavior end) end
        F.oldCameraType, F.oldIcon, F.oldBehavior = nil, nil, nil
        pcall(function() Camera.CameraSubject = humOf(LocalPlayer.Character) end)
        return
    end
    F.keys = { W = 0, A = 0, S = 0, D = 0, E = 0, Q = 0, LeftShift = 0, Space = 0 }
    F.yaw, F.pitch = 0, 0
    local needLock = UserInputService.MouseBehavior == Enum.MouseBehavior.Default
        and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
    F.oldCameraType = Camera.CameraType
    F.oldBehavior = needLock and UserInputService.MouseBehavior or nil
    F.oldIcon = UserInputService.MouseIconEnabled
    Camera.CameraType = Enum.CameraType.Scriptable
    if needLock then UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter end
    UserInputService.MouseIconEnabled = false
    F.action = HttpService:GenerateGUID(false)
    local function keyFn(_, state, input)
        F.keys[input.KeyCode.Name] = (state == Enum.UserInputState.Begin) and 1 or 0
    end
    local function mouseFn(_, state, input)
        if state ~= Enum.UserInputState.Change then return end
        local sens = S.FreecamAdv.Sens / 240
        F.yaw -= input.Delta.X * sens
        F.pitch -= input.Delta.Y * sens
        if S.FreecamAdv.Limits then
            F.pitch = math.clamp(F.pitch, -math.pi / 2, math.pi / 2)
        end
    end
    local function step(dt)
        if UserInputService.MouseBehavior == Enum.MouseBehavior.Default
            and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
        end
        local dir = Vector3.new(F.keys.D - F.keys.A, 0, F.keys.S - F.keys.W)
        if dir.Magnitude > 0 then dir = dir.Unit end
        dir = Vector3.new(dir.X, F.keys.E - F.keys.Q, dir.Z) * S.FreecamAdv.Speed
        if F.keys.LeftShift == 1 then dir *= S.FreecamAdv.ShiftMult end
        local rot = CFrame.Angles(0, F.yaw, 0) * CFrame.Angles(F.pitch, 0, 0)
        local stepV = rot:VectorToWorldSpace(dir) * 50 * dt
        Camera.CFrame = CFrame.new(Camera.CFrame.Position + stepV) * rot
    end
    F.yaw = select(2, Camera.CFrame:ToOrientation())
    F.pitch = S.FreecamAdv.Limits
        and math.asin(math.clamp(Camera.CFrame.LookVector.Y, -1, 1))
        or Camera.CFrame.LookVector.Y
    RunService:BindToRenderStep("VDFreecamRender_" .. F.action, 200, step)
    ContextActionService:BindActionAtPriority("VDFreecamKeyboard_" .. F.action, keyFn, false, 69420,
        Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D,
        Enum.KeyCode.E, Enum.KeyCode.Q, Enum.KeyCode.LeftShift, Enum.KeyCode.Space)
    ContextActionService:BindActionAtPriority("VDFreecamMouse_" .. F.action, mouseFn, false, 69420,
        Enum.UserInputType.MouseMovement)
end

-- ---- CameraPhase (Tidal): Popper queryPoint 0.25 -> 0, else Invisicam ----
local function setCameraPhase(on)
    S.Visual.CameraPhase = on
    if T.popperFn then
        pcall(debug.setconstant, T.popperFn, T.popperIdx, 0.25)
        T.popperFn, T.popperIdx = nil, nil
    end
    if T.camOccOld then
        pcall(function() LocalPlayer.DevCameraOcclusionMode = T.camOccOld end)
        T.camOccOld = nil
    end
    if not on then return end
    local found = false
    if filtergc and debug.setconstant and debug.getconstants then
        pcall(function()
            for _, fn in ipairs(filtergc("function", { Name = "queryPoint" })) do
                local src = debug.info(fn, "s") or ""
                if string.find(src, "ZoomController%.Popper") then
                    for i, c in debug.getconstants(fn) do
                        if c == 0.25 then
                            debug.setconstant(fn, i, 0)
                            T.popperFn, T.popperIdx = fn, i
                            found = true
                            break
                        end
                    end
                    break
                end
            end
        end)
    end
    if not found then
        T.camOccOld = LocalPlayer.DevCameraOcclusionMode
        LocalPlayer.DevCameraOcclusionMode = Enum.DevCameraOcclusionMode.Invisicam
        notify("CameraPhase", "fallback: Invisicam")
    else
        notify("CameraPhase", "Popper patched")
    end
end

-- ---- Cape (Tidal): Motor6D cape + spring physics, hidden in 1st person ----
local function setCape(on)
    S.CapeMod.Enabled = on
    local C = T.cape
    if C.conn then for _, c in ipairs(C.conn) do pcall(function() c:Disconnect() end) end C.conn = {} end
    if C.part then pcall(function() C.part:Destroy() end) C.part = nil end
    if C.motor then pcall(function() C.motor:Destroy() end) C.motor = nil end
    if not on then return end
    local part = Instance.new("Part")
    part.Size = Vector3.new(2, 4, 0.1)
    part.CanCollide = false
    part.CanQuery = false
    part.CastShadow = false
    part.Massless = true
    part.Material = Enum.Material.SmoothPlastic
    part.Color = Color3.fromRGB(0, 0, 0)
    part.Parent = Camera
    C.part = part
    local function buildMotor()
        if not C.part then return end
        if C.motor then pcall(function() C.motor:Destroy() end) C.motor = nil end
        local char = LocalPlayer.Character
        local hrp = hrpOf(char)
        local torso = char and char:FindFirstChild("Torso")
        local p1 = torso or hrp
        if not p1 then return end
        C.part.Parent = Camera
        local m = Instance.new("Motor6D")
        m.MaxVelocity = 0.08
        m.Part0 = C.part
        m.Part1 = p1
        m.C0 = CFrame.new(0, 2, 0) * CFrame.Angles(0, math.rad(-90), 0)
        m.C1 = CFrame.new(0, p1.Size.Y / 2, 0.45) * CFrame.Angles(0, math.rad(90), 0)
        m.Parent = C.part
        C.motor = m
    end
    buildMotor()
    local gui = Instance.new("SurfaceGui")
    gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    gui.Adornee = part
    gui.Parent = part
    C.gui = gui
    local function buildTexture()
        if not C.part or not C.gui then return end
        for _, ch in ipairs(C.gui:GetChildren()) do ch:Destroy() end
        local tex = S.CapeMod.Texture
        if string.find(tex, ".webm", 1, true) then
            local vf = Instance.new("VideoFrame")
            vf.Video = tex
            vf.Size = UDim2.fromScale(1, 1)
            vf.BackgroundTransparency = 1
            vf.Looped = true
            vf.Parent = C.gui
            pcall(function() vf:Play() end)
        else
            local img = Instance.new("ImageLabel")
            img.Image = tex
            img.Size = UDim2.fromScale(1, 1)
            img.BackgroundTransparency = 1
            img.Parent = C.gui
        end
    end
    buildTexture()
    C.buildTexture = buildTexture
    C.conn = {
        LocalPlayer.CharacterAdded:Connect(function()
            task.wait(0.5)
            if S.CapeMod.Enabled then buildMotor() end
        end),
        RunService.PreRender:Connect(function(dt)
            if not alive or not S.CapeMod.Enabled or not C.part then return end
            local char = LocalPlayer.Character
            local hrp = hrpOf(char)
            if hrp and C.motor then
                local vel = hrp.AssemblyLinearVelocity
                local flat = Vector3.new(vel.X, 0, vel.Z)
                local hvel = math.min(flat.Magnitude, 90)
                local target = math.rad(8 + hvel * 0.9)
                    - math.rad(math.clamp(vel.Y * 1, -90, 8))
                if hvel > 1 then
                    local now = os.clock()
                    local fl = math.sin(now * 9) * 0.5 + math.sin(now * 13.7 + 1.3) * 0.3
                    target += math.rad(fl * math.clamp(hvel / 20, 0, 1) * 32)
                end
                C.cur = C.cur or 0
                C.vel = C.vel or 0
                local diff = target - C.cur
                C.vel += diff * 50 * dt
                C.vel *= math.exp(-1 * 10 * dt)
                C.cur += C.vel * dt
                C.motor.DesiredAngle = C.cur
            elseif hrp and not C.motor then
                buildMotor()
            end
            local third = (Camera.CFrame.Position - Camera.Focus.Position).Magnitude > 0.6
            if C.gui then C.gui.Enabled = third end
            C.part.Transparency = third and 0 or 1
        end),
    }
end
-- Fullbright / NoFog loop below owns Lighting; no stray signal connections.
RunService.Heartbeat:Connect(function()
    if not alive then return end
    if S.Visual.Fullbright then
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 2
        Lighting.FogEnd = 1e6
    end
    if S.Visual.NoFog then
        Lighting.FogEnd = 1e6
        pcall(function() Lighting.Atmosphere.Density = 0 end)
    end
end)
-- AntiAFK
local afkConn
local function setAntiAFK(on)
    S.Visual.AntiAFK = on
    if afkConn then pcall(function() afkConn:Disconnect() end) afkConn = nil end
    if on then
        afkConn = LocalPlayer.Idled:Connect(function()
            pcall(function() VirtualUser:ClickButton2(Vector2.new()) end)
        end)
    end
end
-- AntiFling: cap velocity
RunService.Heartbeat:Connect(function()
    if not alive or not S.Visual.AntiFling then return end
    local hrp = myHRP()
    if hrp and hrp.Velocity.Magnitude > 80 then
        hrp.Velocity = hrp.Velocity.Unit * 80
    end
end)

-- Auto Parry: watch killer attack anim + distance, fire parry remote
RunService.Heartbeat:Connect(function()
    if not alive or not S.Parry.Enabled then return end
    local my = myHRP()
    if not my then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if isKiller(p) and p.Character and hrpOf(p.Character) then
            local kp = hrpOf(p.Character).Position
            if (kp - my.Position).Magnitude <= S.Parry.Dist then
                -- humanize delay then fire
                task.delay(S.Parry.Humanize, function()
                    if not S.Parry.Enabled then return end
                    fireRemote("Remotes.Items.Parrying Dagger.parry")
                    if S.Parry.Visual then
                        notify("Parry", "fired @ " .. math.floor((kp - my.Position).Magnitude) .. "m")
                    end
                end)
                break
            end
        end
    end
end)

-- ============ SKILLCHECK: shared state (hook + grader) ============
-- SkillCheckResultEvent signatures (reverse engineered):
--   Perfect -> ("success", 1, gen, point) | Great -> ("neutral", 0, gen, point)
-- RepairEvent: (generatorPoint, false). We never fire result remotes ourselves:
-- the game owns the tuple; we press real Space when the needle is in the zone.
local skillFiredAt = 0
local skillWasVisible = false
local skillShots = 0 -- shots used for the current prompt episode (cap 4, one per revolution)
local skillCtx = nil -- {gen=Model, point=BasePart} captured from SkillCheckEvent
local skillGuiCache = nil
local skillVisSince = nil  -- when the current prompt became visible
local skillGaveUp = false  -- already released a stuck (>12s) prompt this episode
local function skillGui()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    local sc = pg and pg:FindFirstChild("SkillCheckPromptGui")
    if not sc then skillGuiCache = nil return nil end
    local c = skillGuiCache
    if c and c.sc == sc and c.check and c.check.Parent and c.line and c.line.Parent and c.goal and c.goal.Parent then
        return c
    end
    local check = sc:FindFirstChild("Check")
    local line, goal
    if check then
        line = check:FindFirstChild("Line")
        goal = check:FindFirstChild("Goal")
    end
    if not line or not goal then
        for _, d in ipairs(sc:GetDescendants()) do
            if d:IsA("ImageLabel") then
                if d.Name == "Line" then line = d
                elseif d.Name == "Goal" then goal = d end
            end
        end
    end
    if not check or not line or not goal then skillGuiCache = nil return nil end
    skillGuiCache = { sc = sc, check = check, line = line, goal = goal }
    return skillGuiCache
end
local function genPointOf(model, nearPos)
    if not model then return nil end
    -- the ACTIVE point is the one the player stands at: nearest GeneratorPoint,
    -- NOT the first found (Point1 vs Point2 mismatch = server ignores the hit)
    local best, bd = nil, 1e9
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") and string.find(d.Name, "GeneratorPoint") then
            if not nearPos then return d end
            local dist = (d.Position - nearPos).Magnitude
            if dist < bd then bd, best = dist, d end
        end
    end
    if best then return best end
    return model:FindFirstChildWhichIsA("BasePart", true)
end
local function currentRepairTarget(maxDist)
    -- hard cap: repair prompts only work within ~12 studs; firing at far
    -- generators roots the character remotely with no local prompt
    maxDist = math.min(maxDist or 12, 12)
    local my = myHRP()
    if not my then return nil, nil end
    -- prefer context from the live skillcheck prompt (only if still near)
    if skillCtx and skillCtx.gen and skillCtx.gen.Parent then
        local pp = genPointOf(skillCtx.gen, my.Position)
        if pp and (pp.Position - my.Position).Magnitude <= maxDist then
            return skillCtx.gen, pp
        end
    end
    local best, bestPt, bd = nil, nil, maxDist
    local map = Workspace:FindFirstChild("Map")
    local gens = map and (map:FindFirstChild("Generators") or map:FindFirstChild("Gens"))
    local list = gens and gens:GetChildren() or {}
    if #list == 0 and map then
        for _, d in ipairs(map:GetDescendants()) do
            if d:IsA("Model") and string.find(d.Name, "Generator") then table.insert(list, d) end
        end
    end
    for _, g in ipairs(list) do
        local pt = genPointOf(g, my.Position)
        if pt then
            local dist = (pt.Position - my.Position).Magnitude
            if dist < bd then bd, best, bestPt = dist, g, pt end
        end
    end
    return best, bestPt
end
-- Release the repair channel + unroot the character (stuck prompt / manual button)
local function unstick()
    local hrp = myHRP()
    local char = LocalPlayer.Character
    local hum = humOf(char)
    local pt = S._lastRepairPt
    if pt and pt.Parent then
        fireRemote("Remotes.Generator.RepairEvent", pt, true)
    end
    S._lastRepairPt = nil
    S._genPauseUntil = os.clock() + 2
    S._stuckT = 0
    if hrp and hum then
        pcall(function()
            hrp.Anchored = false
            hum.Sit = false
            hum.PlatformStand = false
            hum.JumpPower = 50
            if hum.WalkSpeed < 8 then hum.WalkSpeed = 16 end
            char:SetAttribute("isRepairing", false)
        end)
    end
    notify("Unstick", "repair released")
end

-- Context hook: capture the live generator/point from SkillCheckEvent so
-- autogen targets the exact gen the prompt belongs to. Never answers here.
local function hookSkillcheck()
    local gen = getRemote("Remotes.Generator.SkillCheckEvent")
    if gen and gen:IsA("RemoteEvent") then
        pcall(function()
            gen.OnClientEvent:Connect(function(a1, a2, a3, a4)
                -- capture live context: (gen, point, ...) order may vary, pick by type
                for _, v in ipairs({a1, a2, a3, a4}) do
                    if typeof(v) == "Instance" then
                        if v:IsA("Model") and string.find(v.Name, "Generator") then
                            skillCtx = skillCtx or {}
                            skillCtx.gen = v
                        elseif v:IsA("BasePart") and string.find(v.Name, "GeneratorPoint") then
                            skillCtx = skillCtx or {}
                            skillCtx.point = v
                        end
                    end
                end
            end)
        end)
    end
    local heal = getRemote("Remotes.Healing.SkillCheckEvent")
    if heal and heal:IsA("RemoteEvent") then
        pcall(function()
            heal.OnClientEvent:Connect(function()
                -- heal signature unknown: do NOT press Space (Space = jump,
                -- random jumps break the repair channel). Only log.
                if S.Skill.Debug then print("[VDHub_io] heal skillcheck seen (no signature, skipped)") end
            end)
        end)
    end
end
pcall(hookSkillcheck)

-- ============ SKILLCHECK GRADER (RenderStepped ~60Hz) ============
-- PORTED FROM VD MATCHA (external, naibko-dil): the old internal grader was
-- fully broken because it read Line.Rotation / Goal.Rotation directly. The
-- game's tween writes the live angle to an internal GUI field; the exposed
-- Rotation property stays stale at 0 in the current build. Matcha reads the
-- real values out of memory (offset +0xD8, resolved via a geometry+sin/cos
-- signature). Internally we cannot touch raw memory, so we read the same
-- field through the engine itself: debug.getproperty(inst, "Rotation"),
-- which bypasses the stale public binding. If the engine ever fixes the
-- public property again, plain .Rotation is used as-is.
local skillDbgAt = 0
local function rotOf(inst)
    local v = inst.Rotation
    if type(v) == "Vector2" then v = v.X end
    if type(v) ~= "number" or v ~= v then v = nil end
    local ok, dv = pcall(debug.getproperty, inst, "Rotation")
    if ok and type(dv) == "number" and dv == dv then
        -- prefer the debug-read value when it disagrees with the stale
        -- public binding (needle actually moving vs frozen at 0)
        if not v or math.abs(dv - v) > 0.001 then v = dv end
    end
    return v
end
-- Separate sampling from input so a reset, chained goal, or held physical key
-- cannot produce repeated presses. A stationary/hidden needle never arms.
-- (Matcha scAdvance(): motion-rate lead compensation + server grader window
--  Goal+102 .. Goal+116 measured clockwise from the goal.)
local function scAdvance(t, lr, gr, now, lead)
    local previous = t.line
    local reset = t.goal == nil or math.abs(gr - t.goal) > 0.5
        or (previous ~= nil and lr < previous - 2)
    if reset then
        t.fired, t.counted, t.missed = false, false, false
        t.motionAt, t.motionLine, t.rate = nil, nil, nil
    end
    local moved = previous ~= nil and lr > previous + 0.001
    if moved then
        if t.motionAt then
            local dt = now - t.motionAt
            if dt > 0 and dt < 0.5 then
                local rate = (lr - t.motionLine) / dt
                if rate > 0 and rate < 10000 then
                    t.rate = t.rate and (t.rate * 0.5 + rate * 0.5) or rate
                end
            end
        end
        t.motionAt, t.motionLine = now, lr
    end
    t.line, t.goal = lr, gr
    local active = lr > 0.05 and t.motionAt ~= nil and now - t.motionAt <= 0.12
    local newCheck = active and not t.counted
    if newCheck then t.counted = true end
    local lo, hi = gr + 102, gr + 116
    local threshold = math.clamp(gr + 109 - math.clamp(lead or 0, 0, 10)
        - (t.rate or 0) / 120, lo + 0.25, hi - 0.25)
    local missed = active and not t.fired and not t.missed and lr > hi
    if missed then t.missed = true end
    return active and not t.fired and lr >= threshold and lr <= hi, newCheck, missed, lo, hi
end
local skillTrack = {}
local function resetSkillTrack()
    skillTrack.fired, skillTrack.counted, skillTrack.missed = false, false, false
    skillTrack.motionAt, skillTrack.motionLine, skillTrack.rate = nil, nil, nil
    skillTrack.line, skillTrack.goal = nil, nil
end
local skillMisses, skillErrors = 0, 0
trackConn(RunService.RenderStepped:Connect(function(dt)
    if not alive or not S.Skill.Enabled then
        skillWasVisible = false skillShots = 0 resetSkillTrack() return
    end
    local g = skillGui()
    local vis = g and g.check.Visible == true
    if vis and not skillWasVisible then
        skillShots = 0 -- new prompt episode
        skillVisSince = os.clock()
        S.Skill._prevErr = nil
        resetSkillTrack()
    end
    if vis and g then
        -- prompt stuck open >12s (failed state): release once, don't feed it
        if skillVisSince and os.clock() - skillVisSince > 12 and not skillGaveUp then
            skillGaveUp = true
            unstick()
            notify("Skill", "prompt stuck >12s, released")
        end
        local lr, gr = rotOf(g.line), rotOf(g.goal)
        if not lr or not gr or lr < -3600 or gr < -3600 then
            resetSkillTrack() -- layout refresh: needle unreadable this frame
        else
            local now = os.clock()
            local fire, newCheck, missed = scAdvance(skillTrack, lr, gr, now, S.Skill.Lead)
            S.Skill._err = (lr - gr) % 360 -- clockwise distance from the goal
            S.Skill._needle, S.Skill._goal = lr, gr
            if S.Skill.Debug and now - skillDbgAt > 0.5 then
                skillDbgAt = now
                print(("[VDHub_io] skill L=%.1f G=%.1f rel=%.1f rate=%.0f shots=%d")
                    :format(lr, gr, S.Skill._err, skillTrack.rate or 0, skillShots))
            end
            if newCheck then S.Skill._checks = (S.Skill._checks or 0) + 1 end
            if missed then
                skillMisses += 1
                S.Skill._misses = skillMisses
            end
            if fire then
                if skillShots >= 4 then return end -- cap 4, one per revolution
                skillTrack.fired = true
                skillShots += 1
                skillFiredAt = now
                pcall(function() keyclick(32) end) -- VK_SPACE, only while prompt visible
                if S.Skill.Debug then
                    print(("[VDHub_io] skill SPACE fired rel=%.1f shot=%d/4")
                        :format(S.Skill._err, skillShots))
                end
            end
        end
    end
    if not vis then skillShots = 0 skillVisSince = nil skillGaveUp = false S.Skill._prevErr = nil resetSkillTrack() end
    skillWasVisible = vis and true or false
end))

-- ---- Animations (Tidal): R6-friendly tracks + target movers ----
T.animReg = {}
local function animNotifyFail(title, what)
    notify(title, what)
end
local function loadAnimTrack(id, looped, speed)
    local char = LocalPlayer.Character
    local hum = humOf(char)
    local animator = hum and hum:FindFirstChildOfClass("Animator")
    if not animator then return nil end
    local a = Instance.new("Animation")
    a.AnimationId = id
    local ok, track = pcall(function() return animator:LoadAnimation(a) end)
    if not ok or not track then return nil end
    track.Priority = Enum.AnimationPriority.Action4
    if looped then track.Looped = true end
    track:Play(0, 1, speed or 1)
    return track
end
local function stopAnimTrack(name)
    local t = T.anims[name]
    if t then pcall(function() t:Stop() end) pcall(function() t:Destroy() end) end
    T.anims[name] = nil
end
if not T.animSpawnConn then
    T.animSpawnConn = trackConn(LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.7)
        if not alive then return end
        for _, r in ipairs(T.animReg) do
            if r.isOn() then pcall(r.init) end
        end
    end))
end
local function regAnim(name, isOn, init, deinit)
    for _, r in ipairs(T.animReg) do if r.name == name then r.isOn, r.init, r.deinit = isOn, init, deinit return end end
    table.insert(T.animReg, { name = name, isOn = isOn, init = init, deinit = deinit })
end
local function setAnimEnabled(name, on, init, deinit, isOnFn)
    regAnim(name, isOnFn, init, deinit)
    if on then pcall(init) else pcall(deinit) stopAnimTrack(name) end
end
-- AnimationSpeed: scale every playing track
local function setAnimSpeed(on)
    if T.animSpdConn then for _, c in ipairs(T.animSpdConn) do pcall(function() c:Disconnect() end) end T.animSpdConn = nil end
    if T.animSpdTracks then
        for track, old in pairs(T.animSpdTracks) do pcall(function() track:AdjustSpeed(old) end) end
        T.animSpdTracks = nil
    end
    if not on then return end
    T.animSpdTracks = {}
    local function calc(track)
        if S.AnimMod.UseMulti then
            return (T.animSpdTracks[track] or 1) * S.AnimMod.Multi
        end
        return S.AnimMod.Speed
    end
    local function onPlayed(track)
        if not T.animSpdTracks then return end
        if T.animSpdTracks[track] == nil then T.animSpdTracks[track] = track.Speed end
        pcall(function() track:AdjustSpeed(calc(track)) end)
    end
    local function hookHum()
        local hum = humOf(LocalPlayer.Character)
        if not hum then return end
        table.insert(T.animSpdConn, hum.AnimationPlayed:Connect(onPlayed))
        for _, tr in ipairs(hum:GetPlayingAnimationTracks()) do onPlayed(tr) end
    end
    T.animSpdConn = {}
    hookHum()
    table.insert(T.animSpdConn, LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        -- re-hook only while the toggle is still on (SpeedOn lives in the UI callback)
        if S.AnimMod.SpeedOn and T.animSpdTracks then hookHum() end
    end))
    table.insert(T.animSpdConn, RunService.PreAnimation:Connect(function()
        if not alive or not S.AnimMod.SpeedOn or not T.animSpdTracks then return end
        for track in pairs(T.animSpdTracks) do pcall(function() track:AdjustSpeed(calc(track)) end) end
    end))
end
-- generic target mover (Bang/BendOver/Carpet/HeadSit/Orbit/Stare)
local function targetMoverLoop(name, flag, stepFns)
    if T.anims[name .. "_loop"] then
        for _, c in ipairs(T.anims[name .. "_loop"]) do pcall(function() c:Disconnect() end) end
        T.anims[name .. "_loop"] = nil
    end
    if not flag then return end
    local conns = {}
    for _, fn in ipairs(stepFns) do
        table.insert(conns, RunService.PreSimulation:Connect(function(...)
            if not alive then return end
            pcall(fn, ...)
        end))
    end
    T.anims[name .. "_loop"] = conns
end
local function moverTo(name, offsetCF, inputFlag)
    return function()
        local input = ""
        pcall(function() input = MacLib.Flags[inputFlag]:GetInput() end)
        local hrp, _ = targetRoot(input)
        local my = myHRP()
        if hrp and my then
            my.CFrame = hrp.CFrame * offsetCF
            my.AssemblyLinearVelocity = Vector3.zero
        end
    end
end

local R6DANCES = { Dance = "rbxassetid://27789359", Moonwalk = "rbxassetid://30196114",
    ["Dance Like There's no Tomorrow"] = "rbxassetid://248263260", Disco = "rbxassetid://45834924",
    Party = "rbxassetid://33796059", Goal = "rbxassetid://28488254", ["Flute Dance"] = "rbxassetid://52155728" }
local R15DANCES = { ["River Dance"] = "rbxassetid://3333432454", ["Keeping Time"] = "rbxassetid://4555808220",
    ["Line Dance"] = "rbxassetid://4049037604", ["Air Dance"] = "rbxassetid://4555782893",
    ["Break Dance"] = "rbxassetid://10214311282", Reflex = "rbxassetid://10714010337",
    ["Around Town"] = "rbxassetid://10713981723", ["Idol Face"] = "rbxassetid://10714372526",
    ["Fancy Feet"] = "rbxassetid://10714076981", Robot = "rbxassetid://10714392151",
    ["Still Standing"] = "rbxassetid://11444443576" }
local function danceApply()
    local hum = humOf(LocalPlayer.Character)
    if not hum then animNotifyFail("Dance", "no character") return end
    local id = hum.RigType == Enum.HumanoidRigType.R15
        and R15DANCES[S.AnimMod.DanceR15] or R6DANCES[S.AnimMod.DanceR6]
    if not id then animNotifyFail("Dance", "bad style") return end
    stopAnimTrack("Dance")
    T.anims.Dance = loadAnimTrack(id, true, 1)
    if T.anims.Dance then T.anims.Dance.Priority = Enum.AnimationPriority.Action4
    else animNotifyFail("Dance", "no Animator") end
end

-- Jerk loop clamp (Tidal): hold the 0.6-0.7 window
RunService.PreRender:Connect(function()
    local t = T.anims.Jerk
    if t and alive then
        pcall(function()
            if t.TimePosition >= 0.7 then t.TimePosition = 0.6 end
        end)
    end
end)

-- ============ INTERACTABLES: prompt-based discovery (props have no prompts) ============
-- Usable objects always carry a ProximityPrompt; decorative props do not.
-- Anchor = prompt parent part (or biggest part of the model).
local function promptAnchor(model)
    local bestPrompt
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("ProximityPrompt") then bestPrompt = d break end
    end
    if bestPrompt and bestPrompt.Parent and bestPrompt.Parent:IsA("BasePart") then
        return bestPrompt.Parent, bestPrompt
    end
    local big, bs = nil, 0
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") and d.Size.Magnitude > bs then big, bs = d, d.Size.Magnitude end
    end
    if big and bs >= 2 then return big, bestPrompt end
    return nil, nil
end
local function collectUsables(pred)
    local out = {}
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("Model") and pred(d.Name) then
            local anchor, prompt = promptAnchor(d)
            if anchor then table.insert(out, { model = d, part = anchor, prompt = prompt }) end
        end
    end
    return out
end
local function nearestUsable(list)
    local my = myHRP()
    if not my or #list == 0 then return nil end
    local best, bd = nil, 1e9
    for _, e in ipairs(list) do
        local dist = (e.part.Position - my.Position).Magnitude
        if dist < bd then bd, best = dist, e end
    end
    return best
end
local function tpTo(cf)
    local hrp = myHRP()
    if not hrp or not cf then return end
    -- stand beside: 4 studs to the side + 2.5 up so we never land on top/inside
    local side = cf.RightVector * 4 + Vector3.new(0, 2.5, 0)
    hrp.Velocity = Vector3.zero
    hrp.CFrame = CFrame.new(cf.Position + side, cf.Position)
end
local function tpToPart(p)
    if p then tpTo(p.CFrame) end
end
local function nearestModel(models)
    local my = myHRP()
    if not my then return nil end
    local best, bd = nil, 1e9
    for _, m in ipairs(models) do
        local p = m:IsA("BasePart") and m or m:FindFirstChildWhichIsA("BasePart", true)
        if p then local d = (p.Position - my.Position).Magnitude if d < bd then bd = d best = p end end
    end
    return best
end
local function firePrompt(prompt)
    if not prompt then return false end
    local ok = pcall(function() fireproximityprompt(prompt) end)
    return ok
end

-- ============ UI BUILD (io-lib API per gitbook) ============
-- Bind policy: the ONLY default keybind is RightShift (window open/close, set
-- in MacLib:Window above). Every feature Keybind below starts unbound ("None")
-- and is bound by the user on demand; maclib's Keybind fires Callback only
-- when a bind exists, so unbound rows are harmless placeholders.

-- Combat tab
local c1 = tCombat:Section({ Side = "Left" })
c1:Header({ Name = "Auto Parry", Icon = "bolt" })
c1:Toggle({ Name = "Enabled", Default = false, Callback = function(v) S.Parry.Enabled = v end }, "ParryEnabled")
c1:Slider({ Name = "Distance", Default = 18, Minimum = 5, Maximum = 40, DisplayMethod = "Value", Callback = function(v) S.Parry.Dist = v end }, "ParryDist")
c1:Slider({ Name = "Humanize delay", Default = 5, Minimum = 0, Maximum = 30, DisplayMethod = "Value", Callback = function(v) S.Parry.Humanize = v / 100 end }, "ParryHumanize")
c1:Toggle({ Name = "Visual notify", Default = true, Callback = function(v) S.Parry.Visual = v end }, "ParryVisual")
c1:Keybind({ Name = "Parry bind", Callback = function() fireRemote("Remotes.Items.Parrying Dagger.parry") end }, "ParryBind")

local c2 = tCombat:Section({ Side = "Right" })
c2:Header({ Name = "Skillcheck", Icon = "check" })
c2:Toggle({ Name = "Auto Skillcheck", Default = false, Callback = function(v) S.Skill.Enabled = v end }, "SkillEnabled")
c2:Slider({ Name = "Lead (deg)", Default = 15, Minimum = 0, Maximum = 100, DisplayMethod = "Value", Callback = function(v) S.Skill.Lead = v / 10 end }, "SkillLead")
c2:Toggle({ Name = "Debug (console log)", Default = true, Callback = function(v) S.Skill.Debug = v end }, "SkillDebug")
c2:Keybind({ Name = "Skillcheck bind", Callback = function() S.Skill.Enabled = not S.Skill.Enabled end }, "SkillBind")

local c3 = tCombat:Section({ Side = "Left" })
c3:Header({ Name = "Moonwalk / Dagger", Icon = "code" })
c3:Toggle({ Name = "Auto Moonwalk", Default = false, Callback = function(v) S.Moonwalk.Enabled = v end }, "Moonwalk")
c3:Dropdown({ Name = "Method", Options = {"Classic", "Invert", "Spin"}, Default = 1, Callback = function(v) S.Moonwalk.Mode = v end }, "MoonwalkMode")
c3:Slider({ Name = "Turn smooth", Minimum = 4, Maximum = 40, Default = 16, Precision = 0, Callback = function(v) S.Moonwalk.Smooth = v end }, "MoonwalkSmooth")
c3:Toggle({ Name = "Spin back on dagger", Default = true, Callback = function(v) S.Dagger.SpinBack = v end }, "DaggerSpin")
-- "Dagger anim speed" slider removed: nothing reads S.Dagger.Speed (dead UI).
c3:Button({ Name = "Use dagger (spin back)", Icon = "bolt", Callback = function()
    local hrp = myHRP()
    if hrp and S.Dagger.SpinBack then hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(180), 0) end
    notify("Dagger", "used, back turned")
end })
c3:Keybind({ Name = "Dagger bind", Callback = function()
    local hrp = myHRP()
    if hrp and S.Dagger.SpinBack then hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(180), 0) end
    notify("Dagger", "used, back turned")
end }, "DaggerBind")

local c4 = tCombat:Section({ Side = "Right" })
c4:Header({ Name = "Crouch / Vault", Icon = "eye" })
c4:Toggle({ Name = "Auto Crouch", Default = false, Callback = function(v) S.Crouch.Enabled = v end }, "AutoCrouch")
c4:Slider({ Name = "Crouch radius", Default = 20, Minimum = 5, Maximum = 60, Callback = function(v) S.Crouch.Radius = v end }, "CrouchRadius")
c4:Toggle({ Name = "FastVaultModifier", Default = false, Callback = function(v) S.VaultMod.Enabled = v applyVaultMaster() end }, "FastVault")
c4:Toggle({ Name = "Any Angle", Default = true, Callback = function(v) S.VaultMod.AnyAngle = v applyVaultMaster() end }, "VaultAnyAngle")
c4:Toggle({ Name = "Any Speed", Default = true, Callback = function(v) S.VaultMod.AnySpeed = v applyVaultMaster() end }, "VaultAnySpeed")
c4:Toggle({ Name = "Always Fast Vault (Matcha port)", Default = false, Callback = function(v)
    S.VaultMod.AlwaysFast = v
    if not v then pcall(fvRestore) fvStat.status = "Disabled" end
end }, "VaultAlwaysFast")
c4:Toggle({ Name = "Finesse Vault (Flowstate)", Default = false, Callback = function(v) S.VaultMod.Finesse = v setFinesse(v) end }, "VaultFinesse")

local c5 = tCombat:Section({ Side = "Left" })
c5:Header({ Name = "Survival", Icon = "heart" })
c5:Toggle({ Name = "NoSlowdown", Default = false, Callback = function(v) S.NoSlowdown = v end }, "NoSlowdown")
c5:Toggle({ Name = "Auto Heal", Default = false, Callback = function(v) S.Heal.Auto = v end }, "AutoHeal")
c5:Toggle({ Name = "Auto Complete Gens", Default = false, Callback = function(v)
    S.AutoGen.Enabled = v
    if not v then
        -- release the repair channel so the character is never left rooted
        local pt = S._lastRepairPt
        if pt and pt.Parent then
            fireRemote("Remotes.Generator.RepairEvent", pt, true)
        end
        S._lastRepairPt = nil
    end
end }, "AutoGen")
c5:Button({ Name = "Unstick (release repair)", Icon = "bolt", Callback = function() unstick() end })
c5:Keybind({ Name = "Unstick bind", Callback = function() unstick() end }, "UnstickBind")
c5:Toggle({ Name = "Dodger (avoid killer)", Default = false, Callback = function(v) S.Dodger.Enabled = v end }, "Dodger")
c5:Slider({ Name = "Dodger radius", Default = 22, Minimum = 8, Maximum = 50, Callback = function(v) S.Dodger.Radius = v end }, "DodgerRadius")

-- Killer tab
local k1 = tKiller:Section({ Side = "Left" })
k1:Header({ Name = "Killer tools", Icon = "eye" })
k1:Toggle({ Name = "Auto Carry", Default = false, Callback = function(v) S.KillerTools.AutoCarry = v end }, "AutoCarry")
k1:Toggle({ Name = "Auto Hook", Default = false, Callback = function(v) S.KillerTools.AutoHook = v end }, "AutoHook")
k1:Toggle({ Name = "No cooldown", Default = false, Callback = function(v) S.KillerTools.NoCD = v end }, "NoCD")
k1:Toggle({ Name = "Auto Break pallets", Default = false, Callback = function(v) S.KillerTools.AutoBreak = v end }, "AutoBreak")
k1:Toggle({ Name = "Ignore Flashlight", Default = false, Callback = function(v)
    S.KillerTools.IgnoreFlash = v
    if v then fireRemote("Remotes.Items.Flashlight.GotBlinded", false) end
end }, "IgnoreFlash")
k1:Toggle({ Name = "No Stun (killer)", Default = false, Callback = function(v) S.KillerTools.NoStun = v end }, "KillerNoStun")
-- AutoCarry / AutoHook toggles removed: the state fields exist but no loop
-- ever reads them (dead UI). The manual buttons below actually work.
k1:Button({ Name = "Break nearest pallet", Icon = "bolt", Callback = function()
    local my = myHRP()
    if my then fireRemote("Remotes.Pallet.Jason.Destroy", my) end
end })
k1:Keybind({ Name = "Break pallet bind", Callback = function()
    local my = myHRP()
    if my then fireRemote("Remotes.Pallet.Jason.Destroy", my) end
end }, "BreakPalletBind")
k1:Button({ Name = "Hook carried (nearest)", Icon = "bolt", Callback = function()
    fireRemote("Remotes.Carry.HookEvent", myHRP())
end })
k1:Keybind({ Name = "Hook bind", Callback = function()
    fireRemote("Remotes.Carry.HookEvent", myHRP())
end }, "HookBind")

-- ESP tab
local e1 = tESP:Section({ Side = "Left" })
e1:Header({ Name = "Players", Icon = "lens" })
e1:Toggle({ Name = "Killer ESP", Default = false, Callback = function(v) S.ESP.Killer.Enabled = v end }, "ESPKiller")
e1:Toggle({ Name = "Survivor ESP", Default = false, Callback = function(v) S.ESP.Survivor.Enabled = v end }, "ESPSurv")
e1:Toggle({ Name = "Killer Aura", Default = false, Callback = function(v) S.ESP.Killer.Aura = v end }, "ESPKillerAura")
e1:Toggle({ Name = "Survivor Aura", Default = false, Callback = function(v) S.ESP.Survivor.Aura = v end }, "ESPSurvAura")
e1:Toggle({ Name = "Killer Tracer", Default = false, Callback = function(v) S.ESP.Killer.Tracer = v end }, "ESPKillerTracer")
e1:Toggle({ Name = "Survivor Tracer", Default = false, Callback = function(v) S.ESP.Survivor.Tracer = v end }, "ESPSurvTracer")
e1:Colorpicker({ Name = "Killer color", Default = Color3.fromRGB(255,0,0), Callback = function(c) S.ESP.Killer.AuraColor = c S.ESP.Killer.TracerColor = c end }, "ESPKillerColor")
e1:Colorpicker({ Name = "Survivor color", Default = Color3.fromRGB(0,255,0), Callback = function(c) S.ESP.Survivor.AuraColor = c S.ESP.Survivor.TracerColor = c end }, "ESPSurvColor")

local e2 = tESP:Section({ Side = "Right" })
e2:Header({ Name = "Objects", Icon = "folder" })
e2:Toggle({ Name = "Generator", Default = false, Callback = function(v) S.ESP.Generator.Enabled = v end }, "ESPGen")
e2:Toggle({ Name = "Generator Cham", Default = false, Callback = function(v) S.ESP.Generator.Cham = v end }, "ESPGenCham")
e2:Toggle({ Name = "Pallet", Default = false, Callback = function(v) S.ESP.Pallet.Enabled = v end }, "ESPPallet")
e2:Toggle({ Name = "Pallet Cham", Default = false, Callback = function(v) S.ESP.Pallet.Cham = v end }, "ESPPalletCham")
e2:Toggle({ Name = "Window/Vault", Default = false, Callback = function(v) S.ESP.Vault.Enabled = v end }, "ESPVault")
e2:Toggle({ Name = "Vault Cham", Default = false, Callback = function(v) S.ESP.Vault.Cham = v end }, "ESPVaultCham")
e2:Toggle({ Name = "Hook", Default = false, Callback = function(v) S.ESP.Hook.Enabled = v end }, "ESPHook")
e2:Toggle({ Name = "Hook Cham", Default = false, Callback = function(v) S.ESP.Hook.Cham = v end }, "ESPHookCham")
e2:Toggle({ Name = "Gate", Default = false, Callback = function(v) S.ESP.Gate.Enabled = v end }, "ESPGate")
e2:Toggle({ Name = "Gate Cham", Default = false, Callback = function(v) S.ESP.Gate.Cham = v end }, "ESPGateCham")
-- Locker cham toggle: the chams loop matches "Locker" models; without this row
-- S.ESP.Locker.Cham was unreachable dead state. Color uses the locker default.
e2:Toggle({ Name = "Locker Cham", Default = false, Callback = function(v) S.ESP.Locker.Cham = v end }, "ESPLockerCham")
e2:Slider({ Name = "Max distance", Default = 5000, Minimum = 200, Maximum = 10000, Callback = function(v) S.ESP.MaxDist = v end }, "ESPMaxDist")

-- Move tab
local m1 = tMove:Section({ Side = "Left" })
m1:Header({ Name = "Movement", Icon = "code" })
m1:Toggle({ Name = "Speed", Default = false, Callback = function(v) S.Move.Speed = v end }, "Speed")
m1:Slider({ Name = "Speed mult", Default = 130, Minimum = 100, Maximum = 300, Callback = function(v) S.Move.SpeedVal = v / 100 end }, "SpeedVal")
m1:Toggle({ Name = "Noclip", Default = false, Callback = function(v) S.Move.Noclip = v end }, "Noclip")
-- Bind policy: no default key (RightShift window bind is the only exception)
m1:Keybind({ Name = "Noclip bind", Callback = function() S.Move.Noclip = not S.Move.Noclip end }, "NoclipBind")
m1:Toggle({ Name = "Fly", Default = false, Callback = function(v) setFly(v) end }, "Fly")
m1:Slider({ Name = "Fly speed", Default = 60, Minimum = 10, Maximum = 250, Callback = function(v) S.Move.FlySpeed = v end }, "FlySpeed")
m1:Toggle({ Name = "Legit Jump", Default = false, Callback = function(v) S.Move.Jump = v end }, "JumpMod")
m1:Slider({ Name = "Jump power", Default = 50, Minimum = 50, Maximum = 120, Callback = function(v) S.Move.JumpPower = v end }, "JumpPower")
m1:Toggle({ Name = "Spider", Default = false, Callback = function(v) S.Move.Spider = v end }, "Spider")
m1:Slider({ Name = "Spider speed", Default = 20, Minimum = 0, Maximum = 100, Callback = function(v) S.SpiderMod.Speed = v end }, "SpiderSpeed")
m1:Slider({ Name = "Spider radius", Default = 25, Minimum = 10, Maximum = 90, Callback = function(v) S.SpiderMod.Radius = v / 10 end }, "SpiderRadius")
m1:Slider({ Name = "Spider max angle", Default = 10, Minimum = 0, Maximum = 90, Callback = function(v) S.SpiderMod.MaxAngleDeg = v end }, "SpiderAngle")
m1:Dropdown({ Name = "Spider method", Options = {"Velocity", "CFrame"}, Default = 1, Callback = function(v) S.SpiderMod.Method = v end }, "SpiderMethod")
m1:Toggle({ Name = "Spider reset vel", Default = false, Callback = function(v) S.SpiderMod.ResetVel = v end }, "SpiderResetVel")
-- "Noclip pallets" toggle removed: UI-only placeholder (TeleNoclipPallets was
-- never read by any noclip implementation).
m1:Keybind({ Name = "Fly bind", Callback = function() setFly(not S.Move.Fly) end }, "FlyBind")

local mF = tMove:Section({ Side = "Right" })
mF:Header({ Name = "Float", Icon = "code" })
mF:Toggle({ Name = "Float", Default = false, Callback = function(v) setFloat(v) end }, "Float")
mF:Dropdown({ Name = "Float method", Options = {"Part", "LinearVelocity"}, Default = 1, Callback = function(v) S.FloatMod.Method = v if S.FloatMod.Enabled then setFloat(true) end end }, "FloatMethod")
mF:Slider({ Name = "Up offset", Default = 0, Minimum = 0, Maximum = 100, Callback = function(v) S.FloatMod.UpOffset = v / 100 end }, "FloatUpOff")
mF:Slider({ Name = "Down offset", Default = 0, Minimum = 0, Maximum = 100, Callback = function(v) S.FloatMod.DownOffset = v / 100 end }, "FloatDownOff")
mF:Slider({ Name = "Up speed", Default = 20, Minimum = 1, Maximum = 100, Callback = function(v) S.FloatMod.UpSpeed = v end }, "FloatUpSpeed")
mF:Slider({ Name = "Down speed", Default = 20, Minimum = 1, Maximum = 100, Callback = function(v) S.FloatMod.DownSpeed = v end }, "FloatDownSpeed")
mF:Colorpicker({ Name = "Float color", Default = Color3.fromRGB(163,162,165), Callback = function(c) S.FloatMod.Color = c end }, "FloatColor")
mF:Keybind({ Name = "Float up", onBinded = function(b) S.FloatMod.UpKey = b end }, "FloatUp")
mF:Keybind({ Name = "Float down", onBinded = function(b) S.FloatMod.DownKey = b end }, "FloatDown")

local m2 = tMove:Section({ Side = "Right" })
m2:Header({ Name = "Camera", Icon = "sun" })
m2:Toggle({ Name = "FOV changer", Default = false, Callback = function(v) S.Move.FovOn = v end }, "FovOn")
m2:Slider({ Name = "FOV", Default = 70, Minimum = 40, Maximum = 120, Callback = function(v) S.Move.Fov = v end }, "FovVal")

-- Visual tab
local v1 = tVisual:Section({ Side = "Left" })
v1:Header({ Name = "World", Icon = "sun" })
v1:Toggle({ Name = "Fullbright", Default = false, Callback = function(v) S.Visual.Fullbright = v end }, "Fullbright")
v1:Toggle({ Name = "No Fog", Default = false, Callback = function(v) S.Visual.NoFog = v end }, "NoFog")
v1:Toggle({ Name = "AntiAFK", Default = false, Callback = function(v) setAntiAFK(v) end }, "AntiAFK")
v1:Toggle({ Name = "AntiFling", Default = false, Callback = function(v) S.Visual.AntiFling = v end }, "AntiFling")
v1:Toggle({ Name = "Cape", Default = false, Callback = function(v) setCape(v) end }, "Cape")
v1:Input({ Name = "Cape texture", Placeholder = "rbxassetid://...", Callback = function() end }, "CapeTexture")
v1:Button({ Name = "Apply cape texture", Icon = "image", Callback = function()
    pcall(function() S.CapeMod.Texture = MacLib.Flags.CapeTexture:GetInput() end)
    if S.CapeMod.Enabled and T.cape.buildTexture then T.cape.buildTexture() end
end })
local v2 = tVisual:Section({ Side = "Right" })
v2:Header({ Name = "Camera", Icon = "eye" })
v2:Toggle({ Name = "Freecam", Default = false, Callback = function(v) setFreecam(v) end }, "Freecam")
v2:Slider({ Name = "Freecam speed", Default = 1, Minimum = 0, Maximum = 10, Callback = function(v) S.FreecamAdv.Speed = v end }, "FreecamAdvSpeed")
v2:Slider({ Name = "Shift multiplier", Default = 2, Minimum = 0, Maximum = 10, Callback = function(v) S.FreecamAdv.ShiftMult = v end }, "FreecamShift")
v2:Slider({ Name = "Sensitivity", Default = 10, Minimum = 1, Maximum = 30, Callback = function(v) S.FreecamAdv.Sens = v / 10 end }, "FreecamSens")
v2:Toggle({ Name = "Camera limits", Default = true, Callback = function(v) S.FreecamAdv.Limits = v end }, "FreecamLimits")
v2:Toggle({ Name = "Unlock cursor in menu", Default = true, Callback = function(v) S.Cursor.Unlock = v end }, "CursorUnlock")
v2:Toggle({ Name = "CameraPhase", Default = false, Callback = function(v) setCameraPhase(v) end }, "CameraPhase")

-- Teleport tab
local tp = tTele:Section({ Side = "Left" })
tp:Header({ Name = "Teleport", Icon = "folder" })
tp:Button({ Name = "To Killer", Icon = "eye", Callback = function()
    for _, p in ipairs(Players:GetPlayers()) do
        if isKiller(p) and p ~= LocalPlayer and hrpOf(p.Character) then tpTo(hrpOf(p.Character).CFrame) break end
    end
end })
tp:Button({ Name = "To Random Survivor", Icon = "user", Callback = function()
    local cands = {}
    for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer and not isKiller(p) and hrpOf(p.Character) then table.insert(cands, p) end end
    if #cands > 0 then local p = cands[math.random(1, #cands)] tpTo(hrpOf(p.Character).CFrame) end
end })
tp:Button({ Name = "To Nearest Generator", Icon = "bolt", Callback = function()
    local list = collectUsables(function(n) return string.find(n, "Generator") end)
    if #list == 0 then
        local g = nearestModel(mapFolder({"Generators","Gens"}))
        if g then tpTo(g.CFrame) else notify("TP", "no generator (round active?)") end
        return
    end
    local e = nearestUsable(list)
    if e then tpTo(e.part.CFrame) end
end })
tp:Button({ Name = "To Nearest Pallet (usable)", Icon = "folder", Callback = function()
    local list = collectUsables(function(n) return string.find(n, "Pallet") end)
    if #list == 0 then notify("TP", "no usable pallet (props skipped)") return end
    local e = nearestUsable(list)
    if e then tpTo(e.part.CFrame) notify("TP", "pallet + prompt") end
end })
tp:Button({ Name = "To Gate / Exit", Icon = "check", Callback = function()
    local list = collectUsables(function(n)
        return n == "Gate" or n == "Exit" or string.find(n, "Escape") or string.find(n, "Lever")
    end)
    if #list == 0 then
        -- fallback: biggest Gate part anywhere (map folders Exit1/Exit2)
        local big, bs = nil, 0
        for _, d in ipairs(Workspace:GetDescendants()) do
            if d:IsA("BasePart") then
                local a = d:GetFullName()
                if string.find(a, "Gate") or string.find(a, "Exit") then
                    if d.Size.Magnitude > bs then big, bs = d, d.Size.Magnitude end
                end
            end
        end
        if big then tpTo(big.CFrame) else notify("TP", "no gate (round active?)") end
        return
    end
    local e = nearestUsable(list)
    if e then tpTo(e.part.CFrame) end
end })
tp:Button({ Name = "To Lobby", Icon = "clock", Callback = function()
    local l = Workspace:FindFirstChild("Lobby")
    if l then local p = l:FindFirstChildWhichIsA("BasePart", true) if p then tpTo(p.CFrame) end end
end })
tp:Button({ Name = "Open Gate (prompt+remote)", Icon = "key", Callback = function()
    local n = 0
    local list = collectUsables(function(nm)
        return nm == "Gate" or nm == "Exit" or string.find(nm, "Escape") or string.find(nm, "Lever")
    end)
    for _, e in ipairs(list) do
        if e.prompt and firePrompt(e.prompt) then n += 1 end
    end
    -- backup: direct remotes (server does not validate)
    fireRemote("Remotes.Exit.LeverEvent", myHRP())
    fireRemote("Remotes.Exit.LeverEvent")
    fireRemote("Remotes.Items.Gate.gate", myHRP())
    notify("Gate", n > 0 and ("prompts fired: " .. n) or "remotes fired (no prompt found)")
end })
tp:Button({ Name = "Finish game (TP end)", Icon = "check", Callback = function()
    local map = Workspace:FindFirstChild("Map")
    if map then
        local f = map:FindFirstChild("Fininshline") or map:FindFirstChildWhichIsA("SpawnLocation", true)
        if f and f:IsA("BasePart") then tpTo(f.CFrame) else notify("Finish", "no finish part") end
    end
end })

local tp2 = tTele:Section({ Side = "Right" })
tp2:Header({ Name = "Players", Icon = "user" })
tp2:Input({ Name = "Player name", Placeholder = "username", Callback = function() end }, "TPName")
tp2:Button({ Name = "TP to player", Icon = "user", Callback = function()
    local name = ""
    pcall(function() name = MacLib.Flags.TPName:GetInput() end)
    local plr = Players:FindFirstChild(name)
    if plr and hrpOf(plr.Character) then tpTo(hrpOf(plr.Character).CFrame) else notify("TP", "player not found") end
end })
tp2:Button({ Name = "Self Unhook (anticamp)", Icon = "lock", Callback = function()
    fireRemote("Remotes.Carry.SelfUnHookEvent")
    notify("Unhook", "SelfUnHook fired")
end })
tp2:Button({ Name = "Save teammate (UnHook)", Icon = "heart", Callback = function()
    fireRemote("Remotes.Carry.UnHookEvent", myHRP())
end })

-- Misc tab
local mi = tMisc:Section({ Side = "Left" })
mi:Header({ Name = "Misc", Icon = "sliders" })
local lastAvatarId = 0 -- запоминаем применённый userid для корректного reset
mi:Input({ Name = "Avatar userid", Placeholder = "12345", Callback = function() end }, "AvatarID")
mi:Button({ Name = "Avatar by userid", Icon = "user", Callback = function()
    local raw = ""
    local flag = MacLib.Flags and MacLib.Flags.AvatarID
    pcall(function() if flag and flag.GetInput then raw = tostring(flag:GetInput()) end end)
    if raw == "" then raw = tostring(S.Config and S.Config.AvatarID or "") end
    local id = tonumber((raw:gsub("%D", ""))) or 0
    if id <= 0 then notify("Avatar", "enter a valid userid first", "error"); return end
    -- сетевой вызов выносим за pcall-обёртку так, чтобы ошибку было видно;
    -- на Real GetHumanoidDescriptionFromUserId работает только из unsandboxed контекста
    local ok, descOrErr = pcall(function() return Players:GetHumanoidDescriptionFromUserId(id) end)
    if not ok or descOrErr == nil then
        notify("Avatar", "userid " .. id .. " not found / fetch blocked", "error"); return
    end
    local char = LocalPlayer.Character
    local hum = humOf(char)
    if not hum then notify("Avatar", "no character / respawn first", "error"); return end
    local ok2, err2 = pcall(function() hum:ApplyDescription(descOrErr) end)
    if ok2 then
        lastAvatarId = id
        notify("Avatar", "applied " .. id)
    else
        notify("Avatar", "apply failed: " .. tostring(err2), "error")
    end
end })
mi:Button({ Name = "Reset avatar", Icon = "cross", Callback = function()
    -- всегда восстанавливаем РОДНОЙ аватар игрока (LocalPlayer.UserId), а не последний uid
    local hum = humOf(LocalPlayer.Character)
    if not hum then notify("Avatar", "no character / respawn first", "error"); return end
    local ok, descOrErr = pcall(function() return Players:GetHumanoidDescriptionFromUserId(LocalPlayer.UserId) end)
    if not ok or descOrErr == nil then notify("Avatar", "native description fetch failed", "error"); return end
    local ok2 = pcall(function() hum:ApplyDescription(descOrErr) end)
    if ok2 then lastAvatarId = 0; notify("Avatar", "reset to native") else notify("Avatar", "reset failed", "error") end
end })
mi:Button({ Name = "Flinger (spin fling)", Icon = "bolt", Callback = function()
    local hrp = myHRP()
    if hrp then
        local bv = Instance.new("BodyAngularVelocity")
        bv.AngularVelocity = Vector3.new(0, 50, 0)
        bv.MaxTorque = Vector3.new(0, 1e6, 0)
        bv.Parent = hrp
        task.delay(1.5, function() pcall(function() bv:Destroy() end) end)
    end
end })
mi:Button({ Name = "DBD icon/sound (notify)", Icon = "bell", Callback = function()
    notify("DBD", "icon/sound swap: replace in Items/Gate.audio + tool textures (manual)")
end })
mi:Toggle({ Name = "Remove Escape Gates (client)", Default = false, Callback = function(v)
    local map = Workspace:FindFirstChild("Map")
    if map then
        for _, c in ipairs(map:GetChildren()) do
            if c.Name == "Gate" then pcall(function() c:Destroy() end) end
        end
    end
    if v then notify("Gates", "removed (client, one round)") end
end }, "RemoveGates")
mi:Toggle({ Name = "No gameplay paused popup", Default = false, Callback = function(v)
    pcall(function() GuiService:SetGameplayPausedNotificationEnabled(not v) end)
end }, "NoPausedPopup")

-- Anim tab (Tidal Animations, R6-ready)
local aSpd = tAnim:Section({ Side = "Left" })
aSpd:Header({ Name = "AnimationSpeed", Icon = "bolt" })
aSpd:Toggle({ Name = "Enabled", Default = false, Callback = function(v) S.AnimMod.SpeedOn = v setAnimSpeed(v) end }, "AnimSpeedOn")
aSpd:Slider({ Name = "Speed", Default = 10, Minimum = 0, Maximum = 30, Callback = function(v) S.AnimMod.Speed = v / 10 end }, "AnimSpeed")
aSpd:Toggle({ Name = "Use multi", Default = false, Callback = function(v) S.AnimMod.UseMulti = v end }, "AnimMultiOn")
aSpd:Slider({ Name = "Multi", Default = 10, Minimum = 0, Maximum = 30, Callback = function(v) S.AnimMod.Multi = v / 10 end }, "AnimMulti")
local aT = tAnim:Section({ Side = "Right" })
aT:Header({ Name = "Target movers", Icon = "user" })
aT:Input({ Name = "Target player", Placeholder = "username", Callback = function() end }, "AnimTarget")
aT:Button({ Name = "Bang (target)", Icon = "bolt", Callback = function()
    local inp = MacLib.Flags.AnimTarget:GetInput()
    local hrp = targetRoot(inp)
    if not hrp then notify("Bang", "no target") return end
    local hum = humOf(LocalPlayer.Character)
    local rig = hum and hum.RigType
    stopAnimTrack("Bang")
    T.anims.Bang = loadAnimTrack(rig == Enum.HumanoidRigType.R15 and "rbxassetid://5918726674" or "rbxassetid://148840371", true, S.AnimMod.BangSpeed * 3)
    if T.anims.Bang then T.anims.Bang.Priority = Enum.AnimationPriority.Action4 end
    targetMoverLoop("Bang", true, { moverTo("Bang", CFrame.new(0, 0, 1.1), "AnimTarget") })
    S.AnimMod.BangOn = true
end })
aT:Button({ Name = "Stop movers", Icon = "cross", Callback = function()
    S.AnimMod.BangOn = false
    for _, n in ipairs({ "Bang", "BendOver", "Carpet", "HeadSit", "Orbit" }) do
        targetMoverLoop(n, false, {})
        stopAnimTrack(n)
    end
end })
aT:Button({ Name = "BendOver (target)", Icon = "user", Callback = function()
    local hum = humOf(LocalPlayer.Character)
    if not hum or hum.RigType ~= Enum.HumanoidRigType.R15 then notify("BendOver", "R15 only") return end
    stopAnimTrack("BendOver")
    T.anims.BendOver = loadAnimTrack("rbxassetid://10214311282", false, 1)
    if T.anims.BendOver then
        T.anims.BendOver.Priority = Enum.AnimationPriority.Action4
        T.anims.BendOver.TimePosition = 4
        T.anims.BendOver:AdjustSpeed(0)
    end
    targetMoverLoop("BendOver", true, { moverTo("BendOver", CFrame.new(0.4, 0, -2.1) * CFrame.Angles(0, math.rad(14), 0), "AnimTarget") })
end })
aT:Button({ Name = "Carpet (target)", Icon = "user", Callback = function()
    local hum = humOf(LocalPlayer.Character)
    stopAnimTrack("Carpet")
    if hum and hum.RigType == Enum.HumanoidRigType.R6 then
        T.anims.Carpet = loadAnimTrack("rbxassetid://282574440", true, 1)
        if T.anims.Carpet then T.anims.Carpet.Priority = Enum.AnimationPriority.Action4 end
    end
    targetMoverLoop("Carpet", true, { function()
        local input = MacLib.Flags.AnimTarget:GetInput()
        local hrp = targetRoot(input)
        local my = myHRP()
        local myHum = humOf(LocalPlayer.Character)
        if hrp and my and myHum then
            if myHum.RigType == Enum.HumanoidRigType.R15 then
                my.CFrame = hrp.CFrame:ToWorldSpace(CFrame.Angles(math.rad(-90), 0, 0) + Vector3.new(0, -myHum.HipHeight, 0))
            else
                my.CFrame = hrp.CFrame
            end
            my.AssemblyLinearVelocity = Vector3.zero
        end
    end })
end })
aT:Button({ Name = "HeadSit (target)", Icon = "user", Callback = function()
    local hum = humOf(LocalPlayer.Character)
    if hum then pcall(function() hum.Sit = true end) end
    targetMoverLoop("HeadSit", true, { moverTo("HeadSit", CFrame.new(0, 1.6, 0.4), "AnimTarget") })
end })
aT:Button({ Name = "Orbit (target)", Icon = "user", Callback = function()
    S.AnimMod.OrbitRot = 0
    targetMoverLoop("Orbit", true, { function(dt)
        local input = MacLib.Flags.AnimTarget:GetInput()
        local hrp = targetRoot(input)
        local my = myHRP()
        if hrp and my then
            S.AnimMod.OrbitRot = (S.AnimMod.OrbitRot or 0) + S.AnimMod.OrbitSpeed * dt
            my.CFrame = CFrame.new(hrp.Position) * CFrame.Angles(0, math.rad(S.AnimMod.OrbitRot), 0) * CFrame.new(0, 0, S.AnimMod.OrbitDist)
            my.AssemblyLinearVelocity = Vector3.zero
        end
    end })
end })
aT:Button({ Name = "Stare (target)", Icon = "eye", Callback = function()
    targetMoverLoop("Stare", true, { function()
        local input = MacLib.Flags.AnimTarget:GetInput()
        local hrp = targetRoot(input)
        local my = myHRP()
        if hrp and my then
            my.CFrame = CFrame.lookAt(my.Position, Vector3.new(hrp.Position.X, my.Position.Y, hrp.Position.Z))
        end
    end })
end })
local aSolo = tAnim:Section({ Side = "Left" })
aSolo:Header({ Name = "Solo", Icon = "bolt" })
aSolo:Dropdown({ Name = "R6 dance", Options = {"Dance", "Moonwalk", "Dance Like There's no Tomorrow", "Disco", "Party", "Goal", "Flute Dance"}, Default = 1, Callback = function(v)
    S.AnimMod.DanceR6 = v
    if S.AnimMod.DanceOn then danceApply() end
end }, "DanceR6")
aSolo:Dropdown({ Name = "R15 dance", Options = {"River Dance", "Keeping Time", "Line Dance", "Air Dance", "Break Dance", "Reflex", "Around Town", "Idol Face", "Fancy Feet", "Robot", "Still Standing"}, Default = 1, Callback = function(v)
    S.AnimMod.DanceR15 = v
    if S.AnimMod.DanceOn then danceApply() end
end }, "DanceR15")
aSolo:Toggle({ Name = "Dance", Default = false, Callback = function(v) S.AnimMod.DanceOn = v if v then danceApply() else stopAnimTrack("Dance") end end }, "DanceOn")
aSolo:Toggle({ Name = "HeadThrow (R6)", Default = false, Callback = function(v)
    if v then
        local hum = humOf(LocalPlayer.Character)
        if not hum or hum.RigType ~= Enum.HumanoidRigType.R6 then notify("HeadThrow", "R6 only") return end
        stopAnimTrack("HeadThrow")
        T.anims.HeadThrow = loadAnimTrack("rbxassetid://35154961", true, S.AnimMod.HeadThrowSpeed)
        if T.anims.HeadThrow then T.anims.HeadThrow.Priority = Enum.AnimationPriority.Action4 end
    else stopAnimTrack("HeadThrow") end
end }, "HeadThrowOn")
aSolo:Slider({ Name = "HeadThrow speed", Default = 10, Minimum = 0, Maximum = 100, Callback = function(v)
    S.AnimMod.HeadThrowSpeed = v / 10
    if T.anims.HeadThrow then T.anims.HeadThrow:AdjustSpeed(v / 10) end
end }, "HeadThrowSpeed")
aSolo:Toggle({ Name = "Jerk", Default = false, Callback = function(v)
    if v then
        local hum = humOf(LocalPlayer.Character)
        local rig = hum and hum.RigType
        stopAnimTrack("Jerk")
        T.anims.Jerk = loadAnimTrack(rig == Enum.HumanoidRigType.R15 and "rbxassetid://698251653" or "rbxassetid://72042024", false, S.AnimMod.JerkSpeed * 0.7)
        if T.anims.Jerk then
            T.anims.Jerk.Priority = Enum.AnimationPriority.Action4
            T.anims.Jerk.TimePosition = 0.6
        end
    else stopAnimTrack("Jerk") end
end }, "JerkOn")
aSolo:Slider({ Name = "Jerk speed", Default = 10, Minimum = 0, Maximum = 100, Callback = function(v)
    S.AnimMod.JerkSpeed = v / 10
    if T.anims.Jerk then T.anims.Jerk:AdjustSpeed(v / 10 * 0.7) end
end }, "JerkSpeed")
aSolo:Toggle({ Name = "Spasm (R6)", Default = false, Callback = function(v)
    if v then
        local hum = humOf(LocalPlayer.Character)
        if not hum or hum.RigType ~= Enum.HumanoidRigType.R6 then notify("Spasm", "R6 only") return end
        stopAnimTrack("Spasm")
        T.anims.Spasm = loadAnimTrack("rbxassetid://33796059", true, 100)
        if T.anims.Spasm then T.anims.Spasm.Priority = Enum.AnimationPriority.Action4 end
    else stopAnimTrack("Spasm") end
end }, "SpasmOn")
aSolo:Slider({ Name = "Bang speed", Default = 10, Minimum = 0, Maximum = 30, Callback = function(v)
    S.AnimMod.BangSpeed = v / 10
    if T.anims.Bang then T.anims.Bang:AdjustSpeed(v / 10 * 3) end
end }, "BangSpeed")
aSolo:Slider({ Name = "Orbit speed", Default = 45, Minimum = 0, Maximum = 360, Callback = function(v) S.AnimMod.OrbitSpeed = v end }, "OrbitSpeed")
aSolo:Slider({ Name = "Orbit distance", Default = 50, Minimum = 0, Maximum = 200, Callback = function(v) S.AnimMod.OrbitDist = v / 10 end }, "OrbitDist")

-- Config tab (per gitbook config)
tConfig:InsertConfigSection("Left")
local cs = tConfig:Section({ Side = "Right" })
cs:Header({ Name = "Keybinds", Icon = "bolt" })
cs:Button({ Name = "Clear ALL feature binds", Icon = "cross", Callback = function()
    -- menu open/close key (RightShift on the Window) is NOT touched by design
    local cleared = 0
    for _, f in ipairs({ "ParryBind", "SkillBind", "DaggerBind", "UnstickBind", "BreakPalletBind", "HookBind", "NoclipBind", "FlyBind", "FloatUp", "FloatDown" }) do
        local el = MacLib.Flags[f]
        if el and el.Unbind then el:Unbind(); cleared = cleared + 1 end
    end
    notify("Binds", "cleared " .. cleared .. " feature binds (menu key stays)")
end })

cs:Header({ Name = "Window", Icon = "sun" })
cs:Button({ Name = "Unload hub", Icon = "cross", Callback = function()
    alive = false
    pcall(mwRestore)
    local pt = S._lastRepairPt
    if pt and pt.Parent then pcall(function()
        getRemote("Remotes.Generator.RepairEvent"):FireServer(pt, true)
    end) end
    pcall(function() setFloat(false) end)
    pcall(function() setCape(false) end)
    pcall(function() setCameraPhase(false) end)
    pcall(function() setVaultAngle(false) end)
    pcall(function() setVaultSpeed(false) end)
    pcall(function() setFinesse(false) end)
    pcall(function() setAnimSpeed(false) end)
    for _, n in ipairs({ "Bang", "BendOver", "Carpet", "HeadSit", "Orbit", "Stare", "Dance", "HeadThrow", "Jerk", "Spasm" }) do
        targetMoverLoop(n, false, {})
        stopAnimTrack(n)
    end
    clearAllDraw()
    pcall(clearChams)
    setFly(false)
    setFreecam(false)
    for _, p in ipairs(Players:GetPlayers()) do if p.Character then setAura(p.Character, false, Color3.new(0,0,0)) end end
    pcall(function() UserInputService.MouseIconEnabled = true end)
    pcall(function() Window:Unload() end)
end })

Window.onUnloaded(function()
    alive = false
    pcall(mwRestore)
    pcall(clearAllDraw)
    pcall(clearChams)
end)
tCombat:Select()

getgenv().VDHubIO_Unload = function()
    alive = false
    pcall(mwRestore)
    pcall(clearAllDraw)
    pcall(clearChams)
    pcall(function() setFly(false) end)
    pcall(function() setFreecam(false) end)
    pcall(function() Window:Unload() end)
end

notify("Violence District", "v3 io-lib loaded")
