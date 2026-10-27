-- Maclib
-- macOS Sequoia interface for Roblox executors.
-- Drop-in compatible with https://brady-xyz.gitbook.io/maclib-ui-library
--
--   local MacLib = loadstring(readfile("maclib.lua"))()
--   local Window = MacLib:Window({ Title = "App", Subtitle = "1.0", Keybind = Enum.KeyCode.RightControl })

local MacLib = { Version = "2.1.0", Build = "fonts-and-island", Flags = {}, Windows = {}, Folder = "Maclib" }

pcall(function()
	local env = (getgenv :: any)()
	local previous = env and env.Maclib
	if previous and previous ~= MacLib and type(previous.UnloadAll) == "function" then
		previous:UnloadAll()
	end
	if env then
		env.Maclib = MacLib
	end
end)

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local function pickFont(name, fallback)
	local ok, f = pcall(function()
		return Enum.Font[name]
	end)
	if ok and f then
		return f
	end
	return fallback
end

local fontSets = {
	Gotham = {
		regular = pickFont("Gotham", Enum.Font.Gotham),
		medium = pickFont("GothamMedium", Enum.Font.Gotham),
		bold = pickFont("GothamBold", Enum.Font.Gotham),
	},
	Modern = {
		regular = pickFont("SourceSans", Enum.Font.Gotham),
		medium = pickFont("SourceSansSemibold", pickFont("SourceSans", Enum.Font.Gotham)),
		bold = pickFont("SourceSansBold", pickFont("SourceSans", Enum.Font.Gotham)),
	},
	Classic = {
		regular = pickFont("Garamond", Enum.Font.Gotham),
		medium = pickFont("Garamond", Enum.Font.Gotham),
		bold = pickFont("Bodoni", Enum.Font.Gotham),
	},
	Mono = {
		regular = pickFont("Code", Enum.Font.Gotham),
		medium = pickFont("Code", Enum.Font.Gotham),
		bold = pickFont("Code", Enum.Font.Gotham),
	},
	Arcade = {
		regular = pickFont("Arcade", Enum.Font.Gotham),
		medium = pickFont("Arcade", Enum.Font.Gotham),
		bold = pickFont("Arcade", Enum.Font.Gotham),
	},
	Comic = {
		regular = pickFont("Cartoon", Enum.Font.Gotham),
		medium = pickFont("Cartoon", Enum.Font.Gotham),
		bold = pickFont("Bangers", pickFont("Cartoon", Enum.Font.Gotham)),
	},
	Spooky = {
		regular = pickFont("Creepster", Enum.Font.Gotham),
		medium = pickFont("Creepster", Enum.Font.Gotham),
		bold = pickFont("Creepster", Enum.Font.Gotham),
	},
	Handwritten = {
		regular = pickFont("IndieFlower", Enum.Font.Gotham),
		medium = pickFont("PatrickHand", pickFont("IndieFlower", Enum.Font.Gotham)),
		bold = pickFont("IndieFlower", Enum.Font.Gotham),
	},
	SciFi = {
		regular = pickFont("SciFi", Enum.Font.Gotham),
		medium = pickFont("SciFi", Enum.Font.Gotham),
		bold = pickFont("SciFi", Enum.Font.Gotham),
	},
	Bold = {
		regular = pickFont("GothamBold", Enum.Font.Gotham),
		medium = pickFont("GothamBlack", Enum.Font.GothamBold),
		bold = pickFont("GothamBlack", Enum.Font.GothamBold),
	},
}

-- aliases so older scripts that already call SetFont("Arial") etc. keep working
fontSets.Arial = {
	regular = pickFont("Arial", Enum.Font.Gotham),
	medium = pickFont("Arial", Enum.Font.Gotham),
	bold = pickFont("ArialBold", Enum.Font.Gotham),
}
fontSets["Source Sans"] = fontSets.Modern
fontSets.Roboto = {
	regular = pickFont("Roboto", Enum.Font.Gotham),
	medium = pickFont("Roboto", Enum.Font.Gotham),
	bold = pickFont("Roboto", Enum.Font.Gotham),
}
fontSets.Code = fontSets.Mono
local FONT = fontSets.Gotham.medium
local FONT_BOLD = fontSets.Gotham.bold
local FONT_REG = fontSets.Gotham.regular
local fontRegistry = {}
local colorRegistry = {}

local function registerFont(inst, font)
	local weight = "medium"
	if font == FONT_BOLD then
		weight = "bold"
	elseif font == FONT_REG then
		weight = "regular"
	end
	fontRegistry[inst] = weight
end

local function new(class, props)
	local inst = Instance.new(class)
	if props then
		for k, v in pairs(props) do
			if k ~= "Parent" then
				inst[k] = v
			end
		end
		if props.Parent then
			inst.Parent = props.Parent
		end
	end
	if inst:IsA("TextLabel") or inst:IsA("TextBox") or inst:IsA("TextButton") then
		registerFont(inst, inst.Font)
		colorRegistry[inst] = { bg = inst.BackgroundColor3, text = inst.TextColor3 }
	elseif inst:IsA("GuiObject") then
		colorRegistry[inst] = { bg = inst.BackgroundColor3 }
	end
	return inst
end

local function tween(inst, info, props)
	local t = TweenService:Create(inst, info, props)
	t:Play()
	return t
end

local function corner(parent, r)
	return new("UICorner", { CornerRadius = UDim.new(0, r), Parent = parent })
end

local function stroke(parent, color, thickness, transparency)
	local s = new("UIStroke", {
		Color = color or Color3.fromRGB(255, 255, 255),
		Thickness = math.max(1, math.floor((thickness or 1) + 0.5)),
		Transparency = math.clamp(transparency or 0.9, 0, 0.95),
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
	pcall(function()
		s.LineJoinMode = Enum.LineJoinMode.Round
	end)
	return s
end

local function padding(parent, t, b, l, r)
	return new("UIPadding", {
		PaddingTop = UDim.new(0, t or 0),
		PaddingBottom = UDim.new(0, b or t or 0),
		PaddingLeft = UDim.new(0, l or t or 0),
		PaddingRight = UDim.new(0, r or l or t or 0),
		Parent = parent,
	})
end

local function list(parent, dir, gap, align)
	return new("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 0),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		Parent = parent,
	})
end

-- keep a floating menu inside the viewport so it never spills off-screen
local function clampToScreen(inst, pad)
	pad = pad or 6
	local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local pos = inst.Position
	local x = math.clamp(pos.X.Offset, pad, math.max(pad, vp.X - inst.AbsoluteSize.X - pad))
	local y = math.clamp(pos.Y.Offset, pad, math.max(pad, vp.Y - inst.AbsoluteSize.Y - pad))
	inst.Position = UDim2.fromOffset(math.floor(x + 0.5), math.floor(y + 0.5))
end

local theme

-- Roblox resamples every border and glyph that lands on a half pixel, which reads
-- as jagged text and rough edges. Centering a window does exactly that when the
-- viewport or size is odd, so nudge anything we position onto whole pixels.
local function snapToPixel(inst)
	if theme.scale ~= 1 then
		return
	end
	local abs = inst.AbsolutePosition
	local dx = math.floor(abs.X + 0.5) - abs.X
	local dy = math.floor(abs.Y + 0.5) - abs.Y
	if dx ~= 0 or dy ~= 0 then
		inst.Position = inst.Position + UDim2.fromOffset(dx, dy)
	end
end

-- ---------------------------------------------------------------------------------------
-- icon set. every icon is drawn out of rounded frames so it stays crisp at any size,
-- needs no asset ids, and can be tinted like text.

local icons = {}

local function iconBox(parent, x, y, w, h, r, color, rot)
	local f = new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		Rotation = rot or 0,
		Parent = parent,
	})
	if r and r > 0 then
		corner(f, r)
	end
	return f
end

local function iconRing(parent, x, y, w, h, thickness, color)
	local f = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		Parent = parent,
	})
	corner(f, math.min(w, h) / 2)
	stroke(f, color, thickness, 0)
	return f
end

local function iconOutline(parent, x, y, w, h, r, thickness, color)
	local f = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		Parent = parent,
	})
	if r and r > 0 then
		corner(f, r)
	end
	stroke(f, color, thickness, 0)
	return f
end

icons.lens = function(p, c)
	iconRing(p, 2.5, 2.5, 11, 11, 1.8, c)
	iconBox(p, 13.5, 14.5, 6.5, 1.8, 0.9, c, 45)
end

icons.sliders = function(p, c)
	for i = 0, 2 do
		local y = 3.5 + i * 6
		iconBox(p, 1.5, y + 0.6, 17, 1.7, 0.85, c)
		iconBox(p, 3 + ((i * 5) % 10), y - 1.4, 4, 4, 2, c)
	end
end

icons.folder = function(p, c)
	iconBox(p, 3.5, 3.5, 7, 3.5, 1.5, c)
	iconBox(p, 2, 5.5, 16, 11, 2.5, c)
end

icons.clock = function(p, c)
	iconRing(p, 2, 2, 16, 16, 1.7, c)
	iconBox(p, 9.1, 5.5, 1.8, 5.5, 0.9, c)
	iconBox(p, 9.1, 9.3, 5, 1.8, 0.9, c)
end

icons.eye = function(p, c)
	iconOutline(p, 1.8, 5.1, 16.4, 9.8, 4.9, 1.6, c)
	iconBox(p, 7.7, 7.7, 4.6, 4.6, 2.3, c)
end

icons.lock = function(p, c)
	iconRing(p, 5.5, 1.5, 9, 9, 1.7, c)
	iconBox(p, 4, 7, 12, 10, 2.5, c)
end

icons.heart = function(p, c)
	iconBox(p, 4.4, 3.6, 7, 7, 3.5, c)
	iconBox(p, 8.6, 3.6, 7, 7, 3.5, c)
	iconBox(p, 5.6, 5.6, 8.8, 8.8, 1.4, c, 45)
end

icons.chat = function(p, c)
	iconBox(p, 2, 3.5, 16, 11, 3, c)
	iconBox(p, 4.5, 12, 4.5, 4.5, 1, c, 45)
end

icons.code = function(p, c)
	iconBox(p, 2.0, 6.6, 7, 1.8, 0.9, c, -45)
	iconBox(p, 2.0, 11.6, 7, 1.8, 0.9, c, 45)
	iconBox(p, 11.0, 6.6, 7, 1.8, 0.9, c, 45)
	iconBox(p, 11.0, 11.6, 7, 1.8, 0.9, c, -45)
end

icons.image = function(p, c)
	iconOutline(p, 1.8, 3.2, 16.4, 13.6, 2.6, 1.5, c)
	iconBox(p, 4.8, 6.0, 3, 3, 1.5, c)
	iconBox(p, 6.2, 11.2, 4.8, 4.8, 1.2, c, 45)
	iconBox(p, 11.6, 12.2, 3.6, 3.6, 1, c, 45)
end

icons.terminal = function(p, c)
	iconOutline(p, 1.5, 3, 17, 14, 3, 1.6, c)
	iconBox(p, 4.2, 7.2, 4, 1.6, 0.8, c, 45)
	iconBox(p, 4.2, 10.4, 4, 1.6, 0.8, c, -45)
	iconBox(p, 9.8, 11.6, 6, 1.7, 0.85, c)
end

icons.user = function(p, c)
	iconBox(p, 6.8, 2.2, 6.4, 6.4, 3.2, c)
	iconBox(p, 4.2, 10.4, 11.6, 8, 4, c)
end

icons.bell = function(p, c)
	iconBox(p, 4.6, 4.4, 10.8, 9.6, 4.6, c)
	iconBox(p, 3, 13.4, 14, 1.8, 0.9, c)
	iconBox(p, 8.9, 1.8, 2.2, 2.2, 1.1, c)
	iconBox(p, 8.4, 16.6, 3.2, 2.6, 1.3, c)
end

icons.key = function(p, c)
	iconRing(p, 1.5, 6, 8, 8, 1.8, c)
	iconBox(p, 9, 9, 9, 1.8, 0.9, c)
	iconBox(p, 13.5, 9, 1.8, 3.4, 0.9, c)
end

icons.plus = function(p, c)
	iconBox(p, 9, 3.5, 2.2, 13, 1.1, c)
	iconBox(p, 3.5, 9, 13, 2.2, 1.1, c)
end

icons.check = function(p, c)
	iconBox(p, 2.8, 9.6, 6.5, 2.1, 1, c, 45)
	iconBox(p, 7.6, 11.4, 10, 2.1, 1, c, -45)
end

icons.cross = function(p, c)
	iconBox(p, 3.5, 9.1, 13, 2, 1, c, 45)
	iconBox(p, 3.5, 9.1, 13, 2, 1, c, -45)
end

icons.dot = function(p, c)
	iconBox(p, 5.5, 5.5, 9, 9, 4.5, c)
end

icons.bolt = function(p, c)
	iconBox(p, 8.9, 1.4, 4.8, 9.6, 1.4, c, 30)
	iconBox(p, 6.3, 9.2, 4.8, 9.6, 1.4, c, 30)
end

icons.moon = function(p, c)
	iconBox(p, 3.5, 3.5, 13, 13, 6.5, c)
end

icons.sun = function(p, c)
	iconBox(p, 6.4, 6.4, 7.2, 7.2, 3.6, c)
	iconBox(p, 9.1, 0.8, 1.8, 3.4, 0.9, c)
	iconBox(p, 9.1, 15.8, 1.8, 3.4, 0.9, c)
	iconBox(p, 0.8, 9.1, 3.4, 1.8, 0.9, c)
	iconBox(p, 15.8, 9.1, 3.4, 1.8, 0.9, c)
	iconBox(p, 3.4, 3.4, 1.7, 3.2, 0.85, c, 45)
	iconBox(p, 14.9, 3.4, 1.7, 3.2, 0.85, c, -45)
	iconBox(p, 3.4, 13.4, 1.7, 3.2, 0.85, c, -45)
	iconBox(p, 14.9, 13.4, 1.7, 3.2, 0.85, c, 45)
end

local function iconBuild(name, parent, color)
	local builder = icons[name] or icons.dot
	builder(parent, color)
end

function MacLib:Icon(name, parent, size, color)
	size = size or 16
	local holder = new("Frame", {
		Name = "Icon_" .. tostring(name),
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		Parent = parent,
	})
	local scale = new("UIScale", { Scale = size / 20, Parent = holder })
	iconBuild(name, holder, color or C.text)
	return holder, scale
end

MacLib.IconNames = {}
for name in pairs(icons) do
	table.insert(MacLib.IconNames, name)
end
table.sort(MacLib.IconNames)

-- recolors either an ImageLabel icon or one of our drawn ones
local function tintIcon(icon, color)
	if icon:IsA("ImageLabel") or icon:IsA("ImageButton") then
		icon.ImageColor3 = color
		return
	end
	for _, d in ipairs(icon:GetDescendants()) do
		if d:IsA("UIStroke") then
			d.Color = color
		elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then
			d.BackgroundColor3 = color
		end
	end
end

local function safeParent()	local ok, hui = pcall(function()
		return gethui()
	end)
	if ok and hui then
		return hui
	end
	local ok2, cg = pcall(function()
		return CoreGui
	end)
	if ok2 and cg then
		return cg
	end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local C = {
	bg = Color3.fromRGB(28, 28, 30),
	bgDeep = Color3.fromRGB(22, 22, 24),
	sidebar = Color3.fromRGB(36, 36, 38),
	card = Color3.fromRGB(44, 44, 46),
	cardHover = Color3.fromRGB(58, 58, 60),
	elevated = Color3.fromRGB(54, 54, 56),
	separator = Color3.fromRGB(72, 72, 74),
	text = Color3.fromRGB(245, 245, 247),
	textDim = Color3.fromRGB(174, 174, 178),
	textFaint = Color3.fromRGB(110, 110, 115),
	accent = Color3.fromRGB(255, 255, 255),
	accentSoft = Color3.fromRGB(64, 156, 255),
	green = Color3.fromRGB(48, 209, 88),
	yellow = Color3.fromRGB(255, 214, 10),
	orange = Color3.fromRGB(255, 159, 10),
	red = Color3.fromRGB(255, 69, 58),
	pink = Color3.fromRGB(255, 55, 95),
	purple = Color3.fromRGB(191, 90, 242),
	teal = Color3.fromRGB(100, 210, 255),
	white = Color3.fromRGB(255, 255, 255),
	black = Color3.fromRGB(0, 0, 0),
	toggleOff = Color3.fromRGB(99, 99, 102),
}

local island

local function fs(path)
	local ok, res = pcall(function()
		return isfile(path)
	end)
	return ok and res or false
end
local function fd(path)
	local ok, res = pcall(function()
		return isfolder(path)
	end)
	return ok and res or false
end
local function wf(path, content)
	pcall(function()
		writefile(path, content)
	end)
end
local function rf(path)
	local ok, res = pcall(function()
		return readfile(path)
	end)
	if ok then
		return res
	end
	return nil
end
local function mf(path)
	pcall(function()
		makefolder(path)
	end)
end
local function lf(path)
	local ok, res = pcall(function()
		return listfiles(path)
	end)
	if ok and type(res) == "table" then
		return res
	end
	return {}
end
local function df(path)
	pcall(function()
		delfile(path)
	end)
end

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local o = {}
	for k, v in pairs(t) do
		o[k] = deepCopy(v)
	end
	return o
end

local function encode(v)
	local ok, res = pcall(function()
		return HttpService:JSONEncode(v)
	end)
	return ok and res or "{}"
end
local function decode(s)
	local ok, res = pcall(function()
		return HttpService:JSONDecode(s)
	end)
	if ok then
		return res
	end
	return nil
end

local function colorToTable(c)
	return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end
local function tableToColor(t)
	if type(t) ~= "table" then
		return Color3.new(1, 1, 1)
	end
	return Color3.fromRGB(t[1] or 255, t[2] or 255, t[3] or 255)
end

local function keyName(key)
	if typeof(key) == "EnumItem" then
		local n = key.Name
		local map = {
			LeftControl = "Ctrl",
			RightControl = "RCtrl",
			LeftShift = "Shift",
			RightShift = "RShift",
			LeftAlt = "Alt",
			RightAlt = "RAlt",
			MouseButton1 = "MB1",
			MouseButton2 = "MB2",
			MouseButton3 = "MB3",
			Backspace = "Bksp",
			Return = "Enter",
			Space = "Space",
			Escape = "Esc",
			Delete = "Del",
			Insert = "Ins",
			PageUp = "PgUp",
			PageDown = "PgDn",
			Up = "Up",
			Down = "Down",
			Left = "Left",
			Right = "Right",
		}
		if map[n] then
			return map[n]
		end
		if n:sub(1, 6) == "Keypad" then
			return "Num" .. n:sub(7)
		end
		if n:sub(1, 3) == "Key" and #n > 3 then
			return n:sub(4)
		end
		return n
	end
	return tostring(key)
