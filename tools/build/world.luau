-- World: cleanup, lighting, surface ground and the mountain over Mine 1.
----------------------------------------------------------------------------
-- cleanup
----------------------------------------------------------------------------

for _, name in { "Baseplate", "SpawnLocation", "Camp", "Mines" } do
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
T:Clear()
minesFolder = folder("Mines", workspace)

----------------------------------------------------------------------------
-- lighting / player settings
----------------------------------------------------------------------------

workspace.StreamingEnabled = false
-- Mines go far below the default -500 kill plane (Mine 3 is around y = -530).
workspace.FallenPartsDestroyHeight = -5000
T.WaterColor = Color3.fromRGB(40, 110, 160)
T.WaterTransparency = 0.45
T.WaterReflectance = 0.6
T.WaterWaveSize = 0.05
T.WaterWaveSpeed = 4
pcall(function() Lighting.Technology = Enum.Technology.Future end) -- not writable from plugins; set in Properties
Lighting.ClockTime = 16.8
Lighting.Brightness = 2.4
Lighting.Ambient = Color3.fromRGB(16, 14, 13)
Lighting.OutdoorAmbient = Color3.fromRGB(118, 110, 104)
Lighting.EnvironmentDiffuseScale = 0.25
Lighting.EnvironmentSpecularScale = 0.4
Lighting.GlobalShadows = true
Lighting.ShadowSoftness = 0.25
Lighting.ExposureCompensation = 0.1
for _, c in Lighting:GetChildren() do
	if c:IsA("PostEffect") or c:IsA("Atmosphere") or c:IsA("Sky") then
		c:Destroy()
	end
end
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.32
atmosphere.Offset = 0.2
atmosphere.Color = Color3.fromRGB(214, 190, 160)
atmosphere.Decay = Color3.fromRGB(110, 90, 76)
atmosphere.Glare = 0.2
atmosphere.Haze = 1.6
atmosphere.Parent = Lighting
local cc = Instance.new("ColorCorrectionEffect")
cc.Contrast = 0.08
cc.Saturation = 0.05
cc.TintColor = Color3.fromRGB(255, 246, 236)
cc.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.6
bloom.Size = 30
bloom.Threshold = 1.6
bloom.Parent = Lighting

StarterPlayer.CameraMaxZoomDistance = 32
StarterPlayer.CameraMinZoomDistance = 0.5

----------------------------------------------------------------------------
-- terrain: ground, mountain, mine
----------------------------------------------------------------------------

-- Bedrock mass under everything.
T:FillBlock(CFrame.new(0, -80, -130), Vector3.new(520, 160, 640), Enum.Material.Rock)
-- Camp ground (top at y = 0).
T:FillBlock(CFrame.new(0, -6, 80), Vector3.new(520, 12, 260), Enum.Material.Ground)
T:FillBlock(CFrame.new(0, -2, 80), Vector3.new(520, 4, 260), Enum.Material.Grass)

-- Mountain over the mine.
local hills = {
	{ Vector3.new(0, -5, -100), 60 },
	{ Vector3.new(-72, -12, -118), 58 },
	{ Vector3.new(74, -12, -124), 58 },
	{ Vector3.new(0, -10, -190), 70 },
	{ Vector3.new(-70, -16, -255), 66 },
	{ Vector3.new(66, -16, -285), 66 },
	{ Vector3.new(0, -14, -345), 72 },
	{ Vector3.new(-140, -22, -70), 58 },
	{ Vector3.new(142, -22, -80), 58 },
	{ Vector3.new(-190, -26, -10), 50 },
	{ Vector3.new(190, -26, 0), 50 },
}
for _, h in hills do
	T:FillBall(h[1], h[2], Enum.Material.Rock)
end
-- Grass on the upper slopes, rock cliffs lower down.
T:ReplaceMaterial(Region3.new(Vector3.new(-256, 14, -448), Vector3.new(256, 72, 64)):ExpandToGrid(4), 4,
	Enum.Material.Rock, Enum.Material.Grass)
T:ReplaceMaterial(Region3.new(Vector3.new(-256, 4, -448), Vector3.new(256, 14, 64)):ExpandToGrid(4), 4,
	Enum.Material.Rock, Enum.Material.Ground)
