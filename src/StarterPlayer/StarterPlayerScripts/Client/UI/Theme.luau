--!strict
-- Shared look for all Deep Mine UI, plus small constructors so every screen
-- is built the same way.

local Theme = {}

Theme.Colors = {
	Panel = Color3.fromRGB(24, 21, 19),
	PanelLight = Color3.fromRGB(42, 37, 33),
	Stroke = Color3.fromRGB(78, 66, 54),
	Text = Color3.fromRGB(244, 236, 224),
	TextDim = Color3.fromRGB(176, 164, 148),
	Accent = Color3.fromRGB(242, 166, 58), -- lantern amber
	AccentDark = Color3.fromRGB(176, 108, 30),
	Good = Color3.fromRGB(118, 204, 112),
	Bad = Color3.fromRGB(226, 84, 72),
	Cash = Color3.fromRGB(255, 208, 92),
}

Theme.Font = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)
Theme.FontMedium = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Medium)
Theme.FontHeavy = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.ExtraBold)

function Theme.Corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = parent
	return c
end

function Theme.Stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.Colors.Stroke
	s.Thickness = thickness or 1.5
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function Theme.Padding(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = parent
	return p
end

function Theme.Panel(props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Theme.Colors.Panel
	f.BackgroundTransparency = 0.12
	f.BorderSizePixel = 0
	for k, v in props do
		(f :: any)[k] = v
	end
	Theme.Corner(f)
	Theme.Stroke(f, nil, 1.5, 0.2)
	return f
end

function Theme.Label(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.FontFace = Theme.Font
	l.TextColor3 = Theme.Colors.Text
	l.TextScaled = false
	l.TextSize = 18
	l.TextXAlignment = Enum.TextXAlignment.Left
	for k, v in props do
		(l :: any)[k] = v
	end
	return l
end

function Theme.Button(props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = true
	b.BackgroundColor3 = Theme.Colors.Accent
	b.BorderSizePixel = 0
	b.FontFace = Theme.FontHeavy
	b.TextColor3 = Color3.fromRGB(30, 20, 10)
	b.TextSize = 20
	for k, v in props do
		(b :: any)[k] = v
	end
	Theme.Corner(b, 8)
	return b
end

-- One ScreenGui per feature, all scaled together for phones/tablets/TV.
function Theme.Screen(name: string, order: number): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = order
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	local function update()
		local camera = workspace.CurrentCamera
		local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
		scale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 720) * 1.1, 0.62, 1.3)
	end
	update()
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
	return gui
end

return Theme