end

local function filterChars(mode, text)
	if type(mode) == "function" then
		local ok, res = pcall(mode, text)
		return ok and res or text
	end
	if mode == "Numeric" then
		return text:gsub("[^0-9%.%-]", "")
	elseif mode == "Alphabetic" then
		return text:gsub("[^%a%s]", "")
	elseif mode == "AlphaNumeric" then
		return text:gsub("[^%w%s]", "")
	end
	return text
end

local function label(parent, text, size, color, font, xalign)
	return new("TextLabel", {
		BackgroundTransparency = 1,
		Font = font or FONT,
		TextSize = size or 13,
		TextColor3 = color or C.text,
		TextXAlignment = xalign or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = text or "",
		Parent = parent,
	})
end

-- ---------------------------------------------------------------------------------------
-- shared screen + theme

local screen = new("ScreenGui", {
	Name = "Maclib",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	DisplayOrder = 999,
	Parent = safeParent(),
})

pcall(function()
	local env = (getgenv :: any)()
	local guard = env and (env.protectgui or (env.syn and env.syn.protect_gui))
	if type(guard) == "function" then
		guard(screen)
	end
end)

MacLib._screen = screen

theme = {
	accent = C.accent,
	blur = true,
	notifications = true,
	reduceMotion = false,
	animation = "Spring",
	font = "Gotham",
	glass = 0.18,
	mode = "Glass",
	island = { clock = true, ping = false, fps = false, username = false, label = "" },
	scale = 1,
}

local lightBg = {
	[tostring(C.bg)] = Color3.fromRGB(242, 242, 247),
	[tostring(C.bgDeep)] = Color3.fromRGB(255, 255, 255),
	[tostring(C.card)] = Color3.fromRGB(255, 255, 255),
	[tostring(C.cardHover)] = Color3.fromRGB(238, 238, 242),
	[tostring(C.elevated)] = Color3.fromRGB(226, 226, 230),
	[tostring(C.separator)] = Color3.fromRGB(208, 208, 213),
	[tostring(C.toggleOff)] = Color3.fromRGB(200, 200, 205),
	[tostring(Color3.fromRGB(72, 72, 76))] = Color3.fromRGB(205, 205, 210),
	[tostring(Color3.fromRGB(90, 90, 94))] = Color3.fromRGB(200, 200, 205),
	[tostring(Color3.fromRGB(58, 58, 62))] = Color3.fromRGB(205, 205, 210),
}
local lightText = {
	[tostring(C.text)] = Color3.fromRGB(28, 28, 30),
	[tostring(C.textDim)] = Color3.fromRGB(95, 95, 100),
	[tostring(C.textFaint)] = Color3.fromRGB(135, 135, 140),
}

local function themed(color)
	if theme.mode == "White" then
		return lightBg[tostring(color)] or color
	end
	return color
end

local function applyModeColors(mode)
	for inst, saved in pairs(colorRegistry) do
		if not inst.Parent then
			colorRegistry[inst] = nil
		elseif not (island and inst:IsDescendantOf(island)) then
			if saved.bg then
				inst.BackgroundColor3 = (mode == "White" and lightBg[tostring(saved.bg)]) or saved.bg
			end
			if saved.text then
				inst.TextColor3 = (mode == "White" and lightText[tostring(saved.text)]) or saved.text
			end
		end
	end
end

local themeListeners = {}
local function onTheme(fn)
	table.insert(themeListeners, fn)
end
local function applyTheme()
	for _, fn in ipairs(themeListeners) do
		pcall(fn)
	end
end

local function motion(seconds)
	if theme.reduceMotion or theme.animation == "Off" then
		return TweenInfo.new(0.01, Enum.EasingStyle.Linear)
	end
	return TweenInfo.new(seconds or 0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
end

local function spring(seconds)
	if theme.reduceMotion or theme.animation == "Off" then
		return TweenInfo.new(0.01, Enum.EasingStyle.Linear)
	end
	if theme.animation == "Smooth" then
		return TweenInfo.new(seconds or 0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	end
	return TweenInfo.new(seconds or 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
end

local blurEffect
local function setBlur(on)
	theme.blur = on and true or false
	if blurEffect then
		tween(blurEffect, motion(0.25), { Size = 0 })
	end
end

-- lensing was dropped: a ViewportFrame can only refract cloned 3D, and in an empty
-- place that is just the character standing inside the camera, so it drew a block
-- through the controls. The glass, sheen and shadow carry the depth instead.

-- ---------------------------------------------------------------------------------------
-- dynamic island. every alert lands in one pill at the top and the pill grows to fit it.

island = new("Frame", {
	Name = "Island",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 14),
	Size = UDim2.fromOffset(126, 34),
	BackgroundColor3 = Color3.fromRGB(8, 8, 10),
	BackgroundTransparency = 0.04,
	ClipsDescendants = true,
	ZIndex = 60,
	Parent = screen,
})
local islandCorner = corner(island, 17)
local islandStroke = stroke(island, C.white, 1, 0.86)
local islandScale = new("UIScale", { Scale = 1, Parent = island })

-- while the island animates it stays center-anchored so it never jitters between
-- odd widths; once a tween settles it drops to integer offsets so the glyphs inside
-- land on whole pixels.
local islandAnimToken = 0
local function islandFloat()
	islandAnimToken += 1
	island.AnchorPoint = Vector2.new(0.5, 0)
	island.Position = UDim2.new(0.5, 0, 0, 14)
	return islandAnimToken
end
local function islandSettle(token)
	if token and token ~= islandAnimToken then
		return
	end
	local parent = island.Parent
	if not parent then
		return
	end
	local pw = parent.AbsoluteSize.X
	local w = island.AbsoluteSize.X
	if pw < 1 or w < 1 then
		return
	end
	island.AnchorPoint = Vector2.new(0, 0)
	island.Position = UDim2.fromOffset(math.floor((pw - w) / 2 + 0.5), 14)
end

local function evenize(n)
	local v = math.floor(n + 0.5)
	if v % 2 ~= 0 then
		v -= 1
	end
	return v
end

local function islandResize(w, h, seconds)
	w = evenize(w)
	h = evenize(h)
	local token = islandFloat()
	local t = tween(island, motion(seconds or 0.45), { Size = UDim2.fromOffset(w, h) })
	t.Completed:Connect(function()
		islandSettle(token)
	end)
end

-- a soft ring that expands off the island when it wakes up, so alerts feel physical
local islandRipple = new("Frame", {
	Name = "IslandRipple",
	AnchorPoint = Vector2.new(0, 0),
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(0, 0),
	Visible = false,
	ZIndex = 59,
	Parent = screen,
})
corner(islandRipple, 18)
local islandRippleStroke = stroke(islandRipple, C.white, 2, 1)

local function pulseRipple(color)
	local w = island.AbsoluteSize.X
	local h = island.AbsoluteSize.Y
	if w < 1 then
		return
	end
	islandRipple.Visible = true
	islandRipple.Size = UDim2.fromOffset(w, h)
	islandRipple.Position = UDim2.fromOffset(island.AbsolutePosition.X, island.AbsolutePosition.Y)
	islandRippleStroke.Color = color or C.white
	islandRippleStroke.Transparency = 0.25
	local t = tween(islandRipple, motion(0.5), {
		Size = UDim2.fromOffset(w + 26, h + 26),
		Position = UDim2.fromOffset(island.AbsolutePosition.X - 13, island.AbsolutePosition.Y - 13),
	})
	tween(islandRippleStroke, motion(0.5), { Transparency = 1 })
	t.Completed:Connect(function()
		islandRipple.Visible = false
	end)
end

-- slow breathing on the island rim while idle
local strokeBreath = TweenService:Create(
	islandStroke,
	TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ Transparency = 0.66 }
)

local function islandThemed()
	if theme.mode == "White" then
		island.BackgroundColor3 = Color3.fromRGB(246, 246, 248)
		islandStroke.Color = Color3.fromRGB(30, 30, 34)
		if not islandBusy then
			islandStroke.Transparency = 0.82
		end
	else
		island.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
		islandStroke.Color = C.white
		if not islandBusy then
			islandStroke.Transparency = 0.86
		end
	end
end

-- idle "live" dot with a radar ring that keeps expanding and fading while nothing
-- is happening, so the island always reads as an active object
local idleDot = new("Frame", {
	Name = "IdleDot",
	Position = UDim2.fromOffset(14, 13),
	Size = UDim2.fromOffset(8, 8),
	BackgroundColor3 = C.green,
	BorderSizePixel = 0,
	ZIndex = 61,
	Parent = island,
})
corner(idleDot, 8)

-- Apple-style idle: the dot just breathes, softly. No radar rings.
local idleScale = new("UIScale", { Scale = 1, Parent = idleDot })
local idleBreath = TweenService:Create(
	idleDot,
	TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ BackgroundTransparency = 0.5 }
)
local idleGrow = TweenService:Create(
	idleScale,
	TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ Scale = 1.35 }
)

local function idlePulseStart()
	idleDot.Visible = true
	idleDot.BackgroundTransparency = 0
	idleScale.Scale = 1
	if theme.reduceMotion or theme.animation == "Off" then
		idleBreath:Pause()
		idleGrow:Pause()
		return
	end
	idleBreath:Play()
	idleGrow:Play()
end

local function idlePulseStop()
	idleBreath:Pause()
	idleGrow:Pause()
	idleDot.Visible = false
	idleScale.Scale = 1
end

local islandRest = label(island, "Maclib", 12, C.textDim, FONT_BOLD, Enum.TextXAlignment.Left)
islandRest.Size = UDim2.new(0.5, -34, 1, 0)
islandRest.Position = UDim2.fromOffset(28, 0)
islandRest.TextTruncate = Enum.TextTruncate.AtEnd
islandRest.ZIndex = 62

local islandTime = label(island, "", 11, C.textFaint, FONT, Enum.TextXAlignment.Right)
islandTime.AnchorPoint = Vector2.new(1, 0.5)
islandTime.Position = UDim2.new(1, -14, 0.5, 0)
islandTime.Size = UDim2.new(0.6, -20, 1, 0)
islandTime.ZIndex = 62

local islandHit = new("TextButton", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 61,
	Parent = island,
})
islandHit.MouseEnter:Connect(function()
	tween(islandScale, motion(0.18), { Scale = 1.04 })
end)
islandHit.MouseLeave:Connect(function()
	tween(islandScale, motion(0.18), { Scale = 1 })
end)

local islandBody = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Visible = false,
	ZIndex = 62,
	Parent = island,
})
padding(islandBody, 8, 8, 14, 14)
local islandRow = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 62,
	Parent = islandBody,
})
local irl = list(islandRow, Enum.FillDirection.Horizontal, 10)
irl.VerticalAlignment = Enum.VerticalAlignment.Center
local islandDot = new("Frame", { Size = UDim2.fromOffset(8, 8), BackgroundColor3 = C.green, ZIndex = 63, Parent = islandRow })
corner(islandDot, 8)
local dotPulse = TweenService:Create(
	islandDot,
	TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ BackgroundTransparency = 0.55 }
)
dotPulse:Play()
local islandText = new("Frame", {
	Size = UDim2.new(1, -18, 1, 0),
	BackgroundTransparency = 1,
	ZIndex = 63,
	Parent = islandRow,
})
list(islandText, Enum.FillDirection.Vertical, 1)
local islandTitle = label(islandText, "", 13, C.text, FONT_BOLD)
islandTitle.Size = UDim2.new(1, 0, 0, 15)
islandTitle.ZIndex = 63
local islandDesc = label(islandText, "", 11, C.textDim, FONT_REG)
islandDesc.Size = UDim2.new(1, 0, 0, 14)
islandDesc.ZIndex = 63

local islandProgressBg = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -6),
	Size = UDim2.new(1, -28, 0, 3),
	BackgroundColor3 = Color3.fromRGB(58, 58, 62),
	Visible = false,
	ZIndex = 64,
	Parent = islandBody,
})
corner(islandProgressBg, 2)
local islandProgressFill = new("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = C.white,
	ZIndex = 65,
	Parent = islandProgressBg,
})
corner(islandProgressFill, 2)

local islandToken = 0
local islandBusy = false
local islandFlash = false
local notifQueue = {}
local currentNotif
local fpsValue = 60
local frameCount = 0

RunService.Heartbeat:Connect(function()
	frameCount += 1
end)

