--[[
	TreasureModels
	Builds a small 3D model for any treasure out of simple parts, based on its Shape.
	Used for: the dig-up animation, inventory/index icons (ViewportFrames) and shop displays.

	Update 16 detail pass:
	  * real materials by default (coins, keys, crowns... are metal; bottles and orbs glass;
	    skulls and teeth bone-like limestone) unless the treasure sets its own Material
	  * proper shapes: brilliant-cut gems (faceted crown + pavilion) or raw nuggets, reeded coins,
	    pearls with a sheen, compasses with a bezel and a two-tone needle, a message in the bottle,
	    watch bezels and hour marks, a chest with planks, hinges and handles, a skull with teeth...
	  * Common/Uncommon finds still have a little beach grit stuck to them; Rare and up are
	    polished (metal gets a shine), and the rarity frames (Embellish) set the higher tiers apart

	TreasureModels.Build("PirateDoubloon")                    -> Model (about 2 studs big)
	TreasureModels.Build("PirateDoubloon", { Silhouette = true }) -> dark "???" version for the Index

	To add a new shape: add a function to Builders below, then use its name as a treasure's Shape.
]]

local Treasures = require(script.Parent.Config.Treasures)
local Rarities = require(script.Parent.Config.Rarities)

local TreasureModels = {}

local DEG = math.rad
local WHITE_DIAL = Color3.fromRGB(240, 236, 224)
local BLACK = Color3.fromRGB(25, 25, 30)

local function darker(color: Color3, factor: number): Color3
	return Color3.new(color.R * factor, color.G * factor, color.B * factor)
end

type Ctx = {
	model: Model,
	color: Color3,
	accent: Color3,
	material: Enum.Material,
	scale: number,
	silhouette: boolean,
}

local function addPart(ctx: Ctx, className: string, size: Vector3, cf: CFrame, props: { [string]: any }?): BasePart
	local part = Instance.new(className) :: BasePart
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = size * ctx.scale
	part.CFrame = CFrame.new(cf.Position * ctx.scale) * cf.Rotation
	part.Color = ctx.color
	part.Material = ctx.material
	if props then
		for key, value in props do
			(part :: any)[key] = value
		end
	end
	if ctx.silhouette then
		part.Color = Color3.fromRGB(28, 30, 38)
		part.Material = Enum.Material.SmoothPlastic
		part.Transparency = 0
		part.Reflectance = 0
	end
	part.Parent = ctx.model
	return part
end

local function block(ctx: Ctx, size: Vector3, cf: CFrame, props: { [string]: any }?)
	return addPart(ctx, "Part", size, cf, props)
end

local function ball(ctx: Ctx, diameter: number, cf: CFrame, props: { [string]: any }?)
	local part = addPart(ctx, "Part", Vector3.new(diameter, diameter, diameter), cf, props) :: Part
	part.Shape = Enum.PartType.Ball
	return part
end

-- Cylinder whose round faces point along X (Roblox default)
local function cylX(ctx: Ctx, length: number, diameter: number, cf: CFrame, props: { [string]: any }?)
	local part = addPart(ctx, "Part", Vector3.new(length, diameter, diameter), cf, props) :: Part
	part.Shape = Enum.PartType.Cylinder
	return part
end

-- Upright cylinder (round faces up/down)
local function cylY(ctx: Ctx, length: number, diameter: number, cf: CFrame, props: { [string]: any }?)
	return cylX(ctx, length, diameter, cf * CFrame.Angles(0, 0, DEG(90)), props)
end

-- Cylinder facing the camera (round faces along Z), like a coin standing up
local function cylZ(ctx: Ctx, length: number, diameter: number, cf: CFrame, props: { [string]: any }?)
	return cylX(ctx, length, diameter, cf * CFrame.Angles(0, DEG(90), 0), props)
end

local function wedge(ctx: Ctx, size: Vector3, cf: CFrame, props: { [string]: any }?)
	return addPart(ctx, "WedgePart", size, cf, props)
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

