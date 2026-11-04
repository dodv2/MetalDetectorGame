--[[
	EnvironmentService
	Builds the natural-looking parts of the world when the server starts:
	  * any Map part with a TerrainMaterial attribute (beaches, grass, cliffs, rocks) is turned into
	    smooth Terrain of that material and hidden (the part stays as the zone's shape for scripts)
	  * dig areas with a Shore attribute get a sandy slope running down into the sea
	  * the ocean (from the blue "SeaPreview" part), clouds and terrain colours
	In Studio edit mode you see the parts; press Play to see the terrain.
]]

local Workspace = game:GetService("Workspace")

local EnvironmentService = {}

local function materialFrom(name: string): Enum.Material?
	local ok, value = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	return if ok then value else nil
end

-- An axis-aligned (unrotated) box part
local function isFlatBox(part: BasePart): boolean
	local _, _, _, r00, r01, r02, r10, r11, r12, r20, r21, r22 = part.CFrame:GetComponents()
	return math.abs(r00 - 1) < 1e-3 and math.abs(r11 - 1) < 1e-3 and math.abs(r22 - 1) < 1e-3
		and math.abs(r01) + math.abs(r02) + math.abs(r10) + math.abs(r12) + math.abs(r20) + math.abs(r21) < 1e-3
end

-- Fills whole 4-stud voxels so the terrain surface lands exactly on the part's top face.
-- (FillBlock on a box that doesn't line up with the voxel grid leaves half-full voxels,
-- and smooth terrain rounds those UP - that's what used to bury the base floor.)
local function fillAligned(terrain: Terrain, part: BasePart, material: Enum.Material)
	local half = part.Size / 2
	local low = part.Position - half
	local high = part.Position + half
	local top = math.floor(high.Y / 4 + 0.5) * 4 -- snap the top to the nearest voxel boundary
	local bottom = math.min(top - 4, math.floor(low.Y / 4) * 4)
	local minX, maxX = math.floor(low.X / 4) * 4, math.ceil(high.X / 4) * 4
	local minZ, maxZ = math.floor(low.Z / 4) * 4, math.ceil(high.Z / 4) * 4
	local region = Region3.new(Vector3.new(minX, bottom, minZ), Vector3.new(maxX, top, maxZ))
	terrain:FillRegion(region, 4, material)
end

function EnvironmentService:Start()
	local terrain = Workspace.Terrain
	local map = Workspace:WaitForChild("Map")

	-- 1. Ocean + sea floor
	local preview = map:FindFirstChild("SeaPreview")
	local region = if preview and preview:IsA("BasePart") then preview else nil
	local center = if region then region.Position else Vector3.new(425, -6.5, -230)
	local size = if region then region.Size else Vector3.new(1180, 12, 440)
	terrain:FillBlock(CFrame.new(center), size, Enum.Material.Water)
	terrain:FillBlock(CFrame.new(center - Vector3.new(0, size.Y / 2 + 3, 0)), Vector3.new(size.X, 6, size.Z), Enum.Material.Sand)
	if preview then
		preview:Destroy()
	end

	-- 2. Parts that become terrain
	for _, part in map:GetDescendants() do
		if part:IsA("BasePart") then
			local materialName = part:GetAttribute("TerrainMaterial")
			local material = if type(materialName) == "string" then materialFrom(materialName) else nil
			if material then
				if part:IsA("Part") and part.Shape == Enum.PartType.Ball then
					terrain:FillBall(part.Position, part.Size.X / 2, material)
				elseif part:IsA("Part") and part.Shape == Enum.PartType.Cylinder then
					terrain:FillCylinder(part.CFrame * CFrame.Angles(0, 0, math.rad(90)), part.Size.X, part.Size.Y / 2, material)
				elseif part.ClassName == "Part" and isFlatBox(part) then
					fillAligned(terrain, part, material)
				else
					terrain:FillBlock(part.CFrame, part.Size, material)
				end
				-- Shore slope: from the sea-facing (-Z) edge down under the water
				local shore = part:GetAttribute("Shore")
				if type(shore) == "number" and shore > 0 then
					local top = part.Position.Y + part.Size.Y / 2
					local edgeZ = part.Position.Z - part.Size.Z / 2
					local wedgeSize = Vector3.new(part.Size.X, 10, shore)
					terrain:FillWedge(CFrame.new(part.Position.X, top - 5, edgeZ - shore / 2), wedgeSize, material)
				end
				part.Transparency = 1
				part.CanCollide = false
				part.CanQuery = false
				part.CastShadow = false
			end
		end
	end

	-- 3. Look (each beach's client also tints the water to its own mood - see WorldController)
	terrain.WaterColor = Color3.fromRGB(28, 156, 176)
	terrain.WaterTransparency = 0.6
	terrain.WaterWaveSize = 0.22
	terrain.WaterWaveSpeed = 10
	terrain.WaterReflectance = 0.6
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(236, 214, 164)) -- golden sand
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(190, 164, 120)) -- wet sand where the waves reach
	terrain:SetMaterialColor(Enum.Material.Salt, Color3.fromRGB(184, 178, 164)) -- Rocky Shore: coarse grey shingle sand
	terrain:SetMaterialColor(Enum.Material.Snow, Color3.fromRGB(232, 222, 196)) -- Tropical Island: pale powder sand
	terrain:SetMaterialColor(Enum.Material.Sandstone, Color3.fromRGB(204, 172, 126)) -- Abandoned Pier: weathered brown sand
	terrain:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(84, 78, 72)) -- Shipwreck Coast: dark, wet volcanic sand
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(104, 172, 82))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(96, 168, 78))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(150, 142, 128))

	-- a steady sea breeze: clouds drift across the sky and particles/grass lean with it
	Workspace.GlobalWind = Vector3.new(6, 0, -3)
	if not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.45
		clouds.Density = 0.55
		clouds.Color = Color3.fromRGB(255, 255, 255)
		clouds.Parent = terrain
	end
end

return EnvironmentService
