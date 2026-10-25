--!strict
-- Shrinking safe zone. Circles are in the XZ plane. Each phase holds the previous
-- circle until its start time, then shrinks linearly. Phase centers move toward the
-- final landmark so the landmark stays inside every circle.
local Zone = {}

export type Circle = { x: number, z: number, radius: number }
export type ZoneState = Circle & { damage: number, shrinking: boolean, nextChangeIn: number? }

local function phaseCircle(config: any, index: number, origin: Circle, landmark: Circle): Circle
	local phase = config.phases[index]
	local radius = origin.radius * phase.radius
	local dx, dz = origin.x - landmark.x, origin.z - landmark.z
	local distance = math.sqrt(dx * dx + dz * dz)
	local allowed = radius * config.landmarkMargin
	local scale = if distance > allowed and distance > 0 then allowed / distance else 1
	return { x = landmark.x + dx * scale, z = landmark.z + dz * scale, radius = radius }
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- `origin` is the starting circle (radius already scaled for player count);
-- `landmark` uses x/z only.
function Zone.at(elapsed: number, config: any, origin: Circle, landmark: Circle): ZoneState
	local phases = config.phases
	local current = phaseCircle(config, 1, origin, landmark)
	local damage = phases[1].damage
	for index = 2, #phases do
		local phase = phases[index]
		if elapsed < phase.at then
			return {
				x = current.x,
				z = current.z,
				radius = current.radius,
				damage = damage,
				shrinking = false,
				nextChangeIn = phase.at - elapsed,
			}
		end
		local target = phaseCircle(config, index, origin, landmark)
		local t = if phase.duration > 0
			then math.clamp((elapsed - phase.at) / phase.duration, 0, 1)
			else 1
		damage = phase.damage
		if t < 1 then
			return {
				x = lerp(current.x, target.x, t),
				z = lerp(current.z, target.z, t),
				radius = lerp(current.radius, target.radius, t),
				damage = damage,
				shrinking = true,
				nextChangeIn = phase.at + phase.duration - elapsed,
			}
		end
		current = target
	end
	return {
		x = current.x,
		z = current.z,
		radius = current.radius,
		damage = damage,
		shrinking = false,
		nextChangeIn = nil,
	}
end

-- The circle a phase will settle on; used to place the relic inside the coming zone.
function Zone.target(elapsed: number, config: any, origin: Circle, landmark: Circle): Circle
	local phases = config.phases
	for index = #phases, 1, -1 do
		if elapsed >= phases[index].at then
			return phaseCircle(config, index, origin, landmark)
		end
	end
	return phaseCircle(config, 1, origin, landmark)
end

function Zone.contains(circle: Circle, x: number, z: number): boolean
	local dx, dz = x - circle.x, z - circle.z
	return dx * dx + dz * dz <= circle.radius * circle.radius
end

return Zone