-- Smooth ellipsoid (block part wearing a sphere mesh): the main tool for rounded shapes
local function ellipsoid(ctx: Ctx, size: Vector3, cf: CFrame, props: { [string]: any }?)
	local part = addPart(ctx, "Part", size, cf, props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- Smooth ring (torus) from short cylinder segments, lying in cf's XY plane
local function torus(ctx: Ctx, radius: number, thickness: number, cf: CFrame, segments: number?, props: { [string]: any }?, colors: { Color3 }?)
	local n = segments or 16
	local length = 2 * math.pi * radius / n * 1.12
	for i = 0, n - 1 do
		local a = (i + 0.5) / n * math.pi * 2
		local segmentProps = props
		if colors then
			segmentProps = table.clone(props or {})
			segmentProps.Color = colors[i % #colors + 1]
		end
		cylX(ctx, length, thickness, cf * CFrame.new(math.cos(a) * radius, math.sin(a) * radius, 0) * CFrame.Angles(0, 0, a + math.pi / 2), segmentProps)
	end
end

-- Faceted gem: two crossed rotated blocks read as many facets, with a glowing core
local function facetGem(ctx: Ctx, size: number, cf: CFrame, color: Color3, props: { [string]: any }?)
	local base = { Color = color, Material = Enum.Material.Glass, Reflectance = 0.3, Transparency = 0.08 }
	if props then
		for key, value in props do
			base[key] = value
		end
	end
	block(ctx, Vector3.new(size, size, size), cf * CFrame.Angles(DEG(45), DEG(30), DEG(45)), base)
	block(ctx, Vector3.new(size * 0.82, size * 0.82, size * 0.82), cf * CFrame.Angles(DEG(10), DEG(75), DEG(-20)), base)
	ball(ctx, size * 0.5, cf, { Color = color:Lerp(Color3.new(1, 1, 1), 0.5), Material = Enum.Material.Neon, Transparency = 0.3 })
end

-- Triangle facets around an axis (a cone): two mirrored wedges per facet, so it really is faceted.
-- apex/base are model-space points (before scale); `segments` facets around.
local function facetCone(ctx: Ctx, apex: Vector3, base: Vector3, radius: number, segments: number, spin: number, props: { [string]: any }?)
	local axis = (apex - base).Unit
	local helper = if math.abs(axis.Y) < 0.9 then Vector3.new(0, 1, 0) else Vector3.new(1, 0, 0)
	local e1 = axis:Cross(helper).Unit
	local e2 = axis:Cross(e1).Unit
	for i = 0, segments - 1 do
		local a0 = (i / segments) * math.pi * 2 + spin
		local a1 = ((i + 1) / segments) * math.pi * 2 + spin
		local b1 = base + (e1 * math.cos(a0) + e2 * math.sin(a0)) * radius
		local b2 = base + (e1 * math.cos(a1) + e2 * math.sin(a1)) * radius
		local mid = (b1 + b2) / 2
		local u = (b2 - b1).Unit
		local width = (b2 - b1).Magnitude
		local v = (apex - mid)
		local height = v.Magnitude
		v = v.Unit
		for _, half in { 1, -1 } do
			local zAxis = -u * half
			local center = mid + u * (width / 4) * half + v * (height / 2)
			local cf = CFrame.fromMatrix(center, v:Cross(zAxis), v, zAxis)
			wedge(ctx, Vector3.new(0.03, height, width / 2), cf, props)
		end
	end
end

local Builders: { [string]: (Ctx) -> () } = {}

function Builders.Coin(ctx)
	cylZ(ctx, 0.2, 1.6, at(0, 0, 0))
	torus(ctx, 0.76, 0.14, at(0, 0, 0), 18, { Color = darker(ctx.color, 0.85) }) -- raised rim
	cylZ(ctx, 0.24, 1.1, at(0, 0, 0), { Color = ctx.accent })
	-- embossed profile: a head with a little laurel bump, facing left
	ellipsoid(ctx, Vector3.new(0.42, 0.52, 0.18), at(0.04, 0.04, -0.12), { Color = ctx.color })
	ellipsoid(ctx, Vector3.new(0.2, 0.14, 0.12), at(-0.18, -0.02, -0.14), { Color = ctx.color }) -- nose/chin
	ellipsoid(ctx, Vector3.new(0.36, 0.14, 0.12), at(0.02, -0.3, -0.13), { Color = ctx.color }) -- neck
	-- lettering dots around the face
	for i = 0, 9 do
		local a = DEG(i * 28 + 20)
		block(ctx, Vector3.new(0.06, 0.1, 0.05), at(math.cos(a) * 0.46, math.sin(a) * 0.46, -0.13) * CFrame.Angles(0, 0, a), { Color = darker(ctx.color, 0.8) })
	end
	-- star on the reverse
	for i = 0, 4 do
		local a = DEG(i * 72 + 90)
		wedge(ctx, Vector3.new(0.05, 0.22, 0.1), at(math.cos(a) * 0.1, math.sin(a) * 0.1, 0.13) * CFrame.Angles(0, 0, a - DEG(90)), { Color = ctx.color })
	end
	-- reeded edge
	for i = 0, 15 do
		local a = (i / 16) * math.pi * 2
		block(ctx, Vector3.new(0.05, 0.08, 0.22), at(math.cos(a) * 0.81, math.sin(a) * 0.81, 0) * CFrame.Angles(0, 0, a), { Color = darker(ctx.color, 0.9) })
	end
end

function Builders.CoinStack(ctx)
	for i = 0, 4 do
		local offset = (i % 2 == 0) and 0.06 or -0.06
		cylY(ctx, 0.22, 1.4, at(offset, -0.5 + i * 0.24, offset * 0.5), { Color = if i % 2 == 0 then ctx.color else ctx.accent })
	end
	cylZ(ctx, 0.2, 1.3, at(0.6, 0.45, -0.2) * CFrame.Angles(0, 0, DEG(-25)))
end

function Builders.Ring(ctx)
	torus(ctx, 0.6, 0.24, at(0, -0.15, 0), 20)
	torus(ctx, 0.6, 0.1, at(0, -0.15, -0.09), 20, { Color = darker(ctx.color, 0.8) }) -- engraved inner line
	-- claw setting + stone
	for _, x in { -0.16, 0.16 } do
		ball(ctx, 0.12, at(x, 0.5, -0.12))
		ball(ctx, 0.12, at(x, 0.5, 0.12))
	end
	cylY(ctx, 0.16, 0.36, at(0, 0.46, 0))
	facetGem(ctx, 0.38, at(0, 0.7, 0), ctx.accent)
end

function Builders.Gem(ctx)
	if ctx.material == Enum.Material.Metal or ctx.material == Enum.Material.CorrodedMetal then
		-- raw metal: a lumpy nugget, not a cut stone
		local seed = Random.new(7)
		ellipsoid(ctx, Vector3.new(1.2, 0.8, 0.9), at(0, 0, 0) * CFrame.Angles(0, DEG(20), DEG(10)), { Reflectance = 0.15 })
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			ellipsoid(ctx, Vector3.new(0.5 + seed:NextNumber() * 0.3, 0.4 + seed:NextNumber() * 0.25, 0.45 + seed:NextNumber() * 0.25),
				at(math.cos(a) * 0.45, seed:NextNumber(-0.2, 0.25), math.sin(a) * 0.35) * CFrame.Angles(seed:NextNumber(), seed:NextNumber(), seed:NextNumber()),
				{ Reflectance = 0.15, Color = ctx.color:Lerp(ctx.accent, seed:NextNumber() * 0.4) })
		end
		return
	end
	local mat = if ctx.material == Enum.Material.SmoothPlastic then Enum.Material.Glass else ctx.material
	local glassy = mat == Enum.Material.Glass
	local stone = { Material = mat, Transparency = if glassy then 0.1 else 0, Reflectance = if glassy then 0.25 else 0.1 }
	-- brilliant cut: a faceted crown with a flat table on top, a girdle, and a deep pavilion
	local girdle = 0.62
	facetCone(ctx, Vector3.new(0, 0.62, 0), Vector3.new(0, 0.05, 0), girdle, 8, 0, stone) -- crown
	cylY(ctx, 0.05, girdle * 0.95, at(0, 0.36, 0), { Color = ctx.color:Lerp(Color3.new(1, 1, 1), 0.25), Material = mat, Transparency = stone.Transparency, Reflectance = 0.35 }) -- table
	cylY(ctx, 0.1, girdle * 2.02, at(0, 0, 0), stone) -- girdle
	facetCone(ctx, Vector3.new(0, -0.95, 0), Vector3.new(0, -0.05, 0), girdle, 8, math.pi / 8, stone) -- pavilion
	ball(ctx, 0.45, at(0, -0.12, 0), { Color = ctx.color:Lerp(Color3.new(1, 1, 1), 0.5), Material = Enum.Material.Neon, Transparency = 0.35 }) -- fire inside
	-- tiny satellite crystals
	for i = 0, 2 do
		local a = DEG(i * 120 + 20)
		block(ctx, Vector3.new(0.22, 0.32, 0.22), at(math.cos(a) * 0.72, -0.42, math.sin(a) * 0.72) * CFrame.Angles(DEG(20), a, DEG(15)),
			{ Color = ctx.accent, Material = Enum.Material.Glass, Transparency = 0.15, Reflectance = 0.2 })
	end
end

function Builders.Bar(ctx)
	-- bevelled ingot: core + sloped sides and ends
	block(ctx, Vector3.new(1.4, 0.5, 0.6), at(0, -0.05, 0), { Reflectance = 0.12 })
	wedge(ctx, Vector3.new(1.4, 0.5, 0.22), at(0, -0.05, -0.41), { Reflectance = 0.12 })
	wedge(ctx, Vector3.new(1.4, 0.5, 0.22), at(0, -0.05, 0.41) * CFrame.Angles(0, DEG(180), 0), { Reflectance = 0.12 })
	wedge(ctx, Vector3.new(0.6, 0.5, 0.22), at(-0.81, -0.05, 0) * CFrame.Angles(0, DEG(-90), 0), { Reflectance = 0.12 })
	wedge(ctx, Vector3.new(0.6, 0.5, 0.22), at(0.81, -0.05, 0) * CFrame.Angles(0, DEG(90), 0), { Reflectance = 0.12 })
	ellipsoid(ctx, Vector3.new(0.7, 0.08, 0.32), at(0, 0.22, 0), { Color = ctx.accent }) -- stamped seal
end

function Builders.Chest(ctx)
	block(ctx, Vector3.new(2, 1, 1.3), at(0, -0.3, 0), { Material = Enum.Material.Wood })
	cylX(ctx, 2.02, 1.34, at(0, 0.2, 0), { Color = darker(ctx.color, 0.85), Material = Enum.Material.Wood }) -- rounded barrel lid
	for _, x in { -0.68, 0.68 } do
		cylX(ctx, 0.16, 1.44, at(x, 0.2, 0), { Color = ctx.accent, Material = Enum.Material.Metal }) -- lid bands
		block(ctx, Vector3.new(0.16, 1.02, 1.36), at(x, -0.3, 0), { Color = ctx.accent, Material = Enum.Material.Metal })
	end
	for _, x in { -0.98, 0.98 } do
		for _, z in { -0.63, 0.63 } do
			ball(ctx, 0.2, at(x, -0.78, z), { Color = ctx.accent, Material = Enum.Material.Metal }) -- corner studs
		end
	end
	-- plank seams on the front and side handles
	for _, y in { -0.55, -0.2 } do
		block(ctx, Vector3.new(1.95, 0.04, 0.02), at(0, y, -0.66), { Color = darker(ctx.color, 0.6), Material = Enum.Material.Wood })
	end
	for _, x in { -1.05, 1.05 } do
		torus(ctx, 0.18, 0.06, at(x, -0.25, 0) * CFrame.Angles(0, DEG(90), 0), 10, { Color = ctx.accent, Material = Enum.Material.Metal })
	end
	for _, x in { -0.55, 0.55 } do
		cylX(ctx, 0.3, 0.12, at(x, 0.18, 0.68), { Color = ctx.accent, Material = Enum.Material.Metal }) -- hinges
	end
	cylZ(ctx, 0.12, 0.36, at(0, 0.1, -0.7), { Color = ctx.accent, Material = Enum.Material.Metal }) -- lock plate
	ellipsoid(ctx, Vector3.new(0.16, 0.22, 0.1), at(0, 0.08, -0.77), { Color = BLACK })
	for i, x in { -0.45, 0, 0.45 } do
		cylZ(ctx, 0.08, 0.32, at(x, 0.86, -0.2 + i * 0.1) * CFrame.Angles(DEG(70), 0, 0), { Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Metal })
	end
end

function Builders.Bottle(ctx)
	local clear = ctx.material == Enum.Material.Glass
	local glass = { Transparency = if clear then 0.45 else 0, Reflectance = 0.2 }
	cylY(ctx, 1.1, 0.78, at(0, -0.3, 0), glass)
	cylY(ctx, 0.08, 0.8, at(0, -0.84, 0), { Color = darker(ctx.color, 0.8), Transparency = if clear then 0.2 else 0 }) -- thick glass base
	ball(ctx, 0.78, at(0, 0.25, 0), glass)
	cylY(ctx, 0.5, 0.3, at(0, 0.62, 0), glass)
	cylY(ctx, 0.06, 0.36, at(0, 0.84, 0), glass) -- lip ring
	cylY(ctx, 0.24, 0.3, at(0, 0.97, 0), { Color = Color3.fromRGB(176, 130, 82), Material = Enum.Material.Wood }) -- cork
	if clear then
		-- the rolled-up message inside, tied with string, and a little sand in the bottom
		cylY(ctx, 0.8, 0.26, at(0.05, -0.28, 0) * CFrame.Angles(0, 0, DEG(8)), { Color = Color3.fromRGB(240, 226, 190), Material = Enum.Material.SmoothPlastic })
		cylY(ctx, 0.06, 0.29, at(0.05, -0.28, 0) * CFrame.Angles(0, 0, DEG(8)), { Color = Color3.fromRGB(170, 40, 40), Material = Enum.Material.Fabric })
		cylY(ctx, 0.1, 0.7, at(0, -0.74, 0), { Color = Color3.fromRGB(232, 206, 150), Material = Enum.Material.Sand })
	else
		block(ctx, Vector3.new(0.3, 0.55, 0.05), at(0, -0.25, -0.38), { Color = ctx.accent, Material = Enum.Material.SmoothPlastic }) -- label
	end
end

function Builders.Key(ctx)
	cylX(ctx, 1.45, 0.17, at(0.22, 0, 0))
	torus(ctx, 0.36, 0.14, at(-0.82, 0, 0), 14) -- bow
	ball(ctx, 0.24, at(-0.82, 0, 0), { Color = ctx.accent })
	cylX(ctx, 0.12, 0.26, at(-0.42, 0, 0), { Color = ctx.accent }) -- collar
	block(ctx, Vector3.new(0.14, 0.34, 0.12), at(0.84, -0.2, 0))
	block(ctx, Vector3.new(0.14, 0.24, 0.12), at(0.6, -0.15, 0))
	block(ctx, Vector3.new(0.08, 0.3, 0.12), at(0.72, -0.18, 0))
	ball(ctx, 0.16, at(0.95, 0, 0))
	-- an ornate cross inside the bow
	block(ctx, Vector3.new(0.5, 0.06, 0.08), at(-0.82, 0, 0), { Color = ctx.accent })
	block(ctx, Vector3.new(0.06, 0.5, 0.08), at(-0.82, 0, 0), { Color = ctx.accent })
end

function Builders.Crown(ctx)
	cylY(ctx, 0.5, 1.6, at(0, -0.35, 0))
	torus(ctx, 0.8, 0.14, at(0, -0.6, 0) * CFrame.Angles(DEG(90), 0, 0), 20, { Color = ctx.accent }) -- rim
	ellipsoid(ctx, Vector3.new(1.4, 0.9, 1.4), at(0, -0.05, 0), { Color = Color3.fromRGB(150, 30, 50), Material = Enum.Material.Fabric }) -- velvet cap
	for i = 0, 5 do
		local angle = DEG(i * 60)
		local x, z = math.sin(angle) * 0.72, math.cos(angle) * 0.72
		wedge(ctx, Vector3.new(0.3, 0.6, 0.16), at(x, 0.22, z) * CFrame.Angles(0, angle, 0))
		ball(ctx, 0.2, at(x * 1.02, 0.56, z * 1.02), { Color = ctx.accent, Material = Enum.Material.Glass })
	end
	ball(ctx, 0.26, at(0, 0.5, 0), { Color = ctx.color }) -- top orb
	facetGem(ctx, 0.3, at(0, -0.33, -0.82), ctx.accent)
end

function Builders.Skull(ctx)
	ball(ctx, 1.4, at(0, 0.15, 0))
	ellipsoid(ctx, Vector3.new(0.95, 0.5, 0.8), at(0, -0.52, -0.22)) -- jaw
	ellipsoid(ctx, Vector3.new(1.5, 0.35, 0.9), at(0, -0.15, -0.18)) -- cheekbones
	for _, x in { -0.28, 0.28 } do
		ball(ctx, 0.36, at(x, 0.12, -0.56), { Color = ctx.accent, Material = Enum.Material.Neon })
	end
	wedge(ctx, Vector3.new(0.16, 0.2, 0.12), at(0, -0.15, -0.66), { Color = BLACK })
	-- a row of teeth along the jaw
	for i = -3, 3 do
		block(ctx, Vector3.new(0.09, 0.14, 0.06), at(i * 0.1, -0.42, -0.6 + math.abs(i) * 0.03), { Color = Color3.fromRGB(245, 240, 220) })
	end
	-- cracks on the dome
	block(ctx, Vector3.new(0.03, 0.4, 0.03), at(0.2, 0.6, -0.42) * CFrame.Angles(DEG(35), 0, DEG(20)), { Color = darker(ctx.color, 0.55) })
end

function Builders.Orb(ctx)
	if ctx.material == Enum.Material.Metal or ctx.material == Enum.Material.CorrodedMetal then
		-- cast metal ball: a mould seam and a cast-in eyelet
		ball(ctx, 1.2, at(0, 0, 0), { Reflectance = 0.08 })
		torus(ctx, 0.6, 0.06, at(0, 0, 0) * CFrame.Angles(DEG(90), 0, 0), 20, { Color = darker(ctx.color, 0.8) })
		torus(ctx, 0.16, 0.08, at(0, 0.66, 0), 10, { Color = ctx.accent })
		ellipsoid(ctx, Vector3.new(0.3, 0.12, 0.3), at(0.2, -0.45, -0.3), { Color = darker(ctx.color, 0.7) }) -- a dent
		return
	end
	-- a pearl / gazing orb: glossy body, a soft iridescent band and a bright highlight
	ball(ctx, 1.25, at(0, 0, 0), { Reflectance = 0.3 })
	ball(ctx, 1.27, at(0, 0, 0), { Color = ctx.accent, Material = Enum.Material.Glass, Transparency = 0.75, Reflectance = 0.4 })
	torus(ctx, 0.52, 0.12, at(0, 0.08, 0) * CFrame.Angles(DEG(70), DEG(20), 0), 18, { Color = ctx.accent, Material = Enum.Material.Glass, Transparency = 0.55 })
	ellipsoid(ctx, Vector3.new(0.34, 0.22, 0.12), at(-0.28, 0.3, -0.5) * CFrame.Angles(DEG(-30), DEG(25), DEG(-30)), { Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = 0.35 })
end

function Builders.Shell(ctx)
	for i = -3, 3 do
		local color = if i % 2 == 0 then ctx.color else ctx.accent
		ellipsoid(ctx, Vector3.new(0.34, 1.35, 0.2), at(0, -0.6, 0) * CFrame.Angles(0, 0, DEG(i * 18)) * CFrame.new(0, 0.65, 0), { Color = color })
	end
	ellipsoid(ctx, Vector3.new(0.6, 0.4, 0.3), at(0, -0.62, 0), { Color = ctx.accent })
	-- the two "ears" at the hinge, and a rolled lip along the top edge
	for _, x in { -0.32, 0.32 } do
		wedge(ctx, Vector3.new(0.12, 0.3, 0.32), at(x, -0.62, 0) * CFrame.Angles(0, DEG(90 * (if x < 0 then 1 else -1)), 0), { Color = ctx.accent })
	end
	for i = -3, 3 do
		local a = DEG(i * 18)
		ball(ctx, 0.2, at(0, -0.6, 0) * CFrame.Angles(0, 0, a) * CFrame.new(0, 1.3, 0), { Color = if i % 2 == 0 then ctx.color else ctx.accent })
	end
	ball(ctx, 0.16, at(0.1, 0.1, -0.12), { Color = Color3.fromRGB(250, 245, 255), Material = Enum.Material.Glass, Reflectance = 0.3 }) -- tiny pearl
end

function Builders.Compass(ctx)
	cylZ(ctx, 0.24, 1.45, at(0, 0, 0))
	torus(ctx, 0.68, 0.12, at(0, 0, -0.1), 20, { Color = darker(ctx.color, 0.85) }) -- bezel
	cylZ(ctx, 0.26, 1.15, at(0, 0, -0.01), { Color = WHITE_DIAL, Material = Enum.Material.SmoothPlastic })
	-- N / E / S / W ticks, N in red
	for i = 0, 3 do
		local a = DEG(i * 90 + 90)
		block(ctx, Vector3.new(0.06, 0.16, 0.03), at(math.cos(a) * 0.46, math.sin(a) * 0.46, -0.15) * CFrame.Angles(0, 0, a - DEG(90)),
			{ Color = if i == 0 then Color3.fromRGB(200, 40, 40) else BLACK, Material = Enum.Material.SmoothPlastic })
	end
	-- two-tone needle (red north, white south) on a brass pivot
	local tilt = CFrame.Angles(0, 0, DEG(25))
	wedge(ctx, Vector3.new(0.03, 0.4, 0.08), at(0, 0, -0.16) * tilt * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, DEG(90), 0), { Color = Color3.fromRGB(210, 40, 40), Material = Enum.Material.SmoothPlastic })
	wedge(ctx, Vector3.new(0.03, 0.4, 0.08), at(0, 0, -0.16) * tilt * CFrame.Angles(0, 0, DEG(180)) * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, DEG(90), 0), { Color = Color3.fromRGB(235, 235, 235), Material = Enum.Material.SmoothPlastic })
	cylZ(ctx, 0.06, 0.1, at(0, 0, -0.18), { Color = ctx.accent, Material = Enum.Material.Metal })
	cylZ(ctx, 0.04, 1.1, at(0, 0, -0.2), { Color = Color3.fromRGB(220, 240, 255), Material = Enum.Material.Glass, Transparency = 0.7, Reflectance = 0.3 }) -- glass cover
	cylX(ctx, 0.12, 0.34, at(0, 0.8, 0))
	torus(ctx, 0.14, 0.06, at(0, 0.98, 0), 10, { Color = darker(ctx.color, 0.85) }) -- hanging ring