local function islandPing()
	local ok, value = pcall(function()
		return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	if ok and type(value) == "number" then
		return math.floor(value + 0.5)
	end
	return nil
end

local function islandIdleWidth()
	local left = islandRest.Text or ""
	local right = islandTime.Text or ""
	return math.clamp(#left * 7 + #right * 6 + 92, 128, 340)
end

local function refreshIslandIdle()
	if islandFlash then
		return
	end
	local opts = theme.island
	local left = "Maclib"
	if opts.username then
		left = "@" .. LocalPlayer.Name
	elseif opts.label and opts.label ~= "" then
		left = opts.label
	end
	islandRest.Text = left
	local parts = {}
	if opts.clock then
		table.insert(parts, os.date("%H:%M"))
	end
	if opts.ping then
		local ping = islandPing()
		if ping then
			table.insert(parts, ping .. " ms")
		end
	end
	if opts.fps then
		table.insert(parts, fpsValue .. " fps")
	end
	islandTime.Text = table.concat(parts, "   ")
	if not islandBusy then
		islandResize(islandIdleWidth(), 34, 0.3)
	end
end

local function pulseIsland()
	if theme.reduceMotion then
		return
	end
	tween(islandScale, spring(0.4), { Scale = 1.12 })
	task.delay(0.24, function()
		tween(islandScale, motion(0.28), { Scale = 1 })
	end)
end

local function flashIsland(text)
	islandFlash = true
	islandTime.Text = text
	task.delay(1.5, function()
		islandFlash = false
		refreshIslandIdle()
	end)
end

task.spawn(function()
	while screen.Parent do
		task.wait(1)
		if frameCount > 0 then
			fpsValue = frameCount
			frameCount = 0
		end
		if not islandBusy then
			refreshIslandIdle()
		end
	end
end)

local function showNotif(opts)
	islandBusy = true
	idlePulseStop()
	islandToken += 1
	local token = islandToken
	local life = opts.Lifetime or 4
	local color = opts.Color or theme.accent
	if opts.Style == "Confirm" then
		color = C.green
	elseif opts.Style == "Cancel" then
		color = C.red
	end
	dotPulse:Cancel()
	strokeBreath:Cancel()
	islandDot.BackgroundTransparency = 0
	islandDot.BackgroundColor3 = color
	islandTitle.Text = opts.Title or "Maclib"
	islandDesc.Text = opts.Description or ""
	local hasProgress = type(opts.Progress) == "number"
	islandProgressBg.Visible = hasProgress
	if hasProgress then
		islandProgressFill.Size = UDim2.fromScale(math.clamp(opts.Progress, 0, 1), 1)
		islandProgressFill.BackgroundColor3 = color
	end
	islandRow.Size = UDim2.new(1, 0, 1, hasProgress and -10 or 0)
	islandRest.Visible = false
	islandTime.Visible = false
	islandBody.Visible = true
	tween(islandCorner, motion(0.4), { CornerRadius = UDim.new(0, 22) })
	islandStroke.Transparency = theme.mode == "White" and 0.7 or 0.72
	local wide = math.clamp(math.max(#islandTitle.Text, #islandDesc.Text) * 7 + 70, 240, 420)
	local tall = (opts.Description and opts.Description ~= "" and 56 or 38) + (hasProgress and 12 or 0)
	islandResize(wide, tall, 0.45)
	islandScale.Scale = 0.9
	tween(islandScale, spring(0.5), { Scale = 1 })
	if not theme.reduceMotion then
		pulseRipple(color)
	end

	local dismissed = false
	local function finish()
		if dismissed then
			return
		end
		dismissed = true
		if currentNotif and currentNotif.token == token then
			currentNotif = nil
		end
		islandBusy = false
		tween(islandCorner, motion(0.35), { CornerRadius = UDim.new(0, 17) })
		islandStroke.Transparency = theme.mode == "White" and 0.82 or 0.86
		islandResize(126, 34, 0.35)
		task.delay(0.3, function()
			if not islandBusy then
				islandBody.Visible = false
				islandProgressBg.Visible = false
				islandRest.Visible = true
				islandTime.Visible = true
				islandDot.BackgroundTransparency = 0
				dotPulse:Play()
				refreshIslandIdle()
				strokeBreath:Play()
				idlePulseStart()
			end
		end)
		task.delay(0.45, function()
			if not islandBusy then
				local nextOpts = table.remove(notifQueue, 1)
				if nextOpts then
					showNotif(nextOpts)
				end
			end
		end)
	end
	currentNotif = { token = token, callback = opts.Callback, dismiss = finish }
	if life > 0 then
		task.delay(life, finish)
	end
	return {
		UpdateTitle = function(_, t)
			islandTitle.Text = t
		end,
		UpdateDescription = function(_, t)
			islandDesc.Text = t
		end,
		UpdateProgress = function(_, p)
			islandProgressBg.Visible = true
			islandProgressFill.Size = UDim2.fromScale(math.clamp(tonumber(p) or 0, 0, 1), 1)
		end,
		Resize = function() end,
		Cancel = finish,
	}
end

local function pushNotif(opts)
	opts = opts or {}
	if not theme.notifications and not opts.Force then
		return {
			UpdateTitle = function() end,
			UpdateDescription = function() end,
			UpdateProgress = function() end,
			Resize = function() end,
			Cancel = function() end,
		}
	end
	if islandBusy then
		table.insert(notifQueue, opts)
		return {
			UpdateTitle = function() end,
			UpdateDescription = function() end,
			UpdateProgress = function() end,
			Resize = function() end,
			Cancel = function()
				local idx = table.find(notifQueue, opts)
				if idx then
					table.remove(notifQueue, idx)
				end
			end,
		}
	end
	return showNotif(opts)
end

islandHit.MouseButton1Click:Connect(function()
	if currentNotif then
		local callback = currentNotif.callback
		currentNotif.dismiss()
		if callback then
			task.spawn(callback)
		end
		return
	end
	local w = MacLib.Windows[#MacLib.Windows]
	if w and not w.Unloaded then
		w:SetState(not w:GetState())
	end
end)

-- one dismiss layer for every floating menu, so nothing stays open behind your back
local openPopovers = {}
local popoverCloser = new("TextButton", {
	Name = "PopoverCloser",
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	Visible = false,
	ZIndex = 29,
	Parent = screen,
})
local function closePopovers()
	for _, p in ipairs(openPopovers) do
		p.Visible = false
	end
	openPopovers = {}
	popoverCloser.Visible = false
end
popoverCloser.MouseButton1Click:Connect(closePopovers)
local function openPopover(frame)
	closePopovers()
	frame.Visible = true
	table.insert(openPopovers, frame)
	-- Raise the dismiss layer above every open popover. Previously it sat at ZIndex 29,
	-- *under* menus (ZIndex 30), so clicks on rows were swallowed and dropdowns looked empty/dead.
	local topZ = 29
	for _, q in ipairs(openPopovers) do
		if q.ZIndex > topZ then topZ = q.ZIndex end
	end
	popoverCloser.ZIndex = topZ + 1
	popoverCloser.Visible = true
end

local function makeShell(parent, height)
	local shell = new("Frame", {
		Name = "Element",
		Size = UDim2.new(1, 0, 0, height or 36),
		BackgroundColor3 = C.card,
		BackgroundTransparency = 1,
		Parent = parent,
	})
	return shell
end

-- ---------------------------------------------------------------------------------------
-- Window

function MacLib:SetFolder(folder)
	self.Folder = tostring(folder or "Maclib")
	if not fd(self.Folder) then
		mf(self.Folder)
	end
	if not fd(self.Folder .. "/configs") then
		mf(self.Folder .. "/configs")
	end
end

function MacLib:_configPath(name)
	self:SetFolder(self.Folder)
	name = tostring(name or "config")
	if not name:find("%.") then
		name = name .. ".json"
	end
	return self.Folder .. "/configs/" .. name, name
end

function MacLib:UnloadAll()
	for _, w in ipairs(self.Windows) do
		pcall(function()
			w:Unload()
		end)
	end
	if self._screen then
		pcall(function()
			self._screen:Destroy()
		end)
		self._screen = nil
	end
end

-- one pass over the built tree that makes it render cleanly: rounded stroke joins so
-- rounded corners are not jagged, no leftover BorderSizePixel under UICorner (a second
-- border that fights the stroke), default resampling for images, and strokes on nearly
-- transparent containers suppressed so their anti-aliased fringe does not read as a
-- light halo around the edges.
function MacLib:Polish(scope)
	local counts = { strokes = 0, borders = 0, images = 0 }
	for _, d in ipairs((scope or screen):GetDescendants()) do
		if d:IsA("UIStroke") then
			counts.strokes += 1
			pcall(function()
				d.LineJoinMode = Enum.LineJoinMode.Round
				d.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			end)
			d.Thickness = math.max(1, math.floor(d.Thickness + 0.5))
			d.Transparency = math.clamp(d.Transparency, 0, 0.95)
			local parent = d.Parent
			local inIcon = false
			local probe = parent
			for _ = 1, 4 do
				if not probe or not probe.Name then
					break
				end
				if probe.Name:sub(1, 5) == "Icon_" then
					inIcon = true
					break
				end
				probe = probe.Parent
			end
			if parent and parent:IsA("GuiObject") and not inIcon and parent.Name ~= "Border" and parent.BackgroundTransparency > 0.6 then
				d.Transparency = math.max(d.Transparency, parent.BackgroundTransparency - 0.1)
			end
		elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
			counts.images += 1
			pcall(function()
				d.ResampleMode = Enum.ResamplerMode.Default
			end)
		elseif d:IsA("GuiObject") and d.BorderSizePixel ~= 0 and d:FindFirstChildOfClass("UICorner") then
			d.BorderSizePixel = 0
			counts.borders += 1
		end
	end
	for _, w in ipairs(MacLib.Windows) do
		if not w.Unloaded and w._glass then
			snapToPixel(w._glass)
		end
	end
	islandSettle()
	if theme.mode ~= nil then
		islandThemed()
	end
	return counts
end

function MacLib:SetAccent(color)
	theme.accent = color or C.accent
	applyTheme()
end

function MacLib:GetAccent()
	return theme.accent
end

function MacLib:SetAnimation(mode)
	theme.animation = (mode == "Smooth" or mode == "Off") and mode or "Spring"
end

function MacLib:GetAnimation()
	return theme.animation
end

function MacLib:SetFont(name)
	local set = fontSets[name] or fontSets.Gotham
	theme.font = fontSets[name] and name or "Gotham"
	FONT = set.medium
	FONT_BOLD = set.bold
	FONT_REG = set.regular
	local weightOf = {}
	for _, family in pairs(fontSets) do
		weightOf[family.regular] = "regular"
		weightOf[family.medium] = "medium"
		weightOf[family.bold] = "bold"
	end
	-- pass one: everything this library created, by its recorded weight
	for inst, weight in pairs(fontRegistry) do
		if inst.Parent then
			inst.Font = set[weight]
		else
			fontRegistry[inst] = nil
		end
	end
	-- pass two: belt and braces, remap any other text object on screen whose
	-- current font belongs to a family we know, so nothing can be left behind
	for _, obj in ipairs(screen:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextBox") or obj:IsA("TextButton") then
			local weight = weightOf[obj.Font]
			if weight then
				obj.Font = set[weight]
				fontRegistry[obj] = weight
			end
		end
	end
	return theme.font
end

function MacLib:GetFont()
	return theme.font
end

function MacLib:SetGlass(alpha)
	theme.glass = math.clamp(tonumber(alpha) or 0.08, 0, 0.75)
	for _, w in ipairs(MacLib.Windows) do
		if w._glass and not w.Unloaded then
			tween(w._glass, motion(0.25), { BackgroundTransparency = theme.glass })
		end
	end
end

function MacLib:Island(opts)
	return pushNotif(opts)
end

function MacLib:SetMode(mode)
	if mode ~= "Black" and mode ~= "White" then
		mode = "Glass"
	end
	theme.mode = mode
	applyModeColors(mode)
	for _, w in ipairs(MacLib.Windows) do
		if not w.Unloaded and w._glass then
			local root = w._glass
			local border = w._borderStroke
			if mode == "Glass" then
				root.BackgroundColor3 = Color3.fromRGB(16, 16, 18)
				tween(root, motion(0.3), { BackgroundTransparency = theme.glass })
				if w._sheen then
					w._sheen.Visible = true
				end
				if border then
					border.Color = C.white
					tween(border, motion(0.3), { Transparency = 0.55 })
				end
			elseif mode == "Black" then
				root.BackgroundColor3 = Color3.fromRGB(8, 8, 10)
				tween(root, motion(0.3), { BackgroundTransparency = 0 })
				if w._sheen then
					w._sheen.Visible = false
				end
				if border then
					border.Color = C.white
					tween(border, motion(0.3), { Transparency = 0.45 })
				end
			else
				root.BackgroundColor3 = Color3.fromRGB(242, 242, 247)
				tween(root, motion(0.3), { BackgroundTransparency = 0 })
				if w._sheen then
					w._sheen.Visible = false
				end
				if border then
					border.Color = Color3.fromRGB(40, 40, 44)
					tween(border, motion(0.3), { Transparency = 0.8 })
				end
			end
		end
	end
	islandThemed()
	applyTheme()
end

function MacLib:GetMode()
	return theme.mode
end

function MacLib:SetIsland(opts)
	opts = opts or {}
	for k, v in pairs(opts) do
		if k == "Clock" then
			theme.island.clock = v and true or false
		elseif k == "Ping" then
			theme.island.ping = v and true or false
		elseif k == "FPS" then
			theme.island.fps = v and true or false
		elseif k == "Username" then
			theme.island.username = v and true or false
		elseif k == "Label" then
			theme.island.label = tostring(v or "")
		end
	end
	pulseIsland()
	if not islandBusy then
		refreshIslandIdle()
		flashIsland("updated")
	end
end

function MacLib:Window(opts)
	opts = opts or {}
	local self = {
		Settings = {
			Title = opts.Title or "Maclib",
			Subtitle = opts.Subtitle or "",
			Size = opts.Size or UDim2.fromOffset(760, 520),
			DragStyle = opts.DragStyle or 1,
			DisabledWindowControls = opts.DisabledWindowControls or {},
			ShowUserInfo = opts.ShowUserInfo ~= false,
			Keybind = opts.Keybind or Enum.KeyCode.RightControl,
			AcrylicBlur = opts.AcrylicBlur ~= false,
			Callback = opts.Callback,
		},
		Tabs = {},
		TabGroups = {},
		GlobalSettings = {},
		Elements = {},
		Flags = {},
		Unloaded = false,
		Visible = true,
		_unloadCallbacks = {},
		_conns = {},
		_searchQuery = "",
		SetState = function(_self, _v) end,
		_applySearch = function(_self) end,
		_renderPalette = function(_self, _q) end,
	}
	local window = self
	local S = window.Settings

	local disabled = {}
	for _, name in ipairs(S.DisabledWindowControls) do
		disabled[name] = true
	end

	local function viewportSize()
		local cam = workspace.CurrentCamera
		return (cam and cam.ViewportSize) or Vector2.new(1920, 1080)
	end

	local function evenFloor(n)
		local v = math.floor(n + 0.5)
		if v % 2 ~= 0 then
			v -= 1
		end
		return v
	end

	local function sizeInPixels(size)
		local vp = viewportSize()
		return evenFloor(size.X.Scale * vp.X + size.X.Offset), evenFloor(size.Y.Scale * vp.Y + size.Y.Offset)
	end

	local holder = new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0, 0),
		BackgroundTransparency = 1,
		Parent = screen,
	})

	local function placeCentered(w, h)
		local vp = viewportSize()
		holder.Size = UDim2.fromOffset(w, h)
		holder.Position = UDim2.fromOffset(math.floor((vp.X - w) / 2 + 0.5), math.floor((vp.Y - h) / 2 + 0.5))
	end

	local function morphStart()
		local vp = viewportSize()
		local w = holder.AbsoluteSize.X
		if w < 1 then
			w = sizeInPixels(S.Size)
		end
		return UDim2.fromOffset(math.floor((vp.X - w) / 2 + 0.5), 31)
	end

	local startW, startH = sizeInPixels(S.Size)
	placeCentered(startW, startH)

	local scale = new("UIScale", { Scale = 0.12, Parent = holder })
	local lastPos = holder.Position
	local movedByUser = false

	table.insert(self._conns, Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if not movedByUser and not self.Unloaded then
			local vp = viewportSize()
			local size = holder.AbsoluteSize
			if size.X < 100 or size.Y < 100 then
				return
			end
			local w = evenFloor(size.X)
			local h = evenFloor(size.Y)
			holder.Size = UDim2.fromOffset(w, h)
			holder.Position = UDim2.fromOffset(math.floor((vp.X - w) / 2 + 0.5), math.floor((vp.Y - h) / 2 + 0.5))
			lastPos = holder.Position
		end
	end))

	-- one soft frame shadow. image shadows sliced wrong leave square patches at the corners
	local shadow = new("Frame", {
		Name = "Shadow",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 10),
		Size = UDim2.new(1, 40, 1, 40),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.66,
		ZIndex = 1,
		Parent = holder,
	})
	corner(shadow, 36)

	local root = new("Frame", {
		Name = "Glass",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(16, 16, 18),
		BackgroundTransparency = theme.glass,
		ClipsDescendants = true,
		ZIndex = 3,
		Parent = holder,
	})
	corner(root, 22)
	self._glass = root

	-- sandwich: the glass layer carries only the translucent fill; the border lives on
	-- a separate transparent layer drawn above it, so the stroke renders at native
	-- resolution and never alpha-blends with the fill underneath it.
	local borderLayer = new("Frame", {
		Name = "Border",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 45,
		Parent = holder,
	})
	corner(borderLayer, 22)
	local rootStroke = stroke(borderLayer, C.white, 1, 0.55)
	self._borderStroke = rootStroke

	-- liquid glass: a soft highlight pooled along the top edge, like light on curved glass
	local sheen = new("Frame", {
		Size = UDim2.new(1, 0, 0, 150),
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 0.9,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = root,
	})
	corner(sheen, 22)
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = sheen,
	})
	self._sheen = sheen
	if theme.mode ~= "Glass" then
		sheen.Visible = false
	end

	-- the window is born out of the island and returns to it
	holder.Position = morphStart()
	task.defer(function()
		local move = tween(holder, motion(0.55), { Position = lastPos })
		move.Completed:Connect(function()
			snapToPixel(holder)
			lastPos = holder.Position
		end)
		tween(scale, spring(0.6), { Scale = theme.scale })
	end)

	-- title bar
	local titlebar = new("Frame", {
		Name = "Titlebar",
		Size = UDim2.new(0, 210, 0, 52),
		BackgroundTransparency = 1,
		ZIndex = 6,
		Parent = root,
	})

	local function traffic(order, color, glyph, enabled)
		local b = new("TextButton", {
			Size = UDim2.fromOffset(12, 12),
			BackgroundColor3 = enabled and color or C.toggleOff,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = order,
			ZIndex = 7,
			Parent = titlebar,
		})
		corner(b, 12)
		local pop = new("UIScale", { Scale = 1, Parent = b })
		local g = label(b, glyph, 9, Color3.fromRGB(60, 40, 40), FONT_BOLD, Enum.TextXAlignment.Center)
		g.Size = UDim2.fromScale(1, 1)
		g.TextTransparency = 1
		g.ZIndex = 8
		b.MouseEnter:Connect(function()
			if enabled then
				tween(g, motion(0.12), { TextTransparency = 0.15 })
				tween(pop, motion(0.15), { Scale = 1.15 })
			end
		end)
		b.MouseLeave:Connect(function()
			tween(g, motion(0.12), { TextTransparency = 1 })
			tween(pop, motion(0.15), { Scale = 1 })
		end)
		return b
	end

	local lights = new("Frame", {
		Size = UDim2.fromOffset(54, 12),
		Position = UDim2.fromOffset(16, 12),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = titlebar,
	})
	local ll = list(lights, Enum.FillDirection.Horizontal, 6)
	ll.VerticalAlignment = Enum.VerticalAlignment.Center

	local closeBtn = traffic(1, C.red, "x", not disabled.Exit)
	closeBtn.Parent = lights
	local minBtn = traffic(2, C.yellow, "-", not disabled.Minimize)
	minBtn.Parent = lights
	local zoomBtn = traffic(3, C.green, "+", true)
	zoomBtn.Parent = lights

	local function iconBtn(xRight)
		local b = new("TextButton", {
			Size = UDim2.fromOffset(26, 26),
			Position = UDim2.new(1, xRight, 0, 13),
			BackgroundColor3 = C.card,
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 7,
			Parent = root,
		})
		corner(b, 8)
		b.MouseEnter:Connect(function()
			tween(b, motion(0.12), { BackgroundTransparency = 0.45 })
		end)
		b.MouseLeave:Connect(function()
			tween(b, motion(0.12), { BackgroundTransparency = 1 })
		end)
		return b
	end

	local searchBtn = iconBtn(-100)
	local searchIcon = MacLib:Icon("lens", searchBtn, 15, C.textFaint)
	searchIcon.Position = UDim2.fromOffset(5, 5)
	searchIcon.ZIndex = 8

	local cmdBtn = iconBtn(-70)
	local terminalIcon = MacLib:Icon("terminal", cmdBtn, 15, C.textFaint)
	terminalIcon.Position = UDim2.fromOffset(5, 5)
	terminalIcon.ZIndex = 8

	local globeBtn = iconBtn(-40)
	local globeIcon = MacLib:Icon("sliders", globeBtn, 15, C.textFaint)
	globeIcon.Position = UDim2.fromOffset(5, 5)
	globeIcon.ZIndex = 8

	-- body
	local body = new("Frame", {
		Name = "Body",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = root,
	})

	local sidebar = new("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, 210, 1, 0),
		BackgroundTransparency = 1,
		Parent = body,
	})
	new("Frame", {
		Size = UDim2.new(0, 1, 1, 0),
		Position = UDim2.new(1, -1, 0, 0),
		BackgroundColor3 = C.white,
		BackgroundTransparency = 0.92,
		BorderSizePixel = 0,
		Parent = sidebar,
	})

	local titleLabel = label(sidebar, S.Title, 18, C.text, FONT_BOLD)
	titleLabel.Position = UDim2.fromOffset(16, 36)
	titleLabel.Size = UDim2.new(1, -28, 0, 24)
	local subLabel = label(sidebar, S.Subtitle, 11, C.textFaint, FONT_REG)
	subLabel.Position = UDim2.fromOffset(16, 60)
	subLabel.Size = UDim2.new(1, -28, 0, 16)

	local tabScroll = new("ScrollingFrame", {
		Name = "Tabs",
		Position = UDim2.fromOffset(10, 92),
		Size = UDim2.new(1, -20, 1, -162),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = sidebar,
	})
	list(tabScroll, Enum.FillDirection.Vertical, 2)

	local userCard = new("Frame", {
		Name = "User",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 10, 1, -10),
		Size = UDim2.new(1, -20, 0, 52),
		BackgroundColor3 = C.card,
		BackgroundTransparency = 0.35,
		Parent = sidebar,
	})
	corner(userCard, 12)

	local avatar = new("ImageLabel", {
		Size = UDim2.fromOffset(32, 32),
		Position = UDim2.fromOffset(10, 10),
		BackgroundColor3 = C.elevated,
		Image = "",
		Parent = userCard,
	})
	corner(avatar, 16)
	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok and content and avatar.Parent then
			avatar.Image = content
		end
	end)

	local userName = label(userCard, LocalPlayer.DisplayName, 12, C.text, FONT_BOLD)
	userName.Position = UDim2.fromOffset(50, 8)
	userName.Size = UDim2.new(1, -58, 0, 16)
	local userHandle = label(userCard, "@" .. LocalPlayer.Name, 11, C.textFaint, FONT_REG)
	userHandle.Position = UDim2.fromOffset(50, 26)
	userHandle.Size = UDim2.new(1, -58, 0, 14)

	local content = new("Frame", {
		Name = "Content",
		Position = UDim2.fromOffset(210, 0),
		Size = UDim2.new(1, -210, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = body,
	})

	local pageTitle = label(content, "", 15, C.text, FONT)
	pageTitle.Position = UDim2.fromOffset(18, 14)
	pageTitle.Size = UDim2.new(1, -150, 0, 24)

	-- search overlay
	local searchBar = new("Frame", {
		Name = "SearchBar",
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 0),
		BackgroundColor3 = C.card,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 4,
		Parent = content,
	})
	corner(searchBar, 10)
	local searchBox = new("TextBox", {
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		BackgroundTransparency = 1,
		Font = FONT_REG,
		TextSize = 13,
		TextColor3 = C.text,
		PlaceholderText = "Search settings",
		PlaceholderColor3 = C.textFaint,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		ZIndex = 5,
		Parent = searchBar,
	})
	local searchOpen = false
	local function setSearch(open)
		searchOpen = open
		searchBar.Visible = true
		tween(searchBar, motion(0.22), { Size = UDim2.new(1, -28, 0, open and 32 or 0) })
		if not open then
			searchBox.Text = ""
			self._searchQuery = ""
			self:_applySearch()
			task.delay(0.22, function()
				if not searchOpen then
					searchBar.Visible = false
				end
			end)
		else
			searchBox:CaptureFocus()
		end
	end
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		self._searchQuery = searchBox.Text:lower()
		self:_applySearch()
	end)

	local pages = new("Frame", {
		Name = "Pages",
		Position = UDim2.fromOffset(0, 46),
		Size = UDim2.new(1, 0, 1, -46),
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = content,
	})

	-- global settings popover
	local pop = new("Frame", {
		Name = "GlobalSettings",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 8),
		Size = UDim2.fromOffset(250, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.bgDeep,
		Visible = false,
		ZIndex = 20,
		Parent = content,
	})
	corner(pop, 14)
	stroke(pop, C.white, 1, 0.86)
	padding(pop, 8, 8, 8, 8)
	list(pop, Enum.FillDirection.Vertical, 2)
	local popHeader = label(pop, "Settings", 11, C.textFaint, FONT_BOLD)
	popHeader.Size = UDim2.new(1, 0, 0, 20)
	popHeader.ZIndex = 21
	local popOpen = false

	-- command palette
	local paletteScrim = new("TextButton", {
		Name = "PaletteScrim",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.black,
		BackgroundTransparency = 1,
		Text = "",
		Visible = false,
		AutoButtonColor = false,
		ZIndex = 40,
		Parent = root,
	})
	corner(paletteScrim, 22)
	local palette = new("Frame", {
		Name = "Palette",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.fromOffset(440, 108),
		BackgroundColor3 = C.bgDeep,
		Visible = false,
		ClipsDescendants = true,
		ZIndex = 41,
		Parent = root,
	})
	corner(palette, 14)
	stroke(palette, C.white, 1, 0.84)
	local palBox = new("TextBox", {
		Size = UDim2.new(1, -24, 0, 38),
		Position = UDim2.fromOffset(12, 6),
		BackgroundTransparency = 1,
		Font = FONT,
		TextSize = 15,
		TextColor3 = C.text,
		PlaceholderText = "Type a command or setting...",
		PlaceholderColor3 = C.textFaint,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		ZIndex = 42,
		Parent = palette,
	})
	new("Frame", {
		Size = UDim2.new(1, -20, 0, 1),
		Position = UDim2.fromOffset(10, 46),
		BackgroundColor3 = C.white,
		BackgroundTransparency = 0.92,
		BorderSizePixel = 0,
		ZIndex = 42,
		Parent = palette,
	})
	local palList = new("ScrollingFrame", {
		Position = UDim2.fromOffset(8, 51),
		Size = UDim2.new(1, -16, 0, 32),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 2,
		ScrollBarImageColor3 = C.separator,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 42,
		Parent = palette,
	})
	list(palList, Enum.FillDirection.Vertical, 2)
	local palFooter = label(palette, "Enter to run  -  Esc to close", 11, C.textFaint, FONT_REG, Enum.TextXAlignment.Center)
	palFooter.Size = UDim2.new(1, 0, 0, 20)
	palFooter.ZIndex = 42

	local paletteOpen = false
	local function closePalette()
		paletteOpen = false
		palette.Visible = false
		paletteScrim.Visible = false
		palBox.Text = ""
	end
	paletteScrim.MouseButton1Click:Connect(closePalette)

	local function openPalette()
		paletteOpen = true
		palette.Visible = true
		paletteScrim.Visible = true
		paletteScrim.BackgroundTransparency = 0.55
		self:_renderPalette("")
		palBox:CaptureFocus()
	end
	palBox:GetPropertyChangedSignal("Text"):Connect(function()
		self:_renderPalette(palBox.Text:lower())
	end)
	palBox.FocusLost:Connect(function(enterPressed)
		if not paletteOpen then
			return
		end
		if enterPressed and self._paletteFirst then
			self._paletteFirst()
		else
			closePalette()
		end
	end)

	-- dialog layer
	local dialogLayer = new("Frame", {
		Name = "Dialogs",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 30,
		Parent = root,
	})

	-- dragging
	local dragging, dragStart, startPos
	local dragTarget = S.DragStyle == 2 and root or titlebar
	dragTarget.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			movedByUser = true
			dragStart = input.Position
			startPos = holder.Position
		end
	end)
	dragTarget.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			snapToPixel(holder)
			lastPos = holder.Position
		end
	end)
	table.insert(self._conns, UIS.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - dragStart
			holder.Position = UDim2.fromOffset(
				math.floor(startPos.X.Offset + d.X + 0.5),
				math.floor(startPos.Y.Offset + d.Y + 0.5)
			)
			snapToPixel(holder)
		end
	end))

	-- resizing from the corner
	local grip = new("TextButton", {
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.new(1, -16, 1, -16),
		BackgroundTransparency = 1,
		Text = "",
		ZIndex = 8,
		Parent = root,
	})
	local resizing, resizeStart, startSize
	grip.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			resizing = true
			resizeStart = input.Position
			startSize = holder.Size
		end
	end)
	grip.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			resizing = false
		end
	end)
	table.insert(self._conns, UIS.InputChanged:Connect(function(input)
		if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then
			local d = input.Position - resizeStart
			local w = math.clamp(math.floor(startSize.X.Offset + d.X + 0.5), 560, 1200)
			local h = math.clamp(math.floor(startSize.Y.Offset + d.Y + 0.5), 380, 860)
			holder.Size = UDim2.fromOffset(w - (w % 2), h - (h % 2))
			snapToPixel(holder)
			lastPos = holder.Position
		end
	end))

	local zoomed = false
	local preZoomPos, preZoomSize
	zoomBtn.MouseButton1Click:Connect(function()
		zoomed = not zoomed
		if zoomed then
			preZoomPos, preZoomSize = holder.Position, holder.Size
			local vp = viewportSize()
			local w, h = evenFloor(vp.X - 48), evenFloor(vp.Y - 48)
			local t = tween(holder, motion(0.3), {
				Position = UDim2.fromOffset(math.floor((vp.X - w) / 2 + 0.5), math.floor((vp.Y - h) / 2 + 0.5)),
				Size = UDim2.fromOffset(w, h),
			})
			t.Completed:Connect(function()
				snapToPixel(holder)
			end)
		else
			local t = tween(holder, motion(0.3), { Position = preZoomPos, Size = preZoomSize })
			t.Completed:Connect(function()
				snapToPixel(holder)
			end)
		end
	end)

	local minimized = false
	minBtn.MouseButton1Click:Connect(function()
		if disabled.Minimize then
			return
		end
		minimized = not minimized
		self:SetState(not minimized)
	end)

	-- visibility + keybind
	local toggleConn
	local function bindToggle(key)
		if toggleConn then
			toggleConn:Disconnect()
		end
		S.Keybind = key
		toggleConn = UIS.InputBegan:Connect(function(input, gp)
			if gp then
				return
			end
			if input.KeyCode == S.Keybind then
				self:SetState(not self.Visible)
			elseif input.KeyCode == Enum.KeyCode.F and (UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.RightControl)) then
				setSearch(not searchOpen)
			end
		end)
	end
	bindToggle(S.Keybind)

	searchBtn.MouseButton1Click:Connect(function()
		setSearch(not searchOpen)
	end)
	cmdBtn.MouseButton1Click:Connect(function()
		if paletteOpen then
			closePalette()
		else
			openPalette()
		end
	end)
	globeBtn.MouseButton1Click:Connect(function()
		popOpen = not popOpen
		pop.Visible = popOpen
	end)

	if S.AcrylicBlur then
		setBlur(true)
	end

	-- -----------------------------------------------------------------------------------
	function self:SetState(v)
		v = v and true or false
		if self.Visible == v then
			return
		end
		self.Visible = v
		if v then
			holder.Visible = true
			holder.Position = morphStart()
			scale.Scale = 0.12
			local move = tween(holder, motion(0.5), { Position = lastPos })
			move.Completed:Connect(function()
				snapToPixel(holder)
			end)
			tween(scale, spring(0.55), { Scale = theme.scale })
		else
			lastPos = holder.Position
			tween(holder, motion(0.32), { Position = morphStart() })
			tween(scale, motion(0.32), { Scale = 0.12 })
			task.delay(0.36, function()
				if not self.Visible then
					holder.Visible = false
				end
			end)
		end
	end
	function self:GetState()
		return self.Visible
	end

	function self:SetNotificationsState(v)
		theme.notifications = v and true or false
	end
	function self:GetNotificationsState()
		return theme.notifications
	end
	function self:SetAcrylicBlurState(v)
		setBlur(v)
	end
	function self:GetAcrylicBlurState()
		return theme.blur
	end
	function self:SetUserInfoState(v)
		S.ShowUserInfo = v and true or false
		userCard.Visible = S.ShowUserInfo
		if v then
			userName.Text = LocalPlayer.DisplayName
			userHandle.Text = "@" .. LocalPlayer.Name
		else
			userName.Text = "Hidden"
			userHandle.Text = "@redacted"
		end
	end
	function self:GetUserInfoState()
		return S.ShowUserInfo
	end
	function self:SetKeybind(key)
		bindToggle(key)
	end
	function self:SetSize(size)
		local w, h = sizeInPixels(size)
		placeCentered(w, h)
		S.Size = size
		snapToPixel(holder)
		lastPos = holder.Position
	end
	function self:GetSize()
		return holder.Size
	end
	function self:SetScale(n)
		theme.scale = n
		local t = tween(scale, motion(0.2), { Scale = n })
		t.Completed:Connect(function()
			snapToPixel(holder)
		end)
	end
	function self:GetScale()
		return theme.scale
	end
	function self:UpdateTitle(t)
		S.Title = t
		titleLabel.Text = t
	end
	function self:UpdateSubtitle(t)
		S.Subtitle = t
		subLabel.Text = t
	end

	function self:SetBackground(color)
		root.BackgroundColor3 = color or Color3.fromRGB(16, 16, 18)
	end

	function self:Highlight()
		tween(rootStroke, motion(0.16), { Transparency = 0, Thickness = 2 })
		task.delay(0.4, function()
			if root.Parent then
				tween(rootStroke, motion(0.5), { Transparency = 0.55, Thickness = 1 })
			end
		end)
	end

	function self:Shake()
		if theme.reduceMotion then
			return
		end
		local base = holder.Position
		task.spawn(function()
			local offsets = { 10, -10, 7, -7, 4, -4, 0 }
			for _, dx in ipairs(offsets) do
				tween(holder, TweenInfo.new(0.05, Enum.EasingStyle.Linear), {
					Position = UDim2.new(base.X.Scale, base.X.Offset + dx, base.Y.Scale, base.Y.Offset),
				})
				task.wait(0.05)
			end
			snapToPixel(holder)
			lastPos = holder.Position
		end)
	end

	function self:Notify(o)
		o = o or {}
		o.Title = o.Title or S.Title
		return pushNotif(o)
	end

	function self:Palette(force)
		if force == true or (force == nil and not paletteOpen) then
			openPalette()
		else
			closePalette()
		end
		return paletteOpen
	end

	function self:Search()
		setSearch(not searchOpen)
	end

	function self:Dialog(o)
		o = o or {}
		dialogLayer.Visible = true
		local scrim = new("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = C.black,
			BackgroundTransparency = 0.45,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 31,
			Parent = dialogLayer,
		})
		corner(scrim, 22)
		local box = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.55),
			Size = UDim2.fromOffset(360, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = C.bgDeep,
			ZIndex = 32,
			Parent = dialogLayer,
		})
		corner(box, 16)
		stroke(box, C.white, 1, 0.84)
		padding(box, 18, 14, 18, 18)
		local vl = list(box, Enum.FillDirection.Vertical, 8)
		vl.HorizontalAlignment = Enum.HorizontalAlignment.Center

		local dt = label(box, o.Title or S.Title, 16, C.text, FONT_BOLD, Enum.TextXAlignment.Center)
		dt.Size = UDim2.new(1, 0, 0, 22)
		dt.ZIndex = 33
		local dd = label(box, o.Description or "", 13, C.textDim, FONT_REG, Enum.TextXAlignment.Center)
		dd.Size = UDim2.new(1, 0, 0, 0)
		dd.AutomaticSize = Enum.AutomaticSize.Y
		dd.TextWrapped = true
		dd.ZIndex = 33

		local btnRow = new("Frame", {
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundTransparency = 1,
			ZIndex = 33,
			Parent = box,
		})
		local bl = list(btnRow, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
		bl.HorizontalAlignment = Enum.HorizontalAlignment.Center

		local alive = true
		local function close()
			if not alive then
				return
			end
			alive = false
			box:Destroy()
			scrim:Destroy()
			if #dialogLayer:GetChildren() == 0 then
				dialogLayer.Visible = false
			end
		end
		local buttons = o.Buttons or { { Name = "OK" } }
		for i, b in ipairs(buttons) do
			local primary = i == 1
			local bt = new("TextButton", {
				Size = UDim2.fromOffset(150, 30),
				BackgroundColor3 = primary and theme.accent or C.card,
				Text = b.Name or "Button",
				Font = FONT_BOLD,
				TextSize = 13,
				TextColor3 = C.text,
				AutoButtonColor = false,
				ZIndex = 34,
				Parent = btnRow,
			})
			corner(bt, 8)
			bt.MouseButton1Click:Connect(function()
				if b.Callback then
					task.spawn(b.Callback)
				end
				close()
			end)
		end
		local openTween = tween(box, motion(0.26), { Position = UDim2.fromScale(0.5, 0.5) })
		openTween.Completed:Connect(function()
			snapToPixel(box)
		end)
		return {
			UpdateTitle = function(_, t)
				dt.Text = t
			end,
			UpdateDescription = function(_, t)
				dd.Text = t
			end,
			Cancel = close,
		}
	end

	-- -----------------------------------------------------------------------------------
	-- search + palette

	function self:_applySearch()
		local q = self._searchQuery
		for _, el in ipairs(self.Elements) do
			if el._shell and el._shell.Parent then
				local name = (el._searchName or ""):lower()
				local show = q == "" or name:find(q, 1, true) ~= nil
				if el._userHidden then
					show = false
				end
				el._shell.Visible = show
			end
		end
	end

	function self:_renderPalette(q)
		for _, c in ipairs(palList:GetChildren()) do
			c:Destroy()
		end
		self._paletteFirst = nil
		local shown = 0
		local function makeRow(text, right, activate)
			shown += 1
			local row = new("TextButton", {
				Size = UDim2.new(1, 0, 0, 30),
				BackgroundColor3 = C.card,
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				ZIndex = 43,
				Parent = palList,
			})
			corner(row, 8)
			local t = label(row, text, 13, C.text, FONT)
			t.Size = UDim2.new(1, -84, 1, 0)
			t.Position = UDim2.fromOffset(10, 0)
			t.TextTruncate = Enum.TextTruncate.AtEnd
			t.ZIndex = 44
			local kind = label(row, right or "", 11, C.textFaint, FONT_REG, Enum.TextXAlignment.Right)
			kind.Size = UDim2.fromOffset(70, 30)
			kind.Position = UDim2.new(1, -78, 0, 0)
			kind.ZIndex = 44
			row.MouseEnter:Connect(function()
				tween(row, motion(0.1), { BackgroundTransparency = 0 })
			end)
			row.MouseLeave:Connect(function()
				tween(row, motion(0.1), { BackgroundTransparency = 1 })
			end)
			row.MouseButton1Click:Connect(activate)
			if not self._paletteFirst then
				self._paletteFirst = activate
			end
		end

		if q == "" or ("hide window"):find(q, 1, true) then
			makeRow("Hide window", "Command", function()
				closePalette()
				self:SetState(false)
			end)
		end
		if q == "" or ("unload window"):find(q, 1, true) then
			makeRow("Unload window", "Command", function()
				closePalette()
				self:Unload()
			end)
		end
		if q == "" or ("toggle notifications"):find(q, 1, true) then
			makeRow("Toggle notifications", "Command", function()
				closePalette()
				self:SetNotificationsState(not self:GetNotificationsState())
			end)
		end

		local pickable = {
			Button = true,
			Toggle = true,
			Slider = true,
			Input = true,
			Keybind = true,
			Dropdown = true,
			Colorpicker = true,
			Segmented = true,
			Swatches = true,
			Progress = true,
		}
		for _, el in ipairs(self.Elements) do
			if shown >= 12 then
				break
			end
			local name = el._searchName or ""
			if pickable[el._kind] and name ~= "" and (q == "" or name:lower():find(q, 1, true)) then
				local tabName = el._tab and el._tab.Name or ""
				local kindName = el._kind or ""
				local right = tabName ~= "" and (tabName .. " - " .. kindName) or kindName
				makeRow(name, right, function()
					closePalette()
					if el.Highlight then
						el:Highlight()
					end
					if el._kind == "Toggle" and el.UpdateState then
						el:UpdateState(not el:GetState())
					elseif el._kind == "Button" and el.Settings and el.Settings.Callback then
						task.spawn(el.Settings.Callback)
					end
				end)
			end
		end

		local emptyShown = false
		if shown == 0 then
			local empty = label(palList, "Nothing matches", 12, C.textFaint, FONT_REG, Enum.TextXAlignment.Center)
			empty.Size = UDim2.new(1, 0, 0, 28)
			empty.ZIndex = 44
			emptyShown = true
		end

		local listH = emptyShown and 28 or math.clamp(shown * 32, 32, 224)
		palList.Size = UDim2.new(1, -16, 0, listH)
		palFooter.Position = UDim2.fromOffset(0, 51 + listH + 2)
		local totalH = 51 + listH + 24
		tween(palette, motion(0.25), { Size = UDim2.fromOffset(440, totalH) })
		snapToPixel(palette)
	end

	-- -----------------------------------------------------------------------------------
	-- unload
	function self.onUnloaded(fn)
		table.insert(self._unloadCallbacks, fn)
	end
	function self:Unload()
		if self.Unloaded then
			return
		end
		self.Unloaded = true
		for _, fn in ipairs(self._unloadCallbacks) do
			task.spawn(fn)
		end
		if toggleConn then
			toggleConn:Disconnect()
		end
		for _, c in ipairs(self._conns) do
			pcall(function()
				c:Disconnect()
			end)
		end
		self._conns = {}
		for _, el in ipairs(self.Elements) do
			if el._conns then
				for _, c in ipairs(el._conns) do
					pcall(function()
						c:Disconnect()
					end)
				end
			end
		end
		tween(scale, motion(0.2), { Scale = 0.9 })
		tween(root, motion(0.2), { BackgroundTransparency = 1 })
		task.delay(0.22, function()
			holder:Destroy()
		end)
		local anyLeft = false
		for _, w in ipairs(MacLib.Windows) do
			if w ~= self and not w.Unloaded then
				anyLeft = true
			end
		end
		if not anyLeft then
			setBlur(false)
			task.delay(0.4, function()
				if blurEffect then
					blurEffect:Destroy()
				end
			end)
		end
	end
	closeBtn.MouseButton1Click:Connect(function()
		if disabled.Exit then
			return
		end
		self:Unload()
	end)

	-- -----------------------------------------------------------------------------------
	-- config
	local function collect()
		local data = {}
		for flag, el in pairs(self.Flags) do
			if not el.IgnoreConfig then
				if el._kind == "Toggle" then
					data[flag] = el:GetState()
				elseif el._kind == "Slider" then
					data[flag] = el:GetValue()
				elseif el._kind == "Input" then
					data[flag] = el:GetInput()
				elseif el._kind == "Keybind" then
					local b = el:GetBind()
					data[flag] = b and b.Name or nil
				elseif el._kind == "Colorpicker" then
					data[flag] = { color = colorToTable(el.Color), alpha = el.Alpha }
				elseif el._kind == "Dropdown" then
					data[flag] = el.Value
				elseif el._kind == "Segmented" then
					data[flag] = el.Value
				elseif el._kind == "Swatches" then
					data[flag] = el._index
				elseif el._kind == "Progress" then
					data[flag] = el:GetValue()
				end
			end
		end
		return data
	end

	local function apply(data)
		if type(data) ~= "table" then
			return
		end
		for flag, value in pairs(data) do
			local el = self.Flags[flag]
			if el and not el.IgnoreConfig then
				if el._kind == "Toggle" then
					el:UpdateState(value and true or false)
				elseif el._kind == "Slider" then
					el:UpdateValue(tonumber(value) or el:GetValue())
				elseif el._kind == "Input" then
					el:UpdateText(tostring(value or ""))
					if el.Settings.Callback then
						task.spawn(el.Settings.Callback, el:GetInput())
					end
				elseif el._kind == "Keybind" then
					local ok, key = pcall(function()
						return Enum.KeyCode[value]
					end)
					if not (ok and key) then
						ok, key = pcall(function()
							return Enum.UserInputType[value]
						end)
					end
					if ok and key then
						el:SetBind(key, true)
					end
				elseif el._kind == "Colorpicker" and type(value) == "table" then
					if value.color then
						el:SetColor(tableToColor(value.color))
					end
					if value.alpha ~= nil then
						el:SetAlpha(value.alpha)
					end
				elseif el._kind == "Dropdown" then
					el:UpdateSelection(value)
				elseif el._kind == "Segmented" then
					el:UpdateSelection(value)
				elseif el._kind == "Swatches" then
					el:UpdateSelection(tonumber(value) or 1)
				elseif el._kind == "Progress" then
					el:UpdateValue(tonumber(value) or 0)
				end
			end
		end
	end

	function self:_configPath(name)
		return MacLib:_configPath(name)
	end

	-- -----------------------------------------------------------------------------------
	-- Global settings

	function self:GlobalSetting(o)
		o = o or {}
		local state = o.Default and true or false
		local row = new("TextButton", {
			Size = UDim2.new(1, 0, 0, 32),
			BackgroundColor3 = C.card,
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 21,
			Parent = pop,
		})
		corner(row, 8)
		local name = label(row, o.Name or "Setting", 13, C.text, FONT)
		name.Size = UDim2.new(1, -52, 1, 0)
		name.Position = UDim2.fromOffset(8, 0)
		name.ZIndex = 22
		local knob = new("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(34, 20),
			BackgroundColor3 = state and theme.accent or C.toggleOff,
			ZIndex = 22,
			Parent = row,
		})
		corner(knob, 10)
		local dot = new("Frame", {
			Size = UDim2.fromOffset(16, 16),
			Position = UDim2.fromOffset(state and 16 or 2, 2),
			BackgroundColor3 = C.white,
			ZIndex = 23,
			Parent = knob,
		})
		corner(dot, 8)

		local gs = { State = state, Settings = o }
		function gs:UpdateState(v, silent)
			gs.State = v and true or false
			tween(knob, motion(0.18), { BackgroundColor3 = gs.State and theme.accent or C.toggleOff })
			tween(dot, motion(0.18), { Position = UDim2.fromOffset(gs.State and 16 or 2, 2) })
			if not silent and o.Callback then
				task.spawn(o.Callback, gs.State)
			end
		end
		function gs:GetState()
			return gs.State
		end
		row.MouseButton1Click:Connect(function()
			gs:UpdateState(not gs.State)
		end)
		table.insert(self.GlobalSettings, gs)
		if o.Callback and state then
			task.defer(o.Callback, state)
		end
		return gs
	end

	-- built in appearance controls
	self:GlobalSetting({
		Name = "Reduce Motion",
		Default = false,
		Callback = function(v)
			theme.reduceMotion = v
		end,
	})

	-- -----------------------------------------------------------------------------------
	-- tabs

	local selectedTab
	local tabOrder = 0

	function self:TabGroup()
		local group = { Tabs = {} }
		local divider = new("Frame", {
			Size = UDim2.new(1, -8, 0, 1),
			BackgroundColor3 = C.separator,
			BackgroundTransparency = 0.5,
			BorderSizePixel = 0,
			LayoutOrder = tabOrder,
			Parent = tabScroll,
		})
		tabOrder += 1
		if #self.TabGroups == 0 then
			divider.Visible = false
		end
		table.insert(self.TabGroups, group)

		function group:Tab(o)
			o = o or {}
			local tab = {
				Name = o.Name or "Tab",
				Image = o.Image,
				Sections = { Left = {}, Right = {} },
				_buttons = {},
			}

			local btn = new("TextButton", {
				Size = UDim2.new(1, 0, 0, 32),
				BackgroundColor3 = C.card,
				BackgroundTransparency = 1,
				Text = "",
				AutoButtonColor = false,
				LayoutOrder = tabOrder,
				Parent = tabScroll,
			})
			tabOrder += 1
			corner(btn, 8)
			local icon
			local iconScale
			if o.Image and o.Image ~= "" then
				icon = new("ImageLabel", {
					Size = UDim2.fromOffset(15, 15),
					Position = UDim2.fromOffset(9, 8),
					BackgroundTransparency = 1,
					Image = o.Image,
					ImageColor3 = C.textDim,
					ScaleType = Enum.ScaleType.Fit,
					Parent = btn,
				})
				iconScale = new("UIScale", { Scale = 1, Parent = icon })
			elseif o.Icon and icons[o.Icon] then
				icon = MacLib:Icon(o.Icon, btn, 15, C.textDim)
				icon.Position = UDim2.fromOffset(9, 8)
				iconScale = icon:FindFirstChildOfClass("UIScale")
			end
			local tl = label(btn, tab.Name, 13, C.textDim, FONT)
			tl.Position = UDim2.fromOffset(icon and 30 or 10, 0)
			tl.Size = UDim2.new(1, icon and -38 or -18, 1, 0)

			local indicator = new("Frame", {
				Size = UDim2.fromOffset(3, 14),
				Position = UDim2.fromOffset(0, 9),
				BackgroundColor3 = theme.accent,
				BackgroundTransparency = 1,
				Parent = btn,
			})
			corner(indicator, 2)
			onTheme(function()
				indicator.BackgroundColor3 = theme.accent
			end)
			btn.MouseEnter:Connect(function()
				if selectedTab ~= tab then
					tween(btn, motion(0.14), { BackgroundTransparency = 0.75 })
				end
			end)
			btn.MouseLeave:Connect(function()
				if selectedTab ~= tab then
					tween(btn, motion(0.14), { BackgroundTransparency = 1 })
				end
			end)

			local page = new("ScrollingFrame", {
				Name = tab.Name,
				Size = UDim2.fromScale(1, 1),
				Position = UDim2.fromOffset(14, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				ScrollBarThickness = 3,
				ScrollBarImageColor3 = C.separator,
				CanvasSize = UDim2.new(),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				Visible = false,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				ElasticBehavior = Enum.ElasticBehavior.Never,
				Parent = pages,
			})
			padding(page, 6, 16, 0, 0)
			local columns = new("Frame", {
				Size = UDim2.new(1, -28, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				Parent = page,
			})
			columns.Position = UDim2.fromOffset(14, 0)
			local cl = list(columns, Enum.FillDirection.Horizontal, 10)
			cl.VerticalAlignment = Enum.VerticalAlignment.Top

			local function column()
				local c = new("ScrollingFrame", {
					Size = UDim2.new(0.5, -5, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					CanvasSize = UDim2.new(),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ScrollBarThickness = 0,
					ScrollingEnabled = false,
					Parent = columns,
				})
				list(c, Enum.FillDirection.Vertical, 10)
				return c
			end
			local leftCol = column()
			local rightCol = column()
			tab._page = page
			tab._pad = page:FindFirstChildOfClass("UIPadding")
			tab._left = leftCol
			tab._right = rightCol

			function tab:Select()
				if selectedTab == tab then
					return
				end
				if selectedTab then
					selectedTab._page.Visible = false
					tween(selectedTab._btn, motion(0.16), { BackgroundTransparency = 1 })
					tween(selectedTab._label, motion(0.16), { TextColor3 = C.textDim })
					tween(selectedTab._indicator, motion(0.16), { BackgroundTransparency = 1 })
					if selectedTab._icon then
						tintIcon(selectedTab._icon, C.textDim)
					end
					if selectedTab._iconScale then
						tween(selectedTab._iconScale, motion(0.16), { Scale = 1 })
					end
				end
				selectedTab = tab
				page.Visible = true
				page.Position = UDim2.fromOffset(14, 0)
				tween(page, motion(0.28), { Position = UDim2.fromOffset(0, 0) })
				pageTitle.Text = tab.Name
				tween(btn, motion(0.16), { BackgroundTransparency = 0.35 })
				tween(tl, motion(0.16), { TextColor3 = C.text })
				tween(indicator, motion(0.16), { BackgroundTransparency = 0 })
				if icon then
					tintIcon(icon, C.text)
				end
				if iconScale then
					iconScale.Scale = 0.7
					tween(iconScale, spring(0.4), { Scale = 1 })
				end
				if columns then
					columns.Position = UDim2.fromOffset(14, 10)
					tween(columns, motion(0.32), { Position = UDim2.fromOffset(14, 0) })
				end
				task.defer(function()
					MacLib:Polish()
				end)
			end
			tab._btn = btn
			tab._label = tl
			tab._indicator = indicator
			tab._icon = icon
			tab._iconScale = iconScale
			btn.MouseButton1Click:Connect(function()
				tab:Select()
			end)

			function tab:Section(so)
				so = so or {}
				local side = so.Side == "Right" and "Right" or "Left"
				local holder = side == "Right" and rightCol or leftCol
				local card = new("Frame", {
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = C.card,
					BackgroundTransparency = 0.25,
					Parent = holder,
				})
				corner(card, 12)
				stroke(card, C.white, 1, 0.92)
				padding(card, 8, 8, 8, 8)
				list(card, Enum.FillDirection.Vertical, 2)

				local section = { _card = card, Side = side }
				table.insert(tab.Sections[side], section)

				local hoverKinds = {
					Button = true,
					Toggle = true,
					Slider = true,
					Input = true,
					Keybind = true,
					Dropdown = true,
					Colorpicker = true,
					Segmented = true,
					Progress = true,
					Swatches = true,
				}
				local function register(el, shell, searchName, kind)
					el._shell = shell
					el._searchName = searchName or ""
					el._kind = kind
					el._tab = tab
					el._conns = el._conns or {}
					el.IgnoreConfig = false
					table.insert(window.Elements, el)
					local authoredVisibility = el.SetVisiblity
					if authoredVisibility then
						function el:SetVisiblity(v)
							el._userHidden = not (v and true or false)
							authoredVisibility(el, v)
						end
					end
					function el:Highlight()
						local wasSelected = selectedTab == tab
						if not wasSelected then
							tab:Select()
						end
						tween(shell, motion(0.18), { BackgroundColor3 = theme.accent, BackgroundTransparency = 0.5 })
						task.delay(0.45, function()
							if shell.Parent then
								tween(shell, motion(0.35), { BackgroundColor3 = themed(C.card), BackgroundTransparency = 1 })
							end
						end)
					end
					if hoverKinds[kind] then
						shell.MouseEnter:Connect(function()
							tween(shell, motion(0.12), { BackgroundColor3 = themed(C.cardHover), BackgroundTransparency = 0.72 })
						end)
						shell.MouseLeave:Connect(function()
							tween(shell, motion(0.12), { BackgroundColor3 = themed(C.card), BackgroundTransparency = 1 })
						end)
					end
				end

				local function flag(el, f)
					if f and f ~= "" then
						el.Flag = f
						window.Flags[f] = el
						MacLib.Flags[f] = el
					end
				end

				function section:SetVisiblity() end

				function section:Header(o, f)
					o = o or {}
					local text = o.Name or o.Text or "Header"
					local shell = makeShell(card, 30)
					shell.BackgroundTransparency = 1
					local textX = 8
					if o.Icon and icons[o.Icon] then
						local ic = MacLib:Icon(o.Icon, shell, 12, C.textFaint)
						ic.Position = UDim2.fromOffset(8, 9)
						textX = 25
					end
					local l = label(shell, string.upper(text), 11, C.textFaint, FONT_BOLD)
					l.Size = UDim2.new(1, -textX - 8, 1, 0)
					l.Position = UDim2.fromOffset(textX, 6)
					local el = { Settings = o }
					function el:UpdateName(t)
						l.Text = string.upper(t)
					end
					function el:SetVisiblity(v)
						shell.Visible = v and true or false
					end
					register(el, shell, text, "Header")
					flag(el, f)
					return el
				end

				function section:Divider()
					local shell = makeShell(card, 13)
					shell.BackgroundTransparency = 1
					local line = new("Frame", {
						Size = UDim2.new(1, -4, 0, 1),
						Position = UDim2.new(0, 2, 0.5, 0),
						BackgroundColor3 = C.separator,
						BackgroundTransparency = 0.45,
						BorderSizePixel = 0,
						Parent = shell,
					})
					local el = {}
					function el:Remove()
						shell:Destroy()
					end
					function el:SetVisiblity(v)
						shell.Visible = v and true or false
					end
					register(el, shell, "", "Divider")
					return el
				end

				function section:Spacer()
					local shell = makeShell(card, 8)
					shell.BackgroundTransparency = 1
					local el = {}
					function el:Remove()
						shell:Destroy()
					end
					function el:SetVisiblity(v)
						shell.Visible = v and true or false
					end
					register(el, shell, "", "Spacer")
					return el
				end

				function section:Label(o, f)
					o = o or {}
					local shell = makeShell(card, 0)
					shell.AutomaticSize = Enum.AutomaticSize.Y
					shell.BackgroundTransparency = 1
					local l = label(shell, o.Text or "", 13, C.text, FONT_REG)
					l.Size = UDim2.new(1, -12, 0, 0)
					l.AutomaticSize = Enum.AutomaticSize.Y
					l.Position = UDim2.fromOffset(8, 4)
					l.TextWrapped = true
					local el = { Settings = o }
					function el:UpdateName(t)
						l.Text = t
					end
					function el:SetVisiblity(v)
						shell.Visible = v and true or false
					end
					register(el, shell, o.Text or "", "Label")
					flag(el, f)
					return el
				end

				function section:SubLabel(o, f)
					o = o or {}
					local shell = makeShell(card, 0)
					shell.AutomaticSize = Enum.AutomaticSize.Y
					shell.BackgroundTransparency = 1
					local l = label(shell, o.Text or "", 12, C.textFaint, FONT_REG)
					l.Size = UDim2.new(1, -12, 0, 0)
					l.AutomaticSize = Enum.AutomaticSize.Y
					l.Position = UDim2.fromOffset(8, 2)
					l.TextWrapped = true
					local el = { Settings = o }
					function el:UpdateName(t)
						l.Text = t
					end
					function el:SetVisiblity(v)
						shell.Visible = v and true or false
					end
					register(el, shell, o.Text or "", "SubLabel")
					flag(el, f)
					return el
				end

				function section:Paragraph(o, f)
					o = o or {}
					local shell = makeShell(card, 0)
					shell.AutomaticSize = Enum.AutomaticSize.Y
					shell.BackgroundTransparency = 1
					local h = label(shell, o.Header or "", 13, C.text, FONT_BOLD)
					h.Size = UDim2.new(1, -12, 0, 18)
					h.Position = UDim2.fromOffset(8, 4)
					local b = label(shell, o.Body or "", 12, C.textDim, FONT_REG)
					b.Size = UDim2.new(1, -12, 0, 0)
					b.AutomaticSize = Enum.AutomaticSize.Y
					b.Position = UDim2.fromOffset(8, 22)
					b.TextWrapped = true
					local spacer = new("Frame", { Size = UDim2.new(1, 0, 0, 6), BackgroundTransparency = 1, Parent = shell })
					spacer.LayoutOrder = 2
					local el = { Settings = o }
					function el:UpdateHeader(t)
						h.Text = t
					end
					function el:UpdateBody(t)
						b.Text = t
					end
					function el:SetVisiblity(v)
						shell.Visible = v and true or false
					end
					register(el, shell, (o.Header or "") .. " " .. (o.Body or ""), "Paragraph")
					flag(el, f)
					return el
				end

				function section:Button(o, f)
					o = o or {}
					local shell = makeShell(card, 34)
					local textX = 10
					if o.Icon and icons[o.Icon] then
						local ic = MacLib:Icon(o.Icon, shell, 14, C.textDim)
						ic.Position = UDim2.fromOffset(10, 10)
						textX = 31
					end
					local l = label(shell, o.Name or "Button", 13, C.text, FONT)
					l.Size = UDim2.new(1, -textX - 30, 1, 0)
					l.Position = UDim2.fromOffset(textX, 0)
					local chev = label(shell, ">", 16, C.textFaint, FONT_REG, Enum.TextXAlignment.Right)
					chev.Size = UDim2.fromOffset(20, 34)
					chev.Position = UDim2.new(1, -26, 0, 0)
					local hit = new("TextButton", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "",
						Parent = shell,
					})
					local press = new("UIScale", { Scale = 1, Parent = shell })
					local el = { Settings = o }
					function el:UpdateName(t)
						l.Text = t
						el._searchName = t
					end
					function el:SetVisiblity(v)
						shell.Visible = v and true or false
					end
					hit.MouseButton1Down:Connect(function()
						tween(press, motion(0.08), { Scale = 0.985 })
					end)
					hit.MouseButton1Up:Connect(function()
						tween(press, spring(0.3), { Scale = 1 })
					end)
					hit.MouseButton1Click:Connect(function()
						tween(shell, motion(0.08), { BackgroundColor3 = theme.accent })
						task.delay(0.12, function()
							if shell.Parent then
								tween(shell, motion(0.2), { BackgroundColor3 = C.card })
							end
						end)
						if o.Callback then
							task.spawn(o.Callback)
						end
					end)
					register(el, shell, o.Name or "Button", "Button")
					flag(el, f)
					return el
				end

				function section:Toggle(o, f)
					o = o or {}
					local state = o.Default and true or false
					local shell = makeShell(card, 34)
					local l = label(shell, o.Name or "Toggle", 13, C.text, FONT)
					l.Size = UDim2.new(1, -64, 1, 0)
					l.Position = UDim2.fromOffset(10, 0)
					local track = new("Frame", {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -10, 0.5, 0),
						Size = UDim2.fromOffset(32, 18),
						BackgroundColor3 = state and C.white or Color3.fromRGB(72, 72, 76),
						Parent = shell,
					})
					corner(track, 9)
					local thumb = new("Frame", {
						Size = UDim2.fromOffset(14, 14),
						Position = UDim2.fromOffset(state and 16 or 2, 2),
						BackgroundColor3 = state and Color3.fromRGB(40, 40, 42) or C.white,
						Parent = track,
					})
					corner(thumb, 10)
					local hit = new("TextButton", {
						Size = UDim2.fromScale(1, 1),
						BackgroundTransparency = 1,
						Text = "",
						Parent = shell,
					})
					local el = { State = state, Settings = o }
					local function thumbColor()
						local a = theme.accent
						local lum = 0.2126 * a.R + 0.7152 * a.G + 0.0722 * a.B
						return lum > 0.72 and Color3.fromRGB(40, 40, 42) or C.white
					end
					local function paintAccent()
						tween(track, motion(0.18), { BackgroundColor3 = el.State and theme.accent or themed(Color3.fromRGB(72, 72, 76)) })
						tween(thumb, motion(0.18), { BackgroundColor3 = el.State and thumbColor() or C.white })
					end
					onTheme(paintAccent)
					function el:UpdateState(v, silent)
						el.State = v and true or false
						tween(track, motion(0.18), { BackgroundColor3 = el.State and theme.accent or themed(Color3.fromRGB(72, 72, 76)) })
						tween(thumb, spring(0.32), {
							Position = UDim2.fromOffset(el.State and 16 or 2, 2),
							BackgroundColor3 = el.State and thumbColor() or C.white,
						})
						if not silent and o.Callback then
							task.spawn(o.Callback, el.State)
						end
					end
					function el:GetState()
						return el.State
					end
					function el:UpdateName(t)
						l.Text = t
						el._searchName = t
					end
					function el:SetVisiblity(v)
						shell.Visible = v and true or false
					end
					hit.MouseButton1Click:Connect(function()
						el:UpdateState(not el.State)
					end)
					register(el, shell, o.Name or "Toggle", "Toggle")
					flag(el, f)
					if o.Callback and state then
						task.defer(o.Callback, true)
					end
					return el
				end

				function section:Slider(o, f)
					o = o or {}
					local min = o.Minimum or 0
					local max = o.Maximum or 100
					local prec = o.Precision or 0
					local value = math.clamp(o.Default or min, min, max)
					local shell = makeShell(card, 34)
					local l = label(shell, o.Name or "Slider", 13, C.text, FONT)
					l.Size = UDim2.new(0.4, 0, 1, 0)
					l.Position = UDim2.fromOffset(10, 0)

					local function display(v)
						local p = prec
						local shown = tonumber(string.format("%." .. p .. "f", v)) or v
						local method = o.DisplayMethod or "Value"
						if method == "Percent" then
							local pct = (max - min) ~= 0 and (v - min) / (max - min) * 100 or 0
							return string.format("%." .. p .. "f%%", pct)
						elseif method == "Degrees" then
						return string.format("%." .. p .. "f deg", shown)
						elseif method == "Round" then
							return tostring(math.floor(shown + 0.5))
						end
						return string.format("%." .. p .. "f", shown)
					end

					local chip = new("Frame", {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -8, 0.5, 0),
						Size = UDim2.fromOffset(46, 20),
						BackgroundColor3 = C.bgDeep,
						Parent = shell,
					})
					corner(chip, 6)
					local val = label(chip, display(value), 11, C.text, FONT, Enum.TextXAlignment.Center)
					val.Size = UDim2.fromScale(1, 1)

					local bar = new("Frame", {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -64, 0.5, 0),
						Size = UDim2.new(0.42, 0, 0, 3),
						BackgroundColor3 = themed(Color3.fromRGB(90, 90, 94)),
						Parent = shell,
					})
					corner(bar, 2)
					local fill = new("Frame", {
						Size = UDim2.fromScale(max == min and 0 or (value - min) / (max - min), 1),
						BackgroundColor3 = theme.accent,
						Parent = bar,
					})
					corner(fill, 2)
					onTheme(function()
						fill.BackgroundColor3 = theme.accent
					end)
					local thumb = new("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(fill.Size.X.Scale, 0, 0.5, 0),
						Size = UDim2.fromOffset(13, 13),
						BackgroundColor3 = C.white,
						ZIndex = 3,
						Parent = bar,
					})
					corner(thumb, 7)

					local hit = new("TextButton", {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -64, 0.5, 0),
						Size = UDim2.new(0.42, 0, 0, 24),
						BackgroundTransparency = 1,
						Text = "",
						Parent = shell,
					})

					local el = { Value = value, Settings = o, _conns = {} }
					local sliding = false
					local function set(v, silent, complete)
						v = math.clamp(v, min, max)
						if prec <= 0 then
							v = math.floor(v + 0.5)
						else
							local m = 10 ^ prec
							v = math.floor(v * m + 0.5) / m
						end
						el.Value = v
						local alpha = (max - min) ~= 0 and (v - min) / (max - min) or 0
						fill.Size = UDim2.fromScale(alpha, 1)
						thumb.Position = UDim2.new(alpha, 0, 0.5, 0)
						val.Text = display(v)
						if not silent and o.Callback then
							task.spawn(o.Callback, v)
						end
						if complete and o.onInputComplete then
							task.spawn(o.onInputComplete, v)
						end
					end
					function el:UpdateValue(v)
						set(v, false, true)
					end
					function el:GetValue()
						return el.Value
					end
					function el:UpdateName(t)
						l.Text = t
						el._searchName = t
					end
					function el:SetVisiblity(v)
						shell.Visible = v and true or false
					end

					local function fromInput(input, complete)
						local x = (input.Position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1)
						set(min + math.clamp(x, 0, 1) * (max - min), false, complete)
					end
					hit.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
							sliding = true
							tween(thumb, spring(0.3), { Size = UDim2.fromOffset(16, 16) })
							fromInput(input, false)
						end
					end)
					table.insert(el._conns, UIS.InputEnded:Connect(function(input)
						if sliding and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
							sliding = false
							tween(thumb, motion(0.2), { Size = UDim2.fromOffset(13, 13) })
							fromInput(input, true)
						end
					end))
					table.insert(el._conns, UIS.InputChanged:Connect(function(input)
						if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
							fromInput(input, false)
						end
					end))
					register(el, shell, o.Name or "Slider", "Slider")
					flag(el, f)
					return el
				end

				function section:Input(o, f)
					o = o or {}
					local shell = makeShell(card, 34)
					local l = label(shell, o.Name or "Input", 13, C.text, FONT)
					l.Size = UDim2.new(0.42, 0, 1, 0)
					l.Position = UDim2.fromOffset(10, 0)
					local box = new("TextBox", {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -8, 0.5, 0),
						Size = UDim2.new(0.52, -8, 0, 24),
						BackgroundColor3 = C.bgDeep,
						Font = FONT_REG,
						TextSize = 12,
						TextColor3 = C.text,
						PlaceholderText = o.Placeholder or "",
						PlaceholderColor3 = C.textFaint,
						Text = o.Default or "",
						TextXAlignment = Enum.TextXAlignment.Left,
						ClearTextOnFocus = false,
						ClipsDescendants = true,
						Parent = shell,
					})
					corner(box, 7)
					padding(box, 0, 0, 8, 8)
					local el = { Text = box.Text, Settings = o }
					local function accept(text)
						return filterChars(o.AcceptedCharacters or "All", text)
					end
					box:GetPropertyChangedSignal("Text"):Connect(function()
						local filtered = accept(box.Text)
						if filtered ~= box.Text then
							box.Text = filtered
						end
						el.Text = box.Text
						if o.onChanged then
							task.spawn(o.onChanged, el.Text)
						end
					end)
					box.FocusLost:Connect(function()
						el.Text = box.Text
						if o.Callback then
							task.spawn(o.Callback, el.Text)
						end
					end)
					function el:GetInput()
						return el.Text
					end
					function el:UpdateText(t)
						box.Text = tostring(t or "")
						el.Text = box.Text
					end
					function el:UpdatePlaceholder(t)
						box.PlaceholderText = t
					end
					function el:UpdateName(t)
						l.Text = t
						el._searchName = t
					end
					function el:SetVisiblity(v)
						shell.Visible = v and true or false
					end
					register(el, shell, o.Name or "Input", "Input")
					flag(el, f)
					return el
				end

				function section:Keybind(o, f)
					o = o or {}
					local bind = o.Default
					local blacklist = {}
					if type(o.Blacklist) == "table" then
						for _, k in ipairs(o.Blacklist) do
							blacklist[k] = true
						end
					end
					local listening = false
					local shell = makeShell(card, 34)
					local l = label(shell, o.Name or "Keybind", 13, C.text, FONT)
					l.Size = UDim2.new(1, -110, 1, 0)
					l.Position = UDim2.fromOffset(10, 0)
					local chip = new("TextButton", {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -8, 0.5, 0),
						Size = UDim2.fromOffset(84, 22),
						BackgroundColor3 = C.bgDeep,
						Text = bind and keyName(bind) or "None",
						Font = FONT,
						TextSize = 12,
						TextColor3 = C.textDim,
						AutoButtonColor = false,
						Parent = shell,
					})
					corner(chip, 6)
					local el = { Bind = bind, Settings = o, _conns = {} }
					local function paint()
						chip.Text = listening and "Press..." or (el.Bind and keyName(el.Bind) or "None")
						chip.TextColor3 = listening and theme.accent or C.textDim
					end
					onTheme(paint)
					function el:SetBind(key, silent)
						if key and blacklist[key] then
							return
						end
						el.Bind = key
						listening = false
						paint()
						if not silent and o.onBinded then
							task.spawn(o.onBinded, key)
						end
					end
					function el:Unbind()
						el:SetBind(nil, true)
					end
					function el:GetBind()
						return el.Bind
					end
					function el:UpdateName(t)
						l.Text = t
						el._searchName = t
					end
					function el:SetVisiblity(v)
						shell.Visible = v and true or false
					end
					chip.MouseButton1Click:Connect(function()
						listening = true
						paint()
					end)
					table.insert(el._conns, UIS.InputBegan:Connect(function(input, gp)
						if listening then
							if input.UserInputType == Enum.UserInputType.Keyboard then
								if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Backspace then
									el:Unbind()
								else
									el:SetBind(input.KeyCode)
								end
							elseif input.UserInputType == Enum.UserInputType.MouseButton1 then
								listening = false
								paint()
							elseif input.UserInputType == Enum.UserInputType.MouseButton2
								or input.UserInputType == Enum.UserInputType.MouseButton3 then
								el:SetBind(input.UserInputType)
							end
							return
						end
						if gp or not el.Bind then
							return
						end
						local matched = (input.KeyCode == el.Bind) or (input.UserInputType == el.Bind)
						if matched then
							if o.onBindHeld then
								task.spawn(o.onBindHeld, true, el.Bind)
							end
							if o.Callback then
								task.spawn(o.Callback, el.Bind)
							end
						end
					end))
					table.insert(el._conns, UIS.InputEnded:Connect(function(input)
						if not el.Bind or listening then
							return
						end
						local matched = (input.KeyCode == el.Bind) or (input.UserInputType == el.Bind)
						if matched and o.onBindHeld then
							task.spawn(o.onBindHeld, false, el.Bind)
						end
					end))
					register(el, shell, o.Name or "Keybind", "Keybind")
					flag(el, f)
					return el
				end

				function section:Dropdown(o, f)
					o = o or {}
					local multi = o.Multi and true or false
					local required = o.Required and true or false
					local options = {}
					for _, opt in ipairs(o.Options or {}) do
						table.insert(options, tostring(opt))
					end
					local selected = {}
					if multi then
						for _, name in ipairs(o.Default or {}) do
							selected[tostring(name)] = true
						end
					else
						local idx = tonumber(o.Default) or 1
						if options[idx] then
							selected[options[idx]] = true
						elseif required and options[1] then
							selected[options[1]] = true
						end
					end

					local shell = makeShell(card, 34)
					local l = label(shell, o.Name or "Dropdown", 13, C.text, FONT)
					l.Size = UDim2.new(0.5, -8, 1, 0)
					l.Position = UDim2.fromOffset(10, 0)
					local chip = new("TextButton", {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -8, 0.5, 0),
						Size = UDim2.new(0.46, 0, 0, 22),
						BackgroundColor3 = C.bgDeep,
						Text = "",
						Font = FONT_REG,
						TextSize = 12,
						TextColor3 = C.textDim,
						TextTruncate = Enum.TextTruncate.AtEnd,
						AutoButtonColor = false,
						Parent = shell,
					})
					corner(chip, 6)

					local MENU_MAX_H = 240
					local menu = new("ScrollingFrame", {
						Size = UDim2.fromOffset(210, MENU_MAX_H),
						BackgroundColor3 = Color3.fromRGB(36, 36, 38),
						Visible = false,
						ZIndex = 30,
						ScrollBarThickness = 4,
						ScrollBarImageColor3 = C.separator,
						ScrollingDirection = Enum.ScrollingDirection.Y,
						ScrollingEnabled = true,
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						CanvasSize = UDim2.new(0, 0, 0, 0),
						BorderSizePixel = 0,
						Parent = screen,
					})
					corner(menu, 10)
					stroke(menu, C.white, 1, 0.88)
					padding(menu, 4, 4, 4, 4)
					local menuList = new("Frame", {
						Size = UDim2.fromScale(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						ZIndex = 31,
						Parent = menu,
					})
					list(menuList, Enum.FillDirection.Vertical, 1)
					menu.CanvasPosition = Vector2.new(0, 0)

					local searchRow
					local searchInput
					if o.Search then
						searchInput = new("TextBox", {
							Size = UDim2.new(1, 0, 0, 24),
							BackgroundColor3 = C.card,
							Font = FONT_REG,
							TextSize = 12,
							TextColor3 = C.text,
							PlaceholderText = "Search",
							PlaceholderColor3 = C.textFaint,
							Text = "",
							ClearTextOnFocus = false,
							Parent = menuList,
						})
						corner(searchInput, 6)
						padding(searchInput, 0, 0, 8, 8)
					end

					local el = { Settings = o, _rows = {} }
					local function current()
						if multi then
							local map = {}
							for _, name in ipairs(options) do
								map[name] = selected[name] and true or false
							end
							return map
						end
						for _, name in ipairs(options) do
							if selected[name] then
								return name
							end
						end
						return nil
					end
					el.Value = current()

					local function summary()
						local names = {}
						for _, name in ipairs(options) do
							if selected[name] then
								table.insert(names, name)
							end
						end
						if #names == 0 then
							return "None"
						end
						return table.concat(names, ", ")
					end
					local function paint()
						chip.Text = summary()
						el.Value = current()
					end

					local function fire()
						paint()
						if o.Callback then
							task.spawn(o.Callback, el.Value)
						end
					end

					local function rebuild()
						for _, r in ipairs(el._rows) do
							r:Destroy()
						end
						el._rows = {}
						local q = searchInput and searchInput.Text:lower() or ""
						for _, name in ipairs(options) do
							if q == "" or name:lower():find(q, 1, true) then
								local rowFont = FONT_REG
								if o.FontPreview and fontSets[name] then
									rowFont = fontSets[name].regular
								end
								local row = new("TextButton", {
									Size = UDim2.new(1, 0, 0, 26),
									BackgroundColor3 = selected[name] and theme.accent or themed(C.card),
									BackgroundTransparency = selected[name] and 0.75 or 1,
									Text = "    " .. name,
									Font = rowFont,
									TextSize = 12,
									TextColor3 = C.text,
									TextXAlignment = Enum.TextXAlignment.Left,
									AutoButtonColor = false,
									Parent = menuList,
								})
								corner(row, 6)
								local mark = label(row, selected[name] and "✓" or "", 12, C.white, FONT_BOLD, Enum.TextXAlignment.Right)
								mark.Size = UDim2.new(1, -8, 1, 0)
								row.MouseButton1Click:Connect(function()
									if multi then
										if selected[name] and required then
											local count = 0
											for _, n in ipairs(options) do
												if selected[n] then
													count += 1
												end
											end
											if count <= 1 then
												return
											end
										end
										selected[name] = not selected[name]
									else
										for k in pairs(selected) do
											selected[k] = nil
										end
										selected[name] = true
										closePopovers()
									end
									fire()
									rebuild()
								end)
								table.insert(el._rows, row)
							end
						end
					end
					if searchInput then
						searchInput:GetPropertyChangedSignal("Text"):Connect(rebuild)
					end
					chip.MouseButton1Click:Connect(function()
						if menu.Visible then
							closePopovers()
							return
						end
						openPopover(menu)
						rebuild()
						local topLeft = chip.AbsolutePosition + Vector2.new(chip.AbsoluteSize.X - 210, chip.AbsoluteSize.Y + 6)
						menu.Position = UDim2.fromOffset(math.floor(topLeft.X + 0.5), math.floor(topLeft.Y + 0.5))
						-- Fit the frame to its content once Roblox has laid out the fresh rows
						-- (AbsoluteSize reads are stale/zero in the same frame as rebuild()).
						task.defer(function()
							if not menu.Visible then return end
							local h = math.min(MENU_MAX_H, menuList.AbsoluteSize.Y + 8)
							if h > 0 then menu.Size = UDim2.fromOffset(210, h) end
							-- bring the current selection into view
							if not multi then
								for _, r in ipairs(el._rows) do
									if r.BackgroundTransparency < 1 then
										local y = r.AbsolutePosition.Y - menu.AbsolutePosition.Y + menu.CanvasPosition.Y - menu.AbsoluteSize.Y / 2
										menu.CanvasPosition = Vector2.new(0, math.max(0, y))
										break
									end
								end
							end
							clampToScreen(menu)
						end)
					end)
					paint()

					function el:UpdateSelection(v)
						for k in pairs(selected) do
							selected[k] = nil
						end
						if multi then
							if type(v) == "table" then
								if v[1] ~= nil then
									for _, name in ipairs(v) do
										selected[tostring(name)] = true
									end
								else
									for name, on in pairs(v) do
										if on then
											selected[tostring(name)] = true
										end
									end
								end
							end
						else
							if type(v) == "number" then
								if options[v] then
									selected[options[v]] = true
								end
							elseif type(v) == "string" then
								selected[v] = true
							end
						end
						fire()
						if menu.Visible then
							rebuild()
						end
					end
					function el:InsertOptions(list)
						for _, name in ipairs(list or {}) do
							if not table.find(options, tostring(name)) then
								table.insert(options, tostring(name))
							end
						end
						if menu.Visible then
							rebuild()
						end
						paint()
					end
					function el:RemoveOptions(list)
						local drop = {}
						for _, name in ipairs(list or {}) do
							drop[tostring(name)] = true
						end
						local kept = {}
						for _, name in ipairs(options) do
							if not drop[name] then
								table.insert(kept, name)
							else
								selected[name] = nil
							end
						end
						options = kept
						fire()
						if menu.Visible then
							rebuild()
						end
					end
					function el:ClearOptions()
						options = {}
						selected = {}
						fire()
						rebuild()
					end
					function el:IsOption(name)
						return table.find(options, tostring(name)) ~= nil
					end
					function el:GetOptions()
						local map = {}
						for _, name in ipairs(options) do
							map[name] = selected[name] and true or false
						end
						return map
					end
					function el:UpdateName(t)
						l.Text = t
						el._searchName = t
					end
					function el:SetVisiblity(v)
						shell.Visible = v and true or false
						if not v then
							closePopovers()
						end
					end
					register(el, shell, o.Name or "Dropdown", "Dropdown")
					flag(el, f)
					if o.Callback and next(selected) then
						task.defer(o.Callback, el.Value)
					end
					return el
				end

				function section:Colorpicker(o, f)
					o = o or {}
					local color = o.Default or Color3.fromRGB(10, 132, 255)
					local alpha = o.Alpha
					local h, s, v = color:ToHSV()
					local shell = makeShell(card, 34)
					local l = label(shell, o.Name or "Color", 13, C.text, FONT)
					l.Size = UDim2.new(1, -46, 1, 0)
					l.Position = UDim2.fromOffset(10, 0)
					local swatch = new("TextButton", {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -10, 0.5, 0),
						Size = UDim2.fromOffset(22, 22),
						BackgroundColor3 = color,
						Text = "",
						AutoButtonColor = false,
						Parent = shell,
					})
					corner(swatch, 11)
					stroke(swatch, C.white, 1, 0.75)

					local popup = new("Frame", {
						Size = UDim2.fromOffset(230, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundColor3 = Color3.fromRGB(36, 36, 38),
						Visible = false,
						ZIndex = 30,
						Parent = screen,
					})
					corner(popup, 12)
					stroke(popup, C.white, 1, 0.88)
					padding(popup, 10, 10, 10, 10)
					list(popup, Enum.FillDirection.Vertical, 8)

					local sat = new("ImageButton", {
						Size = UDim2.new(1, 0, 0, 110),
						AutoButtonColor = false,
						Image = "",
						Parent = popup,
					})
					corner(sat, 8)
					local satGrad = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromHSV(h, 1, 1), Parent = sat })
					local whiteGrad = new("UIGradient", {
						Color = ColorSequence.new(C.white, C.white:Lerp(Color3.new(1, 1, 1), 0)),
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 0),
							NumberSequenceKeypoint.new(1, 1),
						}),
						Parent = satGrad,
					})
					whiteGrad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1))
					local blackOverlay = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.black, Parent = sat })
					new("UIGradient", {
						Rotation = 90,
						Transparency = NumberSequence.new({
							NumberSequenceKeypoint.new(0, 1),
							NumberSequenceKeypoint.new(1, 0),
						}),
						Parent = blackOverlay,
					})
					local satCursor = new("Frame", {
						AnchorPoint = Vector2.new(0.5, 0.5),
						Size = UDim2.fromOffset(12, 12),
						Position = UDim2.fromScale(s, 1 - v),
						BackgroundColor3 = C.white,
						ZIndex = 3,
						Parent = sat,
					})
					corner(satCursor, 6)
					stroke(satCursor, C.black, 1, 0.4)

					local hueBar = new("ImageButton", {
						Size = UDim2.new(1, 0, 0, 14),
						AutoButtonColor = false,
						Image = "",
						Parent = popup,
					})
					corner(hueBar, 7)
					new("UIGradient", {
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
							ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
							ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
							ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
							ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
							ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
							ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
						}),
						Parent = hueBar,
					})

					local alphaBar
					if alpha ~= nil then
						alphaBar = new("TextButton", {
							Size = UDim2.new(1, 0, 0, 14),
							BackgroundColor3 = color,
							Text = "",
							AutoButtonColor = false,
							Parent = popup,
						})
						corner(alphaBar, 7)
						new("UIGradient", {
							Transparency = NumberSequence.new({
								NumberSequenceKeypoint.new(0, 0),
								NumberSequenceKeypoint.new(1, 1),
							}),
							Parent = alphaBar,
						})
					end

					local readouts = new("Frame", {
						Size = UDim2.new(1, 0, 0, 22),
						BackgroundTransparency = 1,
						Parent = popup,
					})
					local rl = list(readouts, Enum.FillDirection.Horizontal, 6)
					rl.VerticalAlignment = Enum.VerticalAlignment.Center
					local function mini(placeholder, width)
						local b = new("TextBox", {
							Size = UDim2.fromOffset(width, 22),
							BackgroundColor3 = C.card,
							Font = FONT,
							TextSize = 11,
							TextColor3 = C.text,
							Text = "",
							PlaceholderText = placeholder,
							ClearTextOnFocus = false,
							Parent = readouts,
						})
						corner(b, 6)
						return b
					end
					local hexBox = mini("#HEX", 78)
					local rBox = mini("R", 40)
					local gBox = mini("G", 40)
					local bBox = mini("B", 40)

					local el = { Color = color, Alpha = alpha or 0, Settings = o }
					local suppress = false
					local function emit()
						el.Color = Color3.fromHSV(h, s, v)
						swatch.BackgroundColor3 = el.Color
						satGrad.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
						satCursor.Position = UDim2.fromScale(s, 1 - v)
						if alphaBar then
							alphaBar.BackgroundColor3 = el.Color
						end
						if not suppress then
							local rgb = colorToTable(el.Color)
							hexBox.Text = string.format("#%02X%02X%02X", rgb[1], rgb[2], rgb[3])
							rBox.Text = tostring(rgb[1])
							gBox.Text = tostring(rgb[2])
							bBox.Text = tostring(rgb[3])
						end
						if o.Callback then
							task.spawn(o.Callback, el.Color, el.Alpha)
						end
					end
					function el:SetColor(c)
						el.Color = c
						h, s, v = c:ToHSV()
						emit()
					end
					function el:SetAlpha(a)
						el.Alpha = math.clamp(tonumber(a) or 0, 0, 1)
						emit()
					end
					function el:UpdateName(t)
						l.Text = t
						el._searchName = t
					end
					function el:SetVisiblity(vis)
						shell.Visible = vis and true or false
						if not vis then
							popup.Visible = false
						end
					end
					function el:SetVisibility(vis)
						el:SetVisiblity(vis)
					end

					local function pickSV(input)
						local rx = math.clamp((input.Position.X - sat.AbsolutePosition.X) / math.max(sat.AbsoluteSize.X, 1), 0, 1)
						local ry = math.clamp((input.Position.Y - sat.AbsolutePosition.Y) / math.max(sat.AbsoluteSize.Y, 1), 0, 1)
						s, v = rx, 1 - ry
						emit()
					end
					local function pickHue(input)
						h = math.clamp((input.Position.X - hueBar.AbsolutePosition.X) / math.max(hueBar.AbsoluteSize.X, 1), 0, 1)
						emit()
					end
					local dragSV, dragHue, dragA = false, false, false
					sat.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 then
							dragSV = true
							pickSV(input)
						end
					end)
					hueBar.InputBegan:Connect(function(input)
						if input.UserInputType == Enum.UserInputType.MouseButton1 then
							dragHue = true
							pickHue(input)
						end
					end)
					if alphaBar then
						alphaBar.InputBegan:Connect(function(input)
							if input.UserInputType == Enum.UserInputType.MouseButton1 then
								dragA = true
								el.Alpha = math.clamp((input.Position.X - alphaBar.AbsolutePosition.X) / math.max(alphaBar.AbsoluteSize.X, 1), 0, 1)
								emit()
							end
						end)
					end
					el._conns = {
						UIS.InputEnded:Connect(function(input)
							if input.UserInputType == Enum.UserInputType.MouseButton1 then
								dragSV, dragHue, dragA = false, false, false
							end
						end),
						UIS.InputChanged:Connect(function(input)
							if input.UserInputType ~= Enum.UserInputType.MouseMovement then
								return
							end
							if dragSV then
								pickSV(input)
							elseif dragHue then
								pickHue(input)
							elseif dragA and alphaBar then
								el.Alpha = math.clamp((input.Position.X - alphaBar.AbsolutePosition.X) / math.max(alphaBar.AbsoluteSize.X, 1), 0, 1)
								emit()
							end
						end),
					}

					local function fromBoxes()
						suppress = true
						local r = math.clamp(tonumber(rBox.Text) or 0, 0, 255)
						local g = math.clamp(tonumber(gBox.Text) or 0, 0, 255)
						local b = math.clamp(tonumber(bBox.Text) or 0, 0, 255)
						h, s, v = Color3.fromRGB(r, g, b):ToHSV()
						suppress = false
						emit()
					end
					rBox.FocusLost:Connect(fromBoxes)
					gBox.FocusLost:Connect(fromBoxes)
					bBox.FocusLost:Connect(fromBoxes)
					hexBox.FocusLost:Connect(function()
						local hex = hexBox.Text:gsub("#", "")
						if #hex == 6 then
							local r = tonumber(hex:sub(1, 2), 16)
							local g = tonumber(hex:sub(3, 4), 16)
							local b = tonumber(hex:sub(5, 6), 16)
							if r and g and b then
								h, s, v = Color3.fromRGB(r, g, b):ToHSV()
								emit()
							end
						end
					end)

					swatch.MouseButton1Click:Connect(function()
						if popup.Visible then
							closePopovers()
							return
						end
						openPopover(popup)
						local origin = swatch.AbsolutePosition
						popup.Position = UDim2.fromOffset(math.floor(origin.X - 200 + 0.5), math.floor(origin.Y + 28 + 0.5))
					end)
					emit()
					register(el, shell, o.Name or "Color", "Colorpicker")
					flag(el, f)
					return el
				end

				function section:Segmented(o, f)
					o = o or {}
					local options = {}
					for _, opt in ipairs(o.Options or {}) do
						table.insert(options, tostring(opt))
					end
					if #options == 0 then
						options = { "One", "Two" }
					end
					local index = math.clamp(tonumber(o.Default) or 1, 1, #options)
					local shell = makeShell(card, 44)
					local l = label(shell, o.Name or "View", 13, C.text, FONT)
					l.Size = UDim2.new(1, -20, 0, 16)
					l.Position = UDim2.fromOffset(10, 3)
					local track = new("Frame", {
						Position = UDim2.fromOffset(10, 21),
						Size = UDim2.new(1, -20, 0, 21),
						BackgroundColor3 = C.bgDeep,
						Parent = shell,
					})
					corner(track, 6)
					local pill = new("Frame", {
						Size = UDim2.new(1 / #options, -2, 1, -4),
						Position = UDim2.new((index - 1) / #options, 1, 0, 2),
						BackgroundColor3 = Color3.fromRGB(72, 72, 76),
						ZIndex = 3,
						Parent = track,
					})
					corner(pill, 5)
					local buttons = {}
					local el = { Value = options[index], Settings = o }
					local function paint()
						for i, b in ipairs(buttons) do
							b.TextColor3 = i == index and C.text or C.textDim
						end
						tween(pill, spring(0.35), { Position = UDim2.new((index - 1) / #options, 1, 0, 2) })
					end
					local function set(i, silent)
						index = math.clamp(i, 1, #options)
						el.Value = options[index]
						paint()
						if not silent and o.Callback then
							task.spawn(o.Callback, el.Value)
						end
					end
					for i, name in ipairs(options) do
						local b = new("TextButton", {
							Size = UDim2.new(1 / #options, 0, 1, 0),
							Position = UDim2.new((i - 1) / #options, 0, 0, 0),
							BackgroundTransparency = 1,
							Text = name,
							Font = FONT,
							TextSize = 12,
							TextColor3 = C.textDim,
							AutoButtonColor = false,
							ZIndex = 4,
							Parent = track,
						})
						b.MouseButton1Click:Connect(function()
							set(i)
						end)
						table.insert(buttons, b)
					end
					function el:UpdateSelection(v)
						if type(v) == "number" then
							set(v)
						elseif type(v) == "string" then
							local found = table.find(options, v)
							if found then
								set(found)
							end
						end
					end
					function el:GetSelection()
						return el.Value
					end
					function el:UpdateName(t)
						l.Text = t
						el._searchName = t
					end
					function el:SetVisiblity(v)
						shell.Visible = v and true or false
					end
					register(el, shell, o.Name or "View", "Segmented")
					flag(el, f)
					paint()
					return el
				end

				function section:Swatches(o, f)
					o = o or {}
					local colors = o.Colors or {
						Color3.fromRGB(255, 255, 255),
						Color3.fromRGB(10, 132, 255),
						Color3.fromRGB(191, 90, 242),
						Color3.fromRGB(255, 55, 95),
						Color3.fromRGB(255, 159, 10),
						Color3.fromRGB(48, 209, 88),
					}
					local names = o.Names
					local index = math.clamp(tonumber(o.Default) or 1, 1, #colors)
					local shell = makeShell(card, 62)
					local l = label(shell, o.Name or "Accent", 13, C.text, FONT)
					l.Size = UDim2.new(1, -20, 0, 16)
					l.Position = UDim2.fromOffset(10, 6)
					local row = new("Frame", {
						Position = UDim2.fromOffset(10, 26),
						Size = UDim2.new(1, -20, 0, 26),
						BackgroundTransparency = 1,
						Parent = shell,
					})
					local dots = {}
					local rings = {}
					local scales = {}
					local el = { Value = colors[index], Settings = o }
					local function paint()
						for i, ring in ipairs(rings) do
							ring.Transparency = i == index and 0 or 1
						end
						el.Value = colors[index]
						el._index = index
					end
					local function set(i, silent)
						index = math.clamp(i, 1, #colors)
						paint()
						local dot = dots[index]
						if dot and scales[index] then
							scales[index].Scale = 0.8
							tween(scales[index], spring(0.35), { Scale = 1 })
						end
						if not silent and o.Callback then
							task.spawn(o.Callback, el.Value, names and names[index] or index)
						end
					end
					for i, color in ipairs(colors) do
						local dot = new("TextButton", {
							Size = UDim2.fromOffset(22, 22),
							Position = UDim2.fromOffset(2 + (i - 1) * 28, 2),
							BackgroundColor3 = color,
							Text = "",
							AutoButtonColor = false,
							Parent = row,
						})
						corner(dot, 11)
						local ring = new("Frame", {
							Size = UDim2.fromOffset(30, 30),
							Position = UDim2.fromOffset(-4, -4),
							BackgroundTransparency = 1,
							Parent = dot,
						})
						corner(ring, 15)
						local rs = stroke(ring, C.white, 1.5, 0)
						rs.Transparency = 1
						dots[i] = dot
						rings[i] = rs
						scales[i] = new("UIScale", { Scale = 1, Parent = dot })
						dot.MouseEnter:Connect(function()
							tween(scales[i], motion(0.14), { Scale = 1.15 })
						end)
						dot.MouseLeave:Connect(function()
							tween(scales[i], motion(0.14), { Scale = 1 })
						end)
						dot.MouseButton1Click:Connect(function()
							set(i)
						end)
					end
					function el:UpdateSelection(v)
						if type(v) == "number" then
							set(v)
						elseif typeof(v) == "Color3" then
							for i, color in ipairs(colors) do
								if color == v then
									set(i)
									return
								end
							end
						end
					end
					function el:GetSelection()
						return el.Value
					end
					function el:UpdateName(t)
						l.Text = t
						el._searchName = t
					end
					function el:SetVisiblity(v)
						shell.Visible = v and true or false
					end
					register(el, shell, o.Name or "Accent", "Swatches")
					flag(el, f)
					paint()
					return el
				end

				function section:Progress(o, f)
					o = o or {}
					local value = math.clamp(tonumber(o.Default) or 0, 0, 1)
					local shell = makeShell(card, 34)
					local l = label(shell, o.Name or "Progress", 13, C.text, FONT)
					l.Size = UDim2.new(0.4, 0, 1, 0)
					l.Position = UDim2.fromOffset(10, 0)
					local chip = new("Frame", {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -8, 0.5, 0),
						Size = UDim2.fromOffset(46, 20),
						BackgroundColor3 = C.bgDeep,
						Parent = shell,
					})
					corner(chip, 6)
					local val = label(chip, string.format("%d%%", math.floor(value * 100 + 0.5)), 11, C.text, FONT, Enum.TextXAlignment.Center)
					val.Size = UDim2.fromScale(1, 1)
					local bar = new("Frame", {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, -64, 0.5, 0),
						Size = UDim2.new(0.42, 0, 0, 3),
						BackgroundColor3 = themed(Color3.fromRGB(90, 90, 94)),
						Parent = shell,
					})
					corner(bar, 2)
					local fill = new("Frame", {
						Size = UDim2.fromScale(value, 1),
						BackgroundColor3 = theme.accent,
						Parent = bar,
					})
					corner(fill, 2)
					onTheme(function()
						fill.BackgroundColor3 = theme.accent
					end)
					local el = { Value = value, Settings = o }
					function el:UpdateValue(v)
						el.Value = math.clamp(tonumber(v) or 0, 0, 1)
						tween(fill, motion(0.25), { Size = UDim2.fromScale(el.Value, 1) })
						val.Text = string.format("%d%%", math.floor(el.Value * 100 + 0.5))
						if o.Callback then
							task.spawn(o.Callback, el.Value)
						end
					end
					function el:GetValue()
						return el.Value
					end
					function el:UpdateName(t)
						l.Text = t
						el._searchName = t
					end
					function el:SetVisiblity(v)
						shell.Visible = v and true or false
					end
					register(el, shell, o.Name or "Progress", "Progress")
					flag(el, f)
					return el
				end

				return section
			end

			function tab:InsertConfigSection(side)
				local sec = tab:Section({ Side = side or "Left" })
				sec:Header({ Name = "Configuration" })

				local selected = "config"
				local list = {}
				local function refresh()
					list = MacLib:RefreshConfigList()
				end
				refresh()

				local nameInput = sec:Input({
					Name = "Config Name",
					Placeholder = "config",
					AcceptedCharacters = "AlphaNumeric",
					Callback = function(text)
						selected = text ~= "" and text or "config"
					end,
				})

				local picker = sec:Dropdown({
					Name = "Saved Configs",
					Search = true,
					Options = #list > 0 and list or { "none" },
					Default = 1,
					Callback = function(v)
						if v and v ~= "none" then
							selected = v:gsub("%.json$", "")
							nameInput:UpdateText(selected)
						end
					end,
				})

				sec:Button({
					Name = "Save Config",
					Callback = function()
						MacLib:SaveConfig(selected)
						refresh()
						picker:ClearOptions()
						picker:InsertOptions(list)
						window:Notify({ Title = S.Title, Description = "Saved " .. selected, Lifetime = 3, Style = "Confirm" })
					end,
				})
				sec:Button({
					Name = "Load Config",
					Callback = function()
						local ok = MacLib:LoadConfig(selected)
						window:Notify({
							Title = S.Title,
							Description = ok and ("Loaded " .. selected) or "Config not found",
							Lifetime = 3,
							Style = ok and "Confirm" or "Cancel",
						})
					end,
				})
				sec:Button({
					Name = "Delete Config",
					Callback = function()
						local path = select(1, window:_configPath(selected))
						if fs(path) then
							df(path)
						end
						refresh()
						picker:ClearOptions()
						picker:InsertOptions(#list > 0 and list or { "none" })
						window:Notify({ Title = S.Title, Description = "Deleted " .. selected, Lifetime = 3 })
					end,
				})

				local auto = false
				sec:Toggle({
					Name = "Auto Load",
					Default = false,
					Callback = function(v)
						auto = v
						MacLib:SetFolder(MacLib.Folder)
						wf(MacLib.Folder .. "/autoload.txt", v and (selected .. ".json") or "")
					end,
				})
				sec:Button({
					Name = "Refresh List",
					Callback = function()
						refresh()
						picker:ClearOptions()
						picker:InsertOptions(#list > 0 and list or { "none" })
					end,
				})
				return sec
			end

			table.insert(group.Tabs, tab)
			table.insert(window.Tabs, tab)
			if not selectedTab then
				tab:Select()
			end
			return tab
		end

		return group
	end

	-- search bar offset follows the open state so content isn't hidden under it
	searchBox:GetPropertyChangedSignal("Text"):Connect(function() end)
	local function relayoutSearch() end
	searchBar:GetPropertyChangedSignal("Size"):Connect(relayoutSearch)

	table.insert(MacLib.Windows, self)

	-- MacLib config functions operate on the most recent window, matching single-window use.
	function MacLib:SaveConfig(path)
		local full, name = self:_configPath(path)
		wf(full, encode(collect()))
		return name
	end
	function MacLib:LoadConfig(path)
		local full = select(1, self:_configPath(path))
		local raw = rf(full)
		if not raw then
			return false
		end
		local data = decode(raw)
		if not data then
			return false
		end
		apply(data)
		return true
	end
	function MacLib:RefreshConfigList()
		MacLib:SetFolder(MacLib.Folder)
		local out = {}
		for _, p in ipairs(lf(MacLib.Folder .. "/configs")) do
			local name = tostring(p):match("[^/\\]+$")
			if name and name:sub(-5) == ".json" then
				table.insert(out, name)
			end
		end
		table.sort(out)
		return out
	end
	function MacLib:LoadAutoLoadConfig()
		MacLib:SetFolder(MacLib.Folder)
		local raw = rf(MacLib.Folder .. "/autoload.txt")
		if raw and raw ~= "" then
			return MacLib:LoadConfig(raw)
		end
		return false
	end

	if theme.mode ~= "Glass" then
		task.defer(function()
			MacLib:SetMode(theme.mode)
		end)
	end

	task.delay(1.4, function()
		if not self.Unloaded then
			MacLib:Polish()
		end
	end)

	return self
end

function MacLib:Demo()
	local Window = self:Window({
		Title = "Maclib",
		Subtitle = "Sequoia",
		Size = UDim2.fromOffset(880, 580),
		DragStyle = 1,
		ShowUserInfo = true,
		Keybind = Enum.KeyCode.RightControl,
		AcrylicBlur = true,
	})

	Window:GlobalSetting({
		Name = "Notifications",
		Default = Window:GetNotificationsState(),
		Callback = function(v)
			Window:SetNotificationsState(v)
		end,
	})
	Window:GlobalSetting({
		Name = "Show User Info",
		Default = Window:GetUserInfoState(),
		Callback = function(v)
			Window:SetUserInfoState(v)
		end,
	})

	local group = Window:TabGroup()
	local home = group:Tab({ Name = "Home", Icon = "bolt" })
	local parts = group:Tab({ Name = "Components", Icon = "folder" })
	local look = group:Tab({ Name = "Appearance", Icon = "eye" })
	local settings = group:Tab({ Name = "Settings", Icon = "sliders" })

	local intro = home:Section({ Side = "Left" })
	intro:Header({ Name = "Welcome", Icon = "lens" })
	intro:Paragraph({
		Header = "Maclib 2",
		Body = "A macOS styled interface for Roblox. Everything in this window is a real element you can build with.",
	})
	intro:Button({
		Name = "Send a notification",
		Callback = function()
			Window:Notify({
				Title = "Maclib",
				Description = "Alerts live in the island at the top. Click it to open the window.",
				Lifetime = 4,
				Style = "Confirm",
			})
		end,
	})
	intro:Button({
		Name = "Open a dialog",
		Callback = function()
			Window:Dialog({
				Title = "Restart session?",
				Description = "This closes the window and clears everything it added.",
				Buttons = {
					{ Name = "Restart", Callback = function() end },
					{ Name = "Cancel" },
				},
			})
		end,
	})
	intro:Divider()
	intro:Label({ Text = "Right Control hides the window. The terminal button opens the palette." })
	intro:SubLabel({ Text = "The pill at the top is the island: clock when idle, alerts when busy." })

	local demo = home:Section({ Side = "Right" })
	demo:Header({ Name = "Live", Icon = "clock" })
	local progress = demo:Progress({ Name = "Rendering", Default = 0.25 }, "DemoProgress")
	demo:Button({
		Name = "Run the progress bar",
		Callback = function()
			task.spawn(function()
				for step = 0, 100, 4 do
					progress:UpdateValue(step / 100)
					task.wait(0.03)
				end
				Window:Notify({ Title = "Done", Description = "The progress bar finished.", Lifetime = 3, Style = "Confirm" })
			end)
		end,
	})
	demo:Button({
		Name = "Island live activity",
		Callback = function()
			local activity = MacLib:Island({
				Title = "Downloading",
				Description = "maclib.lua",
				Progress = 0,
				Lifetime = 0,
				Color = theme.accent,
			})
			task.spawn(function()
				for step = 0, 100, 5 do
					activity:UpdateProgress(step / 100)
					task.wait(0.08)
				end
				activity:Cancel()
				Window:Notify({ Title = "Downloaded", Description = "maclib.lua", Lifetime = 3, Style = "Confirm" })
			end)
		end,
	})
	demo:Button({
		Name = "Send three alerts",
		Callback = function()
			Window:Notify({ Title = "First", Description = "They queue in the island.", Lifetime = 3 })
			Window:Notify({ Title = "Second", Description = "One at a time.", Lifetime = 3 })
			Window:Notify({ Title = "Third", Description = "Then back to the clock.", Lifetime = 3, Style = "Confirm" })
		end,
	})
	demo:Segmented({
		Name = "Density",
		Options = { "Comfortable", "Compact" },
		Default = 1,
		Callback = function(v)
			Window:Notify({ Title = "Density", Description = "Set to " .. tostring(v), Lifetime = 2 })
		end,
	}, "DemoDensity")
	demo:Label({ Text = "Segmented controls and progress bars are new here." })

	local inputs = parts:Section({ Side = "Left" })
	inputs:Header({ Name = "Inputs", Icon = "code" })
	inputs:Toggle({
		Name = "Streamer mode",
		Default = false,
		Callback = function(v)
			Window:SetUserInfoState(not v)
			Window:Notify({ Title = "Streamer mode", Description = v and "Names hidden" or "Names shown", Lifetime = 2 })
		end,
	}, "Streamer")
	inputs:Slider({
		Name = "Volume",
		Default = 60,
		Minimum = 0,
		Maximum = 100,
		DisplayMethod = "Percent",
		Precision = 0,
		Callback = function(v)
			print("volume", v)
		end,
	}, "Volume")
	inputs:Input({
		Name = "Nickname",
		Placeholder = "Type a name",
		AcceptedCharacters = "AlphaNumeric",
		Callback = function(text)
			Window:Notify({ Title = "Nickname", Description = "Saved as " .. text, Lifetime = 2 })
		end,
	}, "Nickname")
	inputs:Keybind({
		Name = "Toggle effect",
		Default = Enum.KeyCode.F,
		Callback = function()
			Window:Notify({ Title = "Keybind", Description = "Effect toggled", Lifetime = 2 })
		end,
		onBinded = function(key)
			Window:Notify({ Title = "Keybind", Description = "Bound to " .. tostring(key.Name), Lifetime = 2 })
		end,
	}, "EffectBind")

	local choices = parts:Section({ Side = "Right" })
	choices:Header({ Name = "Choices", Icon = "check" })
	choices:Dropdown({
		Name = "Quality",
		Search = true,
		Options = { "Low", "Medium", "High", "Ultra" },
		Default = 3,
		Callback = function(v)
			Window:Notify({ Title = "Quality", Description = "Set to " .. tostring(v), Lifetime = 2 })
		end,
	}, "Quality")
	local sceneLighting = game:GetService("Lighting")
	local sceneActive = {}

	local sceneDefs = {
		Bloom = { class = "BloomEffect", props = { Intensity = 0.6, Size = 20, Threshold = 0.9 } },
		["Colour grade"] = { class = "ColorCorrectionEffect", props = { Saturation = 0.18, Contrast = 0.06, Brightness = 0.01 } },
		["Depth of field"] = { class = "DepthOfFieldEffect", props = { FarIntensity = 0.12, FocusDistance = 40, InFocusRadius = 30 } },
		["Sun rays"] = { class = "SunRaysEffect", props = { Intensity = 0.08, Spread = 0.9 } },
	}

	local function applySceneEffects(map)
		for name, def in pairs(sceneDefs) do
			local wanted = map[name] and true or false
			local existing = sceneActive[name]
			if wanted and not (existing and existing.Parent) then
				local fx = new(def.class, { Name = "Maclib_" .. def.class })
				for k, v in pairs(def.props) do
					fx[k] = v
				end
				fx.Parent = sceneLighting
				sceneActive[name] = fx
			elseif not wanted and existing then
				existing:Destroy()
				sceneActive[name] = nil
			end
		end
	end

	Window.onUnloaded(function()
		for _, fx in pairs(sceneActive) do
			pcall(function()
				fx:Destroy()
			end)
		end
		sceneActive = {}
	end)

	choices:Dropdown({
		Name = "Scene effects",
		Multi = true,
		Search = true,
		Options = { "Bloom", "Colour grade", "Depth of field", "Sun rays" },
		Default = {},
		Callback = function(map)
			applySceneEffects(map)
			local effects = {}
			for name, on in pairs(map) do
				if on then
					table.insert(effects, name)
				end
			end
			Window:Notify({ Title = "Scene", Description = #effects > 0 and table.concat(effects, ", ") or "none", Lifetime = 2 })
		end,
	}, "Effects")
	choices:Colorpicker({
		Name = "Highlight color",
		Default = Color3.fromRGB(10, 132, 255),
		Callback = function(color)
			MacLib:SetAccent(color)
			Window:Notify({
				Title = "Accent",
				Description = string.format("Set to #%02X%02X%02X", math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255)),
				Lifetime = 2,
			})
		end,
	}, "Highlight")

	local themeSec = look:Section({ Side = "Left" })
	themeSec:Header({ Name = "Theme", Icon = "sun" })
	local accents = {
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(10, 132, 255),
		Color3.fromRGB(191, 90, 242),
		Color3.fromRGB(255, 55, 95),
		Color3.fromRGB(255, 159, 10),
		Color3.fromRGB(48, 209, 88),
	}
	themeSec:Swatches({
		Name = "Accent",
		Colors = accents,
		Names = { "White", "Blue", "Purple", "Pink", "Orange", "Green" },
		Default = 1,
		Callback = function(color, name)
			MacLib:SetAccent(color)
			Window:Notify({ Title = "Theme", Description = "Accent " .. tostring(name), Lifetime = 2 })
		end,
	}, "Accent")
	themeSec:Colorpicker({
		Name = "Custom accent",
		Default = theme.accent,
		Callback = function(color)
			MacLib:SetAccent(color)
		end,
	})
	themeSec:Segmented({
		Name = "Animations",
		Options = { "Spring", "Smooth", "Off" },
		Default = 1,
		Callback = function(v)
			MacLib:SetAnimation(v)
			Window:Notify({ Title = "Animations", Description = tostring(v), Lifetime = 2 })
		end,
	}, "Animations")
	themeSec:Segmented({
		Name = "Window style",
		Options = { "Liquid Glass", "Black", "White" },
		Default = 1,
		Callback = function(v)
			MacLib:SetMode(v == "Liquid Glass" and "Glass" or v)
		end,
	}, "WindowStyle")
	themeSec:Slider({
		Name = "Interface scale",
		Default = 100,
		Minimum = 80,
		Maximum = 130,
		DisplayMethod = "Value",
		Precision = 0,
		Callback = function(v)
			Window:SetScale(v / 100)
		end,
	}, "Scale")

	local winSec = look:Section({ Side = "Right" })
	winSec:Header({ Name = "Window", Icon = "image" })
	winSec:Keybind({
		Name = "Menu key",
		Default = Enum.KeyCode.RightControl,
		onBinded = function(key)
			Window:SetKeybind(key)
		end,
	})
	winSec:Toggle({
		Name = "Show my name",
		Default = true,
		Callback = function(v)
			Window:SetUserInfoState(v)
		end,
	}, "ShowName")
	winSec:Button({
		Name = "Zoom window",
		Callback = function()
			Window:SetSize(UDim2.new(1, -48, 1, -48))
		end,
	})
	winSec:Button({
		Name = "Reset size",
		Callback = function()
			Window:SetSize(UDim2.fromOffset(880, 580))
		end,
	})
	winSec:Button({
		Name = "Shake window",
		Callback = function()
			Window:Shake()
		end,
	})
	winSec:Button({
		Name = "Pulse border",
		Callback = function()
			Window:Highlight()
		end,
	})
	winSec:Label({ Text = "The window also opens and closes through the island." })

	local islandSec = look:Section({ Side = "Right" })
	islandSec:Header({ Name = "Dynamic Island", Icon = "bell" })
	islandSec:Toggle({
		Name = "Clock",
		Default = true,
		Callback = function(v)
			MacLib:SetIsland({ Clock = v })
		end,
	}, "IslandClock")
	islandSec:Toggle({
		Name = "Ping",
		Default = false,
		Callback = function(v)
			MacLib:SetIsland({ Ping = v })
		end,
	}, "IslandPing")
	islandSec:Toggle({
		Name = "FPS",
		Default = false,
		Callback = function(v)
			MacLib:SetIsland({ FPS = v })
		end,
	}, "IslandFPS")
	islandSec:Toggle({
		Name = "Show username",
		Default = false,
		Callback = function(v)
			MacLib:SetIsland({ Username = v })
		end,
	}, "IslandUser")
	islandSec:Input({
		Name = "Custom label",
		Placeholder = "Maclib",
		Callback = function(text)
			MacLib:SetIsland({ Label = text })
		end,
	}, "IslandLabel")
	islandSec:Label({ Text = "Click the island to show or hide the window." })

	settings:InsertConfigSection("Left")
	local about = settings:Section({ Side = "Right" })
	about:Header({ Name = "About", Icon = "user" })
	about:Label({ Text = "Maclib 2 - " .. tostring(MacLib.Version) })
	about:SubLabel({ Text = "Same API as Maclib, redrawn in glass." })
	about:Divider()
	about:Label({ Text = "Terminal button - command palette" })
	about:Label({ Text = "Ctrl+F - search settings" })
	about:Label({ Text = "Right Control - show or hide" })
	about:Divider()
	about:Button({
		Name = "Unload the window",
		Callback = function()
			Window:Unload()
		end,
	})

	self:SetFolder("Maclib")
	home:Select()
	return Window
end

function MacLib:IconDemo()
	local Window = self:Window({
		Title = "Icons",
		Subtitle = tostring(#self.IconNames) .. " icons",
		Size = UDim2.fromOffset(620, 520),
		Keybind = Enum.KeyCode.RightShift,
		AcrylicBlur = true,
	})
	local tab = Window:TabGroup():Tab({ Name = "Gallery", Icon = "image" })
	local sec = tab:Section({ Side = "Left" })
	sec:Header({ Name = "Every icon", Icon = "sun" })
	local names = self.IconNames
	local rows = math.ceil(#names / 2)
	local grid = new("Frame", {
		Size = UDim2.new(1, 0, 0, rows * 60),
		BackgroundTransparency = 1,
		LayoutOrder = 999,
		Parent = sec._card,
	})
	for i, name in ipairs(names) do
		local col = (i - 1) % 2
		local row = math.floor((i - 1) / 2)
		local cell = new("Frame", {
			Position = UDim2.new(col * 0.5, col * 4, 0, row * 60),
			Size = UDim2.new(0.5, -6, 0, 56),
			BackgroundColor3 = C.elevated,
			BackgroundTransparency = 0.6,
			Parent = grid,
		})
		corner(cell, 10)
		local ic = MacLib:Icon(name, cell, 26, C.text)
		ic.Position = UDim2.fromOffset(12, 15)
		local nameLabel = label(cell, name, 13, C.textDim, FONT)
		nameLabel.Position = UDim2.fromOffset(48, 0)
		nameLabel.Size = UDim2.new(1, -56, 1, 0)
	end
	local right = tab:Section({ Side = "Right" })
	right:Header({ Name = "Usage", Icon = "code" })
	right:Paragraph({
		Header = "Draw your own",
		Body = "MacLib:Icon(name, parent, size, color) returns a container frame you can position and tint like any label.",
	})
	right:Label({ Text = "Tabs, headers and buttons take Icon = \"name\"." })
	right:SubLabel({ Text = "Icons are drawn from primitives, so they stay crisp at any size." })
	tab:Select()
	return Window
end

return MacLib
