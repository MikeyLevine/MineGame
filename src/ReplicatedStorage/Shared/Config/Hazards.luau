--!strict
-- Environmental hazards. Hazard volumes in the map are parts tagged "Hazard"
-- with attributes Type (key below), Level and DamagePerSecond. A player whose
-- suit protection for that Type is below Level takes damage while inside.

export type Hazard = {
	DisplayName: string,
	Color: Color3,
	Warning: string,
}

return {
	Heat = {
		DisplayName = "Scorching heat",
		Color = Color3.fromRGB(255, 110, 40),
		Warning = "It's scorching in here! You need heat protection.",
	},
	-- Lava itself: no suit protects against it (volumes use a very high Level).
	Lava = {
		DisplayName = "Lava",
		Color = Color3.fromRGB(255, 60, 20),
		Warning = "You're standing in lava! Get out!",
	},
	Void = {
		DisplayName = "Corrosive air",
		Color = Color3.fromRGB(170, 70, 255),
		Warning = "The air is eating through you! You need a Void Suit.",
	},
	Acid = {
		DisplayName = "Acid",
		Color = Color3.fromRGB(110, 255, 90),
		Warning = "Acid! Get out!",
	},
} :: { [string]: Hazard }