end

function Builders.Statue(ctx)
	cylY(ctx, 0.3, 1.1, at(0, -0.85, 0), { Color = darker(ctx.color, 0.8) }) -- plinth
	cylY(ctx, 1.0, 0.7, at(0, -0.25, 0)) -- robe
	ellipsoid(ctx, Vector3.new(0.95, 0.4, 0.6), at(0, 0.2, 0)) -- shoulders
	ellipsoid(ctx, Vector3.new(0.7, 0.85, 0.7), at(0, 0.62, 0)) -- head
	for _, x in { -0.16, 0.16 } do
		ball(ctx, 0.14, at(x, 0.68, -0.32), { Color = ctx.accent, Material = Enum.Material.Neon })
	end
	torus(ctx, 0.36, 0.08, at(0, 0.98, 0) * CFrame.Angles(DEG(90), 0, 0), 12, { Color = ctx.accent }) -- laurel band
end

function Builders.Trident(ctx)
	cylY(ctx, 2.6, 0.15, at(0, -0.35, 0))
	block(ctx, Vector3.new(0.95, 0.13, 0.13), at(0, 0.98, 0))
	for _, x in { -0.42, 0, 0.42 } do
		local height = if x == 0 then 0.75 else 0.55
		block(ctx, Vector3.new(0.11, height, 0.11), at(x, 1.05 + height / 2, 0))
		ball(ctx, 0.2, at(x, 1.08 + height, 0), { Color = ctx.accent, Material = Enum.Material.Neon })
	end
end

function Builders.Scroll(ctx)
	block(ctx, Vector3.new(1.5, 0.75, 0.05), at(0, -0.15, 0), { Material = Enum.Material.SmoothPlastic })
	for _, y in { 0.25, -0.55 } do
		cylX(ctx, 1.75, 0.42, at(0, y, 0), { Color = darker(ctx.color, 0.85) })
		cylX(ctx, 0.12, 0.5, at(-0.9, y, 0), { Color = ctx.accent })
		cylX(ctx, 0.12, 0.5, at(0.9, y, 0), { Color = ctx.accent })
	end
	block(ctx, Vector3.new(0.16, 0.5, 0.5), at(0, 0.25, 0), { Color = ctx.accent })
	block(ctx, Vector3.new(0.12, 0.12, 0.02), at(0.25, -0.1, -0.04), { Color = Color3.fromRGB(200, 30, 30) })
end

function Builders.Goblet(ctx)
	cylY(ctx, 0.72, 0.95, at(0, 0.45, 0))
	cylY(ctx, 0.08, 1.05, at(0, 0.83, 0), { Color = ctx.accent })
	cylY(ctx, 0.62, 0.2, at(0, -0.2, 0))
	ball(ctx, 0.32, at(0, -0.12, 0)) -- knop on the stem
	ellipsoid(ctx, Vector3.new(0.9, 0.3, 0.9), at(0, 0.1, 0)) -- rounded bowl bottom
	torus(ctx, 0.43, 0.08, at(0, -0.6, 0) * CFrame.Angles(DEG(90), 0, 0), 18, { Color = ctx.accent })
	cylY(ctx, 0.14, 0.85, at(0, -0.56, 0))
	for _, x in { -0.25, 0.25 } do
		ball(ctx, 0.2, at(x, 0.45, -0.46), { Color = ctx.accent, Material = Enum.Material.Glass })
	end
end

function Builders.Anchor(ctx)
	cylY(ctx, 2, 0.22, at(0, 0, 0)) -- shank
	cylX(ctx, 1.15, 0.18, at(0, 0.75, 0)) -- stock
	for _, x in { -0.62, 0.62 } do
		ball(ctx, 0.24, at(x, 0.75, 0))
	end
	torus(ctx, 0.26, 0.1, at(0, 1.25, 0), 12, { Color = ctx.accent }) -- shackle ring
	-- a short length of chain still attached
	for i = 1, 3 do
		torus(ctx, 0.16, 0.06, at(0.12 * i, 1.45 + i * 0.22, 0) * CFrame.Angles(0, if i % 2 == 0 then DEG(90) else 0, DEG(20)), 10, { Color = darker(ctx.color, 0.8) })
	end
	-- curved arms (half circle) + flukes
	for i = 0, 6 do
		local a = DEG(180 + i * 30)
		local next = DEG(180 + (i + 1) * 30)
		local p1 = Vector3.new(math.cos(a) * 0.75, math.sin(a) * 0.55 - 0.55, 0)
		local p2 = Vector3.new(math.cos(next) * 0.75, math.sin(next) * 0.55 - 0.55, 0)
		if i < 6 then
			cylX(ctx, (p2 - p1).Magnitude + 0.06, 0.2, CFrame.lookAt((p1 + p2) / 2, p2) * CFrame.Angles(0, DEG(90), 0))
		end
	end
	for _, side in { -1, 1 } do
		wedge(ctx, Vector3.new(0.2, 0.42, 0.3), at(side * 0.8, -0.45, 0) * CFrame.Angles(0, DEG(90 * side), 0), { Color = ctx.accent })
	end
end

function Builders.Sword(ctx)
	block(ctx, Vector3.new(0.1, 1.9, 0.34), at(0, 0.45, 0), { Reflectance = 0.15 })
	block(ctx, Vector3.new(0.14, 1.7, 0.06), at(0, 0.38, 0), { Color = darker(ctx.color, 0.85), Reflectance = 0.2 }) -- fuller ridge
	wedge(ctx, Vector3.new(0.1, 0.35, 0.34), at(0, 1.57, 0))
	cylX(ctx, 0.95, 0.16, at(0, -0.56, 0), { Color = ctx.accent }) -- guard
	for _, x in { -0.5, 0.5 } do
		ball(ctx, 0.22, at(x, -0.56, 0), { Color = ctx.accent })
	end
	cylY(ctx, 0.55, 0.2, at(0, -0.9, 0), { Color = darker(ctx.accent, 0.7) })
	ball(ctx, 0.3, at(0, -1.22, 0), { Color = ctx.accent })
end

function Builders.Can(ctx)
	local tilt = CFrame.Angles(0, 0, DEG(12))
	cylY(ctx, 1.15, 0.72, tilt * at(0, 0, 0))
	cylY(ctx, 0.07, 0.74, tilt * at(0, 0.6, 0), { Color = ctx.accent })
	cylY(ctx, 0.07, 0.74, tilt * at(0, -0.6, 0), { Color = ctx.accent })
	block(ctx, Vector3.new(0.5, 0.3, 0.05), tilt * at(0, 0.05, -0.36), { Color = ctx.accent })
	torus(ctx, 0.1, 0.04, tilt * at(0.12, 0.65, 0) * CFrame.Angles(DEG(90), 0, 0), 8, { Color = Color3.fromRGB(200, 200, 205), Material = Enum.Material.Metal }) -- pull tab
	block(ctx, Vector3.new(0.03, 1.1, 0.03), tilt * at(0.36, 0, 0), { Color = darker(ctx.color, 0.7) }) -- seam
	ellipsoid(ctx, Vector3.new(0.3, 0.35, 0.15), tilt * at(-0.25, -0.15, -0.3), { Color = darker(ctx.color, 0.8) }) -- a dent
end

function Builders.Watch(ctx)
	-- strap with stitched holes, lugs, a case with a bezel, hour marks and hands
	block(ctx, Vector3.new(0.6, 1.9, 0.1), at(0, 0, 0.08), { Color = ctx.accent, Material = Enum.Material.Fabric })
	for i = 1, 3 do
		cylZ(ctx, 0.12, 0.07, at(0, -0.55 - i * 0.12, 0.02), { Color = BLACK })
	end
	block(ctx, Vector3.new(0.22, 0.1, 0.12), at(0, -0.6, 0.0), { Color = Color3.fromRGB(200, 200, 205), Material = Enum.Material.Metal }) -- buckle
	for _, y in { -0.52, 0.52 } do
		for _, x in { -0.22, 0.22 } do
			block(ctx, Vector3.new(0.1, 0.2, 0.14), at(x, y, 0.02)) -- lugs
		end
	end
	cylZ(ctx, 0.24, 1.12, at(0, 0, 0))
	torus(ctx, 0.5, 0.1, at(0, 0, -0.12), 18, { Color = darker(ctx.color, 0.85) }) -- bezel
	cylZ(ctx, 0.26, 0.85, at(0, 0, -0.01), { Color = WHITE_DIAL, Material = Enum.Material.SmoothPlastic })
	for i = 0, 11 do
		local a = DEG(i * 30)
		block(ctx, Vector3.new(0.04, if i % 3 == 0 then 0.12 else 0.06, 0.02), at(math.sin(a) * 0.34, math.cos(a) * 0.34, -0.15) * CFrame.Angles(0, 0, -a), { Color = BLACK })
	end
	block(ctx, Vector3.new(0.05, 0.3, 0.03), at(0.05, 0.12, -0.16) * CFrame.Angles(0, 0, DEG(-25)), { Color = BLACK })
	block(ctx, Vector3.new(0.22, 0.05, 0.03), at(0.1, -0.02, -0.17) * CFrame.Angles(0, 0, DEG(-15)), { Color = BLACK })
	cylZ(ctx, 0.04, 0.84, at(0, 0, -0.17), { Color = Color3.fromRGB(220, 240, 255), Material = Enum.Material.Glass, Transparency = 0.75, Reflectance = 0.3 }) -- crystal
	cylX(ctx, 0.15, 0.16, at(0.6, 0, 0)) -- crown
end

function Builders.Mask(ctx)
	ellipsoid(ctx, Vector3.new(1.4, 1.8, 0.5), at(0, -0.1, 0))
	for _, x in { -0.32, 0.32 } do
		ellipsoid(ctx, Vector3.new(0.4, 0.2, 0.12), at(x, 0.2, -0.2), { Color = BLACK })
	end
	block(ctx, Vector3.new(0.6, 0.12, 0.1), at(0, -0.55, -0.15), { Color = ctx.accent })
	block(ctx, Vector3.new(0.18, 0.4, 0.12), at(0, -0.15, -0.18), { Color = darker(ctx.color, 0.8) })
	for i = -2, 2 do
		wedge(ctx, Vector3.new(0.2, 0.55, 0.22), at(i * 0.3, 1.0 - math.abs(i) * 0.08, 0), { Color = ctx.accent })
	end
	for _, x in { -0.72, 0.72 } do
		ellipsoid(ctx, Vector3.new(0.2, 0.9, 0.3), at(x, 0, 0), { Color = ctx.accent })
	end
end

function Builders.Bell(ctx)
	cylY(ctx, 0.35, 1.45, at(0, -0.55, 0))
	cylY(ctx, 0.4, 1.2, at(0, -0.2, 0))
	cylY(ctx, 0.4, 0.95, at(0, 0.18, 0))
	ball(ctx, 0.95, at(0, 0.42, 0))
	cylZ(ctx, 0.12, 0.45, at(0, 0.98, 0), { Color = ctx.accent })
	ball(ctx, 0.32, at(0, -0.82, 0), { Color = ctx.accent })
	torus(ctx, 0.72, 0.1, at(0, -0.72, 0) * CFrame.Angles(DEG(90), 0, 0), 20, { Color = darker(ctx.color, 0.85) }) -- flared lip
	torus(ctx, 0.5, 0.05, at(0, -0.1, 0) * CFrame.Angles(DEG(90), 0, 0), 16, { Color = ctx.accent }) -- decorative band
end

function Builders.Tooth(ctx)
	-- curved fang: stacked, shrinking ellipsoids bending to a point
	for i = 0, 4 do
		local t = i / 4
		ellipsoid(ctx, Vector3.new(0.62 - t * 0.42, 0.42, 0.5 - t * 0.32), at(t * 0.18, 0.55 - i * 0.32, 0))
	end
	cylY(ctx, 0.3, 0.62, at(0, -0.85, 0), { Color = ctx.accent }) -- root wrap
	torus(ctx, 0.3, 0.06, at(0, -0.85, 0) * CFrame.Angles(DEG(90), 0, 0), 12, { Color = darker(ctx.accent, 0.7) })
end

---------------------------------------------------------------------------
-- Update 17: twenty new shapes (jewellery, toys, fossils, nautical gear, mysteries)
---------------------------------------------------------------------------
-- small beads along a closed loop in the XY plane (chains)
local function beadLoop(ctx: Ctx, rx: number, ry: number, cy: number, count: number, size: number, props)
	for i = 0, count - 1 do
		local a = i / count * math.pi * 2
		ball(ctx, size, at(math.cos(a) * rx, cy + math.sin(a) * ry, math.sin(a) * 0.08), props)
	end
end

function Builders.Necklace(ctx)
	beadLoop(ctx, 0.62, 0.72, 0.25, 22, 0.13)
	torus(ctx, 0.1, 0.05, at(0, -0.55, 0), 8) -- bail
	facetGem(ctx, 0.42, at(0, -0.82, -0.02), ctx.accent)
	for _, x in { -0.32, 0.32 } do
		ball(ctx, 0.18, at(x, -0.3, -0.06), { Color = ctx.accent, Material = Enum.Material.Glass, Reflectance = 0.25 }) -- side stones
	end
	block(ctx, Vector3.new(0.16, 0.08, 0.08), at(0, 0.97, 0), { Color = darker(ctx.color, 0.8) }) -- clasp
end

function Builders.Bracelet(ctx)
	local tilt = CFrame.Angles(DEG(62), 0, DEG(-12))
	torus(ctx, 0.62, 0.24, tilt, 22)
	torus(ctx, 0.62, 0.1, tilt * CFrame.new(0, 0, -0.1), 22, { Color = darker(ctx.color, 0.75) }) -- engraved line
	for i = 0, 6 do
		local a = (i / 7) * math.pi * 2
		ball(ctx, 0.16, tilt * CFrame.new(math.cos(a) * 0.62, math.sin(a) * 0.62, -0.13), { Color = ctx.accent, Material = Enum.Material.Glass, Reflectance = 0.3 })
	end
end

function Builders.Locket(ctx)
	for i = 0, 7 do -- short chain rising in a V
		local t = i / 7
		for _, side in { -1, 1 } do
			ball(ctx, 0.09, at(side * (0.08 + t * 0.42), 0.5 + t * 0.55, 0), { Color = darker(ctx.color, 0.9) })
		end
	end
	torus(ctx, 0.1, 0.05, at(0, 0.45, 0), 8)
	ellipsoid(ctx, Vector3.new(0.95, 1.05, 0.32), at(0, -0.15, 0), { Reflectance = 0.2 })
	torus(ctx, 0.43, 0.07, at(0, -0.15, -0.1) * CFrame.new(0, 0, 0), 18, { Color = darker(ctx.color, 0.8) }) -- rim
	ellipsoid(ctx, Vector3.new(0.5, 0.56, 0.1), at(0, -0.15, -0.16), { Color = ctx.accent }) -- enamel face
	facetGem(ctx, 0.2, at(0, -0.15, -0.22), ctx.color:Lerp(Color3.new(1, 1, 1), 0.4))
	cylY(ctx, 0.14, 0.08, at(0.47, -0.15, 0), { Color = darker(ctx.color, 0.7) }) -- hinge
end

function Builders.Spectacles(ctx)
	for _, x in { -0.44, 0.44 } do
		torus(ctx, 0.32, 0.07, at(x, 0, 0), 16)
		cylZ(ctx, 0.04, 0.6, at(x, 0, 0), { Color = ctx.accent, Material = Enum.Material.Glass, Transparency = 0.35, Reflectance = 0.35 })
		block(ctx, Vector3.new(0.05, 0.06, 1.1), at(x * 1.7, 0.08, 0.55), {}) -- arms
		wedge(ctx, Vector3.new(0.05, 0.22, 0.2), at(x * 1.7, -0.05, 1.12) * CFrame.Angles(DEG(180), 0, 0), {}) -- ear hooks
	end
	cylX(ctx, 0.28, 0.06, at(0, 0.12, 0)) -- bridge
	for _, x in { -0.78, 0.78 } do
		block(ctx, Vector3.new(0.16, 0.08, 0.08), at(x, 0.1, 0.02))
	end
end

function Builders.ToyCar(ctx)
	block(ctx, Vector3.new(1.5, 0.4, 0.74), at(0, -0.12, 0), { Reflectance = 0.1 })
	ellipsoid(ctx, Vector3.new(0.85, 0.5, 0.66), at(0.08, 0.16, 0), {})
	block(ctx, Vector3.new(0.6, 0.22, 0.68), at(0.08, 0.2, 0), { Color = Color3.fromRGB(170, 210, 235), Material = Enum.Material.Glass, Transparency = 0.25 }) -- windows
	for _, x in { -0.48, 0.5 } do
		for _, z in { -0.37, 0.37 } do
			cylZ(ctx, 0.14, 0.42, at(x, -0.32, z), { Color = BLACK, Material = Enum.Material.Rubber })
			cylZ(ctx, 0.15, 0.2, at(x, -0.32, z), { Color = Color3.fromRGB(200, 200, 205), Material = Enum.Material.Metal }) -- hubcap
		end
	end
	for _, z in { -0.24, 0.24 } do
		ball(ctx, 0.14, at(-0.76, -0.08, z), { Color = Color3.fromRGB(255, 240, 160), Material = Enum.Material.Neon }) -- headlights
	end
	block(ctx, Vector3.new(0.06, 0.12, 0.6), at(0.76, -0.1, 0), { Color = ctx.accent }) -- bumper
	block(ctx, Vector3.new(1.0, 0.04, 0.12), at(0, 0.09, -0.38), { Color = ctx.accent }) -- racing stripe
end

function Builders.RubberDuck(ctx)
	ellipsoid(ctx, Vector3.new(1.0, 0.72, 1.2), at(0, -0.3, 0.05), {})
	ellipsoid(ctx, Vector3.new(0.4, 0.4, 0.5), at(0, -0.05, 0.55) * CFrame.Angles(DEG(-35), 0, 0), {}) -- tail
	ball(ctx, 0.66, at(0, 0.3, -0.25), {})
	ellipsoid(ctx, Vector3.new(0.38, 0.13, 0.32), at(0, 0.22, -0.62), { Color = ctx.accent }) -- beak
	for _, x in { -0.15, 0.15 } do
		ball(ctx, 0.11, at(x, 0.42, -0.52), { Color = BLACK, Material = Enum.Material.SmoothPlastic })
	end
	for _, x in { -0.42, 0.42 } do
		ellipsoid(ctx, Vector3.new(0.18, 0.4, 0.6), at(x, -0.28, 0.1) * CFrame.Angles(0, 0, DEG(x > 0 and -12 or 12)), { Color = darker(ctx.color, 0.92) }) -- wings
	end
end

function Builders.ToySoldier(ctx)
	cylY(ctx, 0.12, 0.8, at(0, -0.95, 0), { Color = Color3.fromRGB(70, 110, 60) }) -- base
	for _, x in { -0.12, 0.12 } do
		block(ctx, Vector3.new(0.18, 0.55, 0.22), at(x, -0.6, 0), { Color = Color3.fromRGB(30, 30, 40) })
	end
	block(ctx, Vector3.new(0.5, 0.62, 0.32), at(0, -0.04, 0), { Color = ctx.color }) -- tunic
	block(ctx, Vector3.new(0.52, 0.08, 0.34), at(0, -0.3, 0), { Color = Color3.fromRGB(240, 240, 240) }) -- belt
	block(ctx, Vector3.new(0.06, 0.6, 0.34), at(0, 0, 0.0) * CFrame.Angles(0, 0, DEG(35)), { Color = Color3.fromRGB(240, 240, 240) }) -- sash
	for _, x in { -0.32, 0.32 } do
		block(ctx, Vector3.new(0.14, 0.55, 0.18), at(x, -0.05, 0), { Color = ctx.color })
	end
	ball(ctx, 0.36, at(0, 0.45, 0), { Color = Color3.fromRGB(240, 205, 175), Material = Enum.Material.SmoothPlastic })
	cylY(ctx, 0.5, 0.36, at(0, 0.82, 0), { Color = Color3.fromRGB(25, 25, 30) }) -- tall hat
	ball(ctx, 0.1, at(0, 0.82, -0.18), { Color = ctx.accent, Material = Enum.Material.Metal }) -- badge
	block(ctx, Vector3.new(0.07, 1.1, 0.07), at(0.44, 0.15, -0.05), { Color = Color3.fromRGB(110, 75, 45) }) -- rifle
end

function Builders.Dice(ctx)
	local tilt = CFrame.Angles(DEG(-22), DEG(32), 0)
	block(ctx, Vector3.new(1.05, 1.05, 1.05), tilt, {})
	local pip = { Color = ctx.accent, Material = Enum.Material.SmoothPlastic }
	local h = 0.53
	-- front 5, top 3, right 2
	for _, p in { { 0, 0 }, { -0.28, -0.28 }, { 0.28, 0.28 }, { -0.28, 0.28 }, { 0.28, -0.28 } } do
		ball(ctx, 0.17, tilt * CFrame.new(p[1], p[2], -h), pip)
	end
	for _, p in { { -0.28, -0.28 }, { 0, 0 }, { 0.28, 0.28 } } do
		ball(ctx, 0.17, tilt * CFrame.new(p[1], h, p[2]), pip)
	end
	for _, p in { { -0.22, 0.22 }, { 0.22, -0.22 } } do
		ball(ctx, 0.17, tilt * CFrame.new(h, p[1], p[2]), pip)
	end
end

function Builders.Starfish(ctx)
	ellipsoid(ctx, Vector3.new(0.55, 0.55, 0.28), at(0, 0, 0), {})
	for i = 0, 4 do
		local a = DEG(90 + i * 72)
		ellipsoid(ctx, Vector3.new(0.34, 1.0, 0.22), at(math.cos(a) * 0.45, math.sin(a) * 0.45, 0.02) * CFrame.Angles(0, 0, a - DEG(90)), {})
		for k = 1, 3 do
			ball(ctx, 0.09, at(math.cos(a) * (0.2 + k * 0.2), math.sin(a) * (0.2 + k * 0.2), -0.11), { Color = ctx.accent })
		end
	end
	ball(ctx, 0.14, at(0, 0, -0.13), { Color = ctx.accent })
end

function Builders.SandDollar(ctx)
	cylZ(ctx, 0.14, 1.45, at(0, 0, 0), {})
	torus(ctx, 0.7, 0.08, at(0, 0, -0.03), 22, { Color = darker(ctx.color, 0.9) })
	for i = 0, 4 do
		local a = DEG(90 + i * 72)
		ellipsoid(ctx, Vector3.new(0.13, 0.4, 0.04), at(math.cos(a) * 0.28, math.sin(a) * 0.28, -0.08) * CFrame.Angles(0, 0, a - DEG(90)), { Color = ctx.accent })
	end
	ball(ctx, 0.12, at(0, 0, -0.06), { Color = darker(ctx.color, 0.6) })
	for i = 0, 4 do
		local a = DEG(54 + i * 72)
		ellipsoid(ctx, Vector3.new(0.08, 0.2, 0.04), at(math.cos(a) * 0.52, math.sin(a) * 0.52, -0.08) * CFrame.Angles(0, 0, a - DEG(90)), { Color = darker(ctx.color, 0.7) }) -- slots
	end
end

function Builders.Ammonite(ctx)
	-- a coiled shell: segments spiralling inwards, ribbed
	local n = 26
	for i = 0, n do
		local t = i / n
		local a = t * math.pi * 3.3
		local r = 0.72 * (1 - t * 0.85)
		local size = 0.5 * (1 - t * 0.75)
		local p = Vector3.new(math.cos(a) * r, math.sin(a) * r, 0)
		ellipsoid(ctx, Vector3.new(size * 1.1, size, size * 0.8), at(p.X, p.Y, 0) * CFrame.Angles(0, 0, a), { Color = if i % 2 == 0 then ctx.color else darker(ctx.color, 0.85) })
	end
	ball(ctx, 0.12, at(0, 0, -0.08), { Color = ctx.accent })
end

function Builders.Bone(ctx)
	local tilt = CFrame.Angles(0, 0, DEG(28))
	cylX(ctx, 1.45, 0.26, tilt, {})
	for _, x in { -0.78, 0.78 } do
		for _, y in { -0.13, 0.13 } do
			ball(ctx, 0.38, tilt * CFrame.new(x, y, 0), {})
		end
	end
	ellipsoid(ctx, Vector3.new(0.5, 0.1, 0.12), tilt * CFrame.new(0.1, 0.1, -0.1), { Color = darker(ctx.color, 0.8) }) -- crack
end

function Builders.Spyglass(ctx)
	local tilt = CFrame.Angles(0, DEG(20), DEG(14))
	cylX(ctx, 0.95, 0.46, tilt * CFrame.new(-0.55, 0, 0), {}) -- big barrel
	cylX(ctx, 0.75, 0.36, tilt * CFrame.new(0.25, 0, 0), {})
	cylX(ctx, 0.55, 0.27, tilt * CFrame.new(0.85, 0, 0), {})
	for _, x in { -1.0, -0.1, 0.6, 1.1 } do
		cylX(ctx, 0.08, if x < 0 then 0.52 else 0.4, tilt * CFrame.new(x, 0, 0), { Color = ctx.accent })
	end
	cylX(ctx, 0.06, 0.4, tilt * CFrame.new(-1.04, 0, 0), { Color = Color3.fromRGB(170, 220, 255), Material = Enum.Material.Glass, Transparency = 0.2, Reflectance = 0.4 })
	cylX(ctx, 0.5, 0.48, tilt * CFrame.new(-0.4, 0, 0), { Color = Color3.fromRGB(110, 70, 40), Material = Enum.Material.Leather }) -- leather grip
end

function Builders.ShipWheel(ctx)
	torus(ctx, 0.68, 0.16, at(0, 0, 0), 22, { Material = Enum.Material.Wood })
	cylZ(ctx, 0.3, 0.42, at(0, 0, 0), { Color = ctx.accent, Material = Enum.Material.Metal })
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		block(ctx, Vector3.new(0.09, 1.0, 0.09), at(math.cos(a) * 0.5, math.sin(a) * 0.5, 0) * CFrame.Angles(0, 0, a - math.pi / 2), { Material = Enum.Material.Wood })
		cylX(ctx, 0.36, 0.13, at(math.cos(a) * 0.98, math.sin(a) * 0.98, 0) * CFrame.Angles(0, 0, a), { Material = Enum.Material.Wood }) -- handles
		ball(ctx, 0.1, at(math.cos(a) * 0.68, math.sin(a) * 0.68, -0.09), { Color = ctx.accent, Material = Enum.Material.Metal }) -- studs
	end
end

function Builders.Lantern(ctx)
	cylY(ctx, 0.14, 0.86, at(0, -0.85, 0), {})
	cylY(ctx, 0.12, 0.8, at(0, 0.45, 0), {})
	cylY(ctx, 0.22, 0.5, at(0, 0.62, 0), {}) -- roof
	ball(ctx, 0.24, at(0, 0.78, 0), {})
	torus(ctx, 0.22, 0.05, at(0, 1.0, 0), 10, {}) -- handle
	cylY(ctx, 1.15, 0.66, at(0, -0.2, 0), { Color = Color3.fromRGB(255, 236, 190), Material = Enum.Material.Glass, Transparency = 0.45, Reflectance = 0.2 })
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		block(ctx, Vector3.new(0.07, 1.25, 0.07), at(math.cos(a) * 0.35, -0.2, math.sin(a) * 0.35), {}) -- frame posts
	end
	ellipsoid(ctx, Vector3.new(0.18, 0.32, 0.18), at(0, -0.25, 0), { Color = ctx.accent, Material = Enum.Material.Neon }) -- flame
	cylY(ctx, 0.25, 0.1, at(0, -0.55, 0), { Color = Color3.fromRGB(240, 235, 220) }) -- wick
end

function Builders.Amphora(ctx)
	ellipsoid(ctx, Vector3.new(0.95, 1.25, 0.95), at(0, -0.12, 0), {})
	cylY(ctx, 0.5, 0.36, at(0, 0.62, 0), {})
	torus(ctx, 0.22, 0.08, at(0, 0.88, 0) * CFrame.Angles(DEG(90), 0, 0), 14, { Color = darker(ctx.color, 0.85) })
	cylY(ctx, 0.25, 0.3, at(0, -0.8, 0), {})
	cylY(ctx, 0.08, 0.5, at(0, -0.94, 0), { Color = darker(ctx.color, 0.85) })
	torus(ctx, 0.48, 0.06, at(0, 0.05, 0) * CFrame.Angles(DEG(90), 0, 0), 20, { Color = ctx.accent }) -- painted band
	torus(ctx, 0.44, 0.05, at(0, -0.35, 0) * CFrame.Angles(DEG(90), 0, 0), 20, { Color = ctx.accent })
	for _, x in { -0.42, 0.42 } do
		torus(ctx, 0.2, 0.07, at(x, 0.48, 0) * CFrame.Angles(0, DEG(90), 0), 10, {}) -- handles
	end
end

function Builders.Hourglass(ctx)
	for _, y in { -0.95, 0.95 } do
		cylY(ctx, 0.14, 1.0, at(0, y, 0), { Color = ctx.accent, Material = Enum.Material.Wood })
	end
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		cylY(ctx, 1.8, 0.09, at(math.cos(a) * 0.42, 0, math.sin(a) * 0.42), { Color = ctx.accent, Material = Enum.Material.Wood })
	end
	local glass = { Color = Color3.fromRGB(230, 245, 255), Material = Enum.Material.Glass, Transparency = 0.55, Reflectance = 0.3 }
	ellipsoid(ctx, Vector3.new(0.62, 0.85, 0.62), at(0, 0.45, 0), glass)
	ellipsoid(ctx, Vector3.new(0.62, 0.85, 0.62), at(0, -0.45, 0), glass)
	ellipsoid(ctx, Vector3.new(0.44, 0.3, 0.44), at(0, -0.68, 0), { Color = ctx.color, Material = Enum.Material.Sand }) -- sand below
	ellipsoid(ctx, Vector3.new(0.3, 0.22, 0.3), at(0, 0.3, 0), { Color = ctx.color, Material = Enum.Material.Sand }) -- sand above
	cylY(ctx, 0.5, 0.04, at(0, -0.12, 0), { Color = ctx.color, Material = Enum.Material.Sand }) -- the trickle
end

function Builders.Meteorite(ctx)
	local seed = Random.new(11)
	ellipsoid(ctx, Vector3.new(1.3, 1.0, 1.05), at(0, 0, 0) * CFrame.Angles(DEG(10), DEG(25), DEG(-8)), { Reflectance = 0.05 })
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2
		ellipsoid(ctx, Vector3.new(0.45 + seed:NextNumber() * 0.3, 0.4 + seed:NextNumber() * 0.25, 0.45),
			at(math.cos(a) * 0.48, seed:NextNumber(-0.3, 0.3), math.sin(a) * 0.4) * CFrame.Angles(seed:NextNumber(), seed:NextNumber(), seed:NextNumber()),
			{ Color = darker(ctx.color, 0.8 + seed:NextNumber() * 0.25) })
	end
	for i = 1, 5 do -- glowing fissures
		block(ctx, Vector3.new(0.05, 0.35 + seed:NextNumber() * 0.3, 0.05), at(seed:NextNumber(-0.4, 0.4), seed:NextNumber(-0.3, 0.3), -0.5) * CFrame.Angles(0, 0, seed:NextNumber(-1, 1)),
			{ Color = ctx.accent, Material = Enum.Material.Neon })
	end
	for i = 1, 4 do
		ball(ctx, 0.12, at(seed:NextNumber(-0.5, 0.5), seed:NextNumber(-0.4, 0.4), -0.48), { Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Metal, Reflectance = 0.3 })
	end
end

function Builders.RuneStone(ctx)
	block(ctx, Vector3.new(1.0, 1.6, 0.36), at(0, 0, 0), {})
	wedge(ctx, Vector3.new(1.0, 0.3, 0.36), at(0, 0.95, 0) * CFrame.Angles(0, DEG(90), 0) * CFrame.Angles(0, 0, 0), {})
	ellipsoid(ctx, Vector3.new(0.5, 0.25, 0.3), at(-0.3, -0.72, -0.1), { Color = Color3.fromRGB(80, 120, 60), Material = Enum.Material.Grass }) -- moss
	ellipsoid(ctx, Vector3.new(0.3, 0.2, 0.25), at(0.38, 0.6, -0.12), { Color = Color3.fromRGB(90, 130, 70), Material = Enum.Material.Grass })
	local rune = { Color = ctx.accent, Material = Enum.Material.Neon }
	block(ctx, Vector3.new(0.08, 0.9, 0.04), at(0, 0.05, -0.19), rune)
	block(ctx, Vector3.new(0.08, 0.45, 0.04), at(-0.14, 0.32, -0.19) * CFrame.Angles(0, 0, DEG(-40)), rune)
	block(ctx, Vector3.new(0.08, 0.45, 0.04), at(0.14, 0.32, -0.19) * CFrame.Angles(0, 0, DEG(40)), rune)
	block(ctx, Vector3.new(0.08, 0.38, 0.04), at(0.12, -0.25, -0.19) * CFrame.Angles(0, 0, DEG(50)), rune)
	ball(ctx, 0.14, at(0, -0.48, -0.19), rune)
end

function Builders.Porthole(ctx)
	torus(ctx, 0.62, 0.24, at(0, 0, 0), 22, { Reflectance = 0.15 })
	cylZ(ctx, 0.08, 1.1, at(0, 0, 0.02), { Color = Color3.fromRGB(120, 190, 220), Material = Enum.Material.Glass, Transparency = 0.35, Reflectance = 0.3 })
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		ball(ctx, 0.12, at(math.cos(a) * 0.62, math.sin(a) * 0.62, -0.13), { Color = darker(ctx.color, 0.75) })
	end
	block(ctx, Vector3.new(0.2, 0.36, 0.16), at(-0.82, 0, 0), {}) -- hinge
	block(ctx, Vector3.new(0.34, 0.12, 0.12), at(0.86, 0, -0.04), { Color = ctx.accent }) -- latch
	ellipsoid(ctx, Vector3.new(0.3, 0.2, 0.06), at(-0.2, 0.25, -0.06), { Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = 0.6 }) -- glint
end

function Builders.Seahorse(ctx)
	-- profile, facing -X: snout, head, curved belly, curled tail
	ellipsoid(ctx, Vector3.new(0.5, 0.42, 0.34), at(-0.05, 0.75, 0), {}) -- head
	cylX(ctx, 0.42, 0.14, at(-0.42, 0.68, 0) * CFrame.Angles(0, 0, DEG(-12)), {}) -- snout
	ellipsoid(ctx, Vector3.new(0.18, 0.28, 0.2), at(0.1, 1.0, 0), { Color = ctx.accent }) -- crest
	ball(ctx, 0.1, at(-0.12, 0.8, -0.16), { Color = BLACK })
	local spine = { { 0.05, 0.42, 0.46 }, { 0.12, 0.12, 0.5 }, { 0.08, -0.18, 0.44 }, { -0.04, -0.44, 0.36 }, { 0.02, -0.66, 0.28 } }
	for _, seg in spine do
		ellipsoid(ctx, Vector3.new(seg[3] * 1.05, 0.34, seg[3] * 0.8), at(seg[1], seg[2], 0), {})
	end
	for i = 0, 9 do -- curled tail
		local a = DEG(-90 + i * 34)
		local r = 0.3 * (1 - i * 0.07)
		ball(ctx, 0.2 * (1 - i * 0.06), at(0.25 + math.cos(a) * r, -0.92 + math.sin(a) * r, 0), {})
	end
	wedge(ctx, Vector3.new(0.06, 0.4, 0.3), at(0.32, 0.1, 0) * CFrame.Angles(0, DEG(90), 0), { Color = ctx.accent }) -- dorsal fin
	for i = 0, 4 do
		block(ctx, Vector3.new(0.4, 0.04, 0.36), at(0.05, 0.4 - i * 0.26, -0.01), { Color = darker(ctx.color, 0.8) }) -- ridges
	end
end

function Builders.Trilobite(ctx)
	ellipsoid(ctx, Vector3.new(1.0, 0.55, 0.3), at(0, 0.65, 0), {}) -- head shield
	for _, x in { -0.25, 0.25 } do
		ball(ctx, 0.14, at(x, 0.7, -0.13), { Color = ctx.accent })
	end
	for i = 0, 8 do
		local y = 0.35 - i * 0.16
		local w = 1.0 - i * 0.08
		ellipsoid(ctx, Vector3.new(w, 0.16, 0.24), at(0, y, 0), { Color = if i % 2 == 0 then ctx.color else darker(ctx.color, 0.85) })
	end
	ellipsoid(ctx, Vector3.new(0.3, 1.5, 0.3), at(0, -0.1, -0.06), { Color = darker(ctx.color, 0.9) }) -- central ridge
	ellipsoid(ctx, Vector3.new(0.4, 0.25, 0.2), at(0, -1.12, 0), {}) -- tail
end

function Builders.Pipe(ctx)
	cylY(ctx, 0.6, 0.5, at(-0.45, 0.15, 0), { Material = Enum.Material.Wood })
	cylY(ctx, 0.05, 0.36, at(-0.45, 0.44, 0), { Color = BLACK }) -- bowl hollow
	ellipsoid(ctx, Vector3.new(0.5, 0.3, 0.5), at(-0.45, -0.15, 0), { Material = Enum.Material.Wood })
	cylX(ctx, 1.1, 0.14, at(0.25, -0.05, 0) * CFrame.Angles(0, 0, DEG(10)), { Material = Enum.Material.Wood })
	cylX(ctx, 0.12, 0.17, at(-0.15, -0.12, 0) * CFrame.Angles(0, 0, DEG(10)), { Color = ctx.accent, Material = Enum.Material.Metal }) -- band
	cylX(ctx, 0.3, 0.1, at(0.92, 0.07, 0) * CFrame.Angles(0, 0, DEG(10)), { Color = BLACK }) -- mouthpiece
end

function Builders.Medal(ctx)
	wedge(ctx, Vector3.new(0.05, 0.9, 0.36), at(-0.18, 0.55, 0) * CFrame.Angles(0, DEG(90), DEG(-14)), { Color = ctx.accent, Material = Enum.Material.Fabric })
	wedge(ctx, Vector3.new(0.05, 0.9, 0.36), at(0.18, 0.55, 0) * CFrame.Angles(0, DEG(-90), DEG(14)), { Color = ctx.accent, Material = Enum.Material.Fabric })
	block(ctx, Vector3.new(0.6, 0.1, 0.06), at(0, 0.1, 0), { Color = darker(ctx.color, 0.85) }) -- bar
	cylZ(ctx, 0.14, 0.95, at(0, -0.42, 0), {})
	torus(ctx, 0.45, 0.06, at(0, -0.42, -0.05), 18, { Color = darker(ctx.color, 0.8) })
	for i = 0, 4 do -- star
		local a = DEG(i * 72 + 90)
		wedge(ctx, Vector3.new(0.05, 0.3, 0.12), at(math.cos(a) * 0.12, -0.42 + math.sin(a) * 0.12, -0.1) * CFrame.Angles(0, 0, a - DEG(90)), { Color = darker(ctx.color, 0.9) })
	end
end

-- Realistic default material per shape (only when the treasure doesn't choose its own)
local DEFAULT_MATERIAL: { [string]: Enum.Material } = {
	Coin = Enum.Material.Metal,
	CoinStack = Enum.Material.Metal,
	Ring = Enum.Material.Metal,
	Crown = Enum.Material.Metal,
	Key = Enum.Material.Metal,
	Goblet = Enum.Material.Metal,
	Bell = Enum.Material.Metal,
	Anchor = Enum.Material.Metal,
	Sword = Enum.Material.Metal,
	Trident = Enum.Material.Metal,
	Compass = Enum.Material.Metal,
	Watch = Enum.Material.Metal,
	Can = Enum.Material.Metal,
	Bar = Enum.Material.Metal,
	Bottle = Enum.Material.Glass,
	Skull = Enum.Material.Limestone,
	Tooth = Enum.Material.Limestone,
	Statue = Enum.Material.Marble,
	Chest = Enum.Material.WoodPlanks,
	Scroll = Enum.Material.Fabric,
	Necklace = Enum.Material.Metal,
	Bracelet = Enum.Material.Metal,
	Locket = Enum.Material.Metal,
	Spectacles = Enum.Material.Metal,
	ToyCar = Enum.Material.SmoothPlastic,
	RubberDuck = Enum.Material.SmoothPlastic,
	ToySoldier = Enum.Material.SmoothPlastic,
	Dice = Enum.Material.SmoothPlastic,
	Starfish = Enum.Material.SmoothPlastic,
	SandDollar = Enum.Material.Limestone,
	Ammonite = Enum.Material.Limestone,
	Bone = Enum.Material.Limestone,
	Trilobite = Enum.Material.Slate,
	Spyglass = Enum.Material.Metal,
	ShipWheel = Enum.Material.Wood,
	Lantern = Enum.Material.Metal,
	Amphora = Enum.Material.Sandstone,
	Hourglass = Enum.Material.Wood,
	Meteorite = Enum.Material.Basalt,
	RuneStone = Enum.Material.Slate,
	Porthole = Enum.Material.Metal,
	Seahorse = Enum.Material.SmoothPlastic,
	Pipe = Enum.Material.Wood,
	Medal = Enum.Material.Metal,
}

-- Weathering and polish: low tiers still carry beach grit, high tiers are polished
local function finish(ctx: Ctx, tier: number, seedText: string)
	if ctx.silhouette then
		return
	end
	local parts = {}
	for _, part in ctx.model:GetChildren() do
		if part:IsA("BasePart") and part.Name ~= "Root" and part.Transparency < 0.5 then
			table.insert(parts, part)
		end
	end
	if tier >= 3 then
		for _, part in parts do
			if part.Material == Enum.Material.Metal then
				part.Reflectance = math.max(part.Reflectance, 0.18)
			end
		end
		return
	end
	-- a few grains of sand stuck to the find (seeded per treasure so icons don't change)
	local seed = 0
	for i = 1, #seedText do
		seed = (seed * 31 + string.byte(seedText, i)) % 100000
	end
	local rng = Random.new(seed)
	local grit = Color3.fromRGB(214, 186, 132)
	for i = 1, math.min(#parts, 3) do
		local host = parts[rng:NextInteger(1, #parts)]
		local size = (0.08 + rng:NextNumber() * 0.1) * ctx.scale
		local offset = Vector3.new(rng:NextNumber(-0.35, 0.35) * host.Size.X, -0.42 * host.Size.Y, -0.45 * host.Size.Z)
		local part = Instance.new("Part")
		part.Name = "Grit" .. i
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = false
		part.Material = Enum.Material.Sand
		part.Color = grit:Lerp(Color3.fromRGB(150, 120, 80), rng:NextNumber() * 0.4)
		part.Size = Vector3.new(size * 1.6, size, size * 1.3)
		part.CFrame = host.CFrame * CFrame.new(offset)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
		part.Parent = ctx.model
	end
end

-- Accessibility / fallback: any unknown shape becomes a gem
local function getBuilder(shape: string)
	return Builders[shape] or Builders.Gem
end

export type BuildOptions = {
	Scale: number?,
	Silhouette: boolean?,
	NoLights: boolean?,
	Plain: boolean?, -- skip the rarity decorations
}

local RAINBOW = {
	Color3.fromRGB(255, 110, 110),
	Color3.fromRGB(255, 200, 90),
	Color3.fromRGB(255, 250, 120),
	Color3.fromRGB(110, 255, 160),
	Color3.fromRGB(110, 190, 255),
	Color3.fromRGB(200, 120, 255),
}

--[[
	Rarity "frames" so each tier has its own silhouette:
	  Rare       a faceted stud gem on the front
	  Epic       + a fine filigree halo ring behind the treasure
	  Legendary  + the halo glows and grows sun-rays
	  Mythical   + a second crossed halo and floating crystal shards
	  Secret     + a rainbow halo, a full starburst and prismatic shards
]]
function TreasureModels.Embellish(ctx: Ctx, rarity: string)
	local tier = Rarities.Tier(rarity)
	if tier < 3 then
		return
	end
	local info = Rarities.Info[rarity]
	local tint = if info and not info.Rainbow then info.Color else Color3.fromRGB(255, 250, 230)
	local boxCF, size = ctx.model:GetBoundingBox()
	local s = ctx.scale
	local center = boxCF.Position / s
	local extent = Vector3.new(size.X, size.Y, size.Z) / s
	local radius = math.max(extent.X, extent.Y) * 0.62 + 0.15
	local behind = center.Z + extent.Z / 2 + 0.12
	-- Rare+: stud gem on the front face
	facetGem(ctx, 0.26, at(center.X, center.Y - extent.Y * 0.2, center.Z - extent.Z / 2 - 0.06), tint)
	if tier < 4 then
		return
	end
	local haloProps = { Color = if tier >= 5 then tint else Color3.fromRGB(255, 214, 120), Material = if tier >= 5 then Enum.Material.Neon else Enum.Material.Metal }
	torus(ctx, radius, 0.07, at(center.X, center.Y, behind), 24, haloProps, if tier >= 7 then RAINBOW else nil)
	if tier >= 5 then
		local rays = if tier >= 7 then 12 else 8
		for i = 0, rays - 1 do
			local a = i / rays * math.pi * 2
			local length = if i % 2 == 0 then 0.5 else 0.3
			wedge(ctx, Vector3.new(0.05, length, 0.14), at(center.X + math.cos(a) * (radius + length / 2 + 0.05), center.Y + math.sin(a) * (radius + length / 2 + 0.05), behind)
				* CFrame.Angles(0, 0, a - math.pi / 2), { Color = if tier >= 7 then RAINBOW[i % #RAINBOW + 1] else tint, Material = Enum.Material.Neon })
		end
	end
	if tier >= 6 then
		torus(ctx, radius * 0.92, 0.05, at(center.X, center.Y, behind + 0.05) * CFrame.Angles(0, DEG(60), 0), 22,
			{ Color = tint, Material = Enum.Material.Neon, Transparency = 0.2 })
		for i = 0, 2 do
			local a = DEG(i * 120 + 30)
			block(ctx, Vector3.new(0.16, 0.42, 0.16), at(center.X + math.cos(a) * radius * 1.15, center.Y - extent.Y * 0.35 + i * 0.12, center.Z + math.sin(a) * radius * 0.6)
				* CFrame.Angles(DEG(25), a, DEG(20)), { Color = if tier >= 7 then RAINBOW[i * 2 + 1] else tint, Material = Enum.Material.Glass, Transparency = 0.1, Reflectance = 0.3 })
		end
	end
end

function TreasureModels.Build(treasureId: string, options: BuildOptions?): Model
	local opts = options or {}
	local def = Treasures.ById[treasureId]
	local model = Instance.new("Model")
	model.Name = if def then def.Name else "Treasure"

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	if not def then
		return model
	end

	local material = DEFAULT_MATERIAL[def.Shape] or Enum.Material.SmoothPlastic
	if def.Material then
		local ok, value = pcall(function()
			return (Enum.Material :: any)[def.Material]
		end)
		if ok and value then
			material = value
		end
	end

	local ctx: Ctx = {
		model = model,
		color = def.Color,
		accent = def.Accent or darker(def.Color, 0.7),
		material = material,
		scale = (def.Scale or 1) * (opts.Scale or 1),
		silhouette = opts.Silhouette == true,
	}
	getBuilder(def.Shape)(ctx)
	finish(ctx, Rarities.Tier(def.Rarity), def.Id)
	if not opts.Plain then
		TreasureModels.Embellish(ctx, def.Rarity)
	end

	if def.Glow and not opts.NoLights and not opts.Silhouette then
		local light = Instance.new("PointLight")
		light.Color = def.Color
		light.Brightness = 1.6
		light.Range = 9
		light.Parent = root
	end

	model:SetAttribute("TreasureId", def.Id)
	return model
end

--[[
	Held in a hand (Update 17): every shape has its own pose, so a coin is shown off between the
	fingers, a sword is held by its grip pointing up, a key by its bow, a chest carried in the fist...
	  Size  largest side of the object itself (rarity halos not counted) in studs
	  Grip  how far up the object the fist closes (0 = its bottom, 0.5 = its middle)
	  Roll  degrees around the facing axis first (e.g. a key lying sideways is stood up)
	  Tilt  degrees the top leans away, so the face tips up towards the camera
	Models face -Z; held ones turn round (Turn, default 180) to face the player holding them -
	in a tool, handle -Z points forward and +Y up while the arm is raised (R6 and R15 alike).
]]
local HOLD: { [string]: { Size: number, Grip: number, Roll: number?, Tilt: number?, Turn: number? } } = {
	Coin = { Size = 0.95, Grip = 0.08, Tilt = 18 },
	CoinStack = { Size = 1.1, Grip = 0.15, Tilt = 10 },
	Ring = { Size = 0.9, Grip = 0.05, Tilt = 15 },
	Gem = { Size = 0.95, Grip = 0.2, Tilt = 12 },
	Bar = { Size = 1.15, Grip = 0.3, Tilt = 22 },
	Chest = { Size = 1.5, Grip = 0.3, Tilt = 6 },
	Bottle = { Size = 1.45, Grip = 0.28, Tilt = 6 },
	Key = { Size = 1.25, Grip = 0.12, Roll = 90, Tilt = 10 },
	Crown = { Size = 1.15, Grip = 0.12, Tilt = 12 },
	Skull = { Size = 1.05, Grip = 0.12, Tilt = 8 },
	Orb = { Size = 0.85, Grip = 0.2, Tilt = 0 },
	Shell = { Size = 1.0, Grip = 0.1, Tilt = 20 },
	Compass = { Size = 0.95, Grip = 0.1, Tilt = 20 },
	Statue = { Size = 1.3, Grip = 0.12, Tilt = 4 },
	Trident = { Size = 2.6, Grip = 0.3, Tilt = 4 },
	Scroll = { Size = 1.3, Grip = 0.35, Tilt = 16 },
	Goblet = { Size = 1.1, Grip = 0.22, Tilt = 6 },
	Anchor = { Size = 1.7, Grip = 0.62, Tilt = 4 },
	Sword = { Size = 2.4, Grip = 0.15, Tilt = 4 },
	Can = { Size = 1.0, Grip = 0.3, Tilt = 6 },
	Watch = { Size = 1.1, Grip = 0.12, Tilt = 18 },
	Mask = { Size = 1.3, Grip = 0.1, Tilt = 10 },
	Bell = { Size = 1.05, Grip = 0.15, Tilt = 6 },
	Tooth = { Size = 0.9, Grip = 0.18, Tilt = 10 },
	Necklace = { Size = 1.15, Grip = 0.75, Tilt = 10 }, -- dangling from the fist
	Bracelet = { Size = 1.0, Grip = 0.1, Tilt = 10 },
	Locket = { Size = 1.05, Grip = 0.8, Tilt = 12 },
	Spectacles = { Size = 1.1, Grip = 0.2, Tilt = 10, Turn = 180 },
	ToyCar = { Size = 1.15, Grip = 0.1, Tilt = 8 },
	RubberDuck = { Size = 0.95, Grip = 0.1, Tilt = 4 },
	ToySoldier = { Size = 1.05, Grip = 0.12, Tilt = 4 },
	Dice = { Size = 0.8, Grip = 0.15, Tilt = 0 },
	Starfish = { Size = 1.0, Grip = 0.1, Tilt = 18 },
	SandDollar = { Size = 0.95, Grip = 0.08, Tilt = 18 },
	Ammonite = { Size = 1.0, Grip = 0.1, Tilt = 16 },
	Bone = { Size = 1.25, Grip = 0.35, Tilt = 6 },
	Trilobite = { Size = 1.05, Grip = 0.1, Tilt = 16 },
	Spyglass = { Size = 1.8, Grip = 0.35, Roll = 60, Tilt = 4 },
	ShipWheel = { Size = 1.6, Grip = 0.1, Tilt = 6 },
	Lantern = { Size = 1.3, Grip = 0.88, Tilt = 0 }, -- carried by its handle
	Amphora = { Size = 1.3, Grip = 0.18, Tilt = 4 },
	Hourglass = { Size = 1.15, Grip = 0.12, Tilt = 4 },
	Meteorite = { Size = 1.0, Grip = 0.15, Tilt = 6 },
	RuneStone = { Size = 1.25, Grip = 0.1, Tilt = 6 },
	Porthole = { Size = 1.1, Grip = 0.1, Tilt = 14 },
	Seahorse = { Size = 1.2, Grip = 0.15, Tilt = 6 },
	Pipe = { Size = 1.0, Grip = 0.2, Tilt = 6 },
	Medal = { Size = 1.0, Grip = 0.85, Tilt = 12 },
}
local DEFAULT_HOLD = { Size = 1.05, Grip = 0.18, Tilt = 12 }
TreasureModels.Hold = HOLD

-- A treasure posed for a hand: the grip point sits at the model's origin (where the handle goes).
-- Returns the model and its held size (studs, bounding box of the posed object).
function TreasureModels.BuildHeld(treasureId: string): (Model, Vector3)
	local def = Treasures.ById[treasureId]
	local hold = (def and HOLD[def.Shape]) or DEFAULT_HOLD
	-- measure the object itself (no rarity halo) so every item comes out a sensible size
	local plain = TreasureModels.Build(treasureId, { Plain = true, NoLights = true })
	local coreCF, coreSize = plain:GetBoundingBox()
	plain:Destroy()
	local model = TreasureModels.Build(treasureId, { NoLights = true })
	local scale = hold.Size / math.max(coreSize.X, coreSize.Y, coreSize.Z, 0.05)
	model:ScaleTo(scale)

	local roll = CFrame.Angles(0, 0, DEG(hold.Roll or 0))
	local turn = CFrame.Angles(0, DEG(hold.Turn or 180), 0)
	local tilt = CFrame.Angles(DEG(-(hold.Tilt or 0)), 0, 0)
	-- the object's box after the roll, to find where the fist closes
	local center = coreCF.Position * scale
	local half = coreSize * scale / 2
	local low, high = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local corner = roll * (center + (coreCF.Rotation * Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)))
				low = low:Min(corner)
				high = high:Max(corner)
			end
		end
	end
	local mid = (low + high) / 2
	local grip = Vector3.new(mid.X, low.Y + (high.Y - low.Y) * hold.Grip, mid.Z)
	model:PivotTo(tilt * turn * CFrame.new(-grip) * roll)
	return model, high - low
end

-- Size of the model's bounding box
function TreasureModels.GetSize(model: Model): Vector3
	return model:GetExtentsSize()
end

TreasureModels.Shapes = Builders

return TreasureModels
