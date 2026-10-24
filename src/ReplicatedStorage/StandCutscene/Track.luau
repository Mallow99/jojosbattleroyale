--!strict
-- Keyframe track sampling for cutscene numbers and camera shots. Pure CFrame math, so the
-- same code drives Roblox playback and the Lune preview/tests.

local Track = {}

Track.EASES = {
	linear = function(x: number): number
		return x
	end,
	sineInOut = function(x: number): number
		return -(math.cos(math.pi * x) - 1) / 2
	end,
	sineOut = function(x: number): number
		return math.sin(x * math.pi / 2)
	end,
	quadIn = function(x: number): number
		return x * x
	end,
	quadOut = function(x: number): number
		return 1 - (1 - x) * (1 - x)
	end,
	cubicOut = function(x: number): number
		return 1 - (1 - x) ^ 3
	end,
	cubicInOut = function(x: number): number
		return if x < 0.5 then 4 * x ^ 3 else 1 - (-2 * x + 2) ^ 3 / 2
	end,
	expoOut = function(x: number): number
		return if x >= 1 then 1 else 1 - 2 ^ (-10 * x)
	end,
	backOut = function(x: number): number
		local c1 = 1.70158
		return 1 + (c1 + 1) * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
	end,
	-- Holds the previous key until the next key's time: a camera cut.
	step = function(x: number): number
		return if x >= 1 then 1 else 0
	end,
}

-- Returns the surrounding keys and the eased blend. The ease is read from `easeIndex` on the
-- later key (default sineInOut).
function Track.locate(keys: { { any } }, t: number, easeIndex: number): ({ any }, { any }, number)
	local count = #keys
	if t <= keys[1][1] then
		return keys[1], keys[1], 0
	end
	if t >= keys[count][1] then
		return keys[count], keys[count], 0
	end
	for index = 2, count do
		local key = keys[index]
		if t <= key[1] then
			local previous = keys[index - 1]
			local span = key[1] - previous[1]
			local alpha = if span > 0 then (t - previous[1]) / span else 1
			local ease = Track.EASES[key[easeIndex] or "sineInOut"]
			assert(ease, "unknown ease " .. tostring(key[easeIndex]))
			return previous, key, ease(alpha)
		end
	end
	return keys[count], keys[count], 0
end

function Track.number(keys: { { any } }, t: number): number
	local a, b, alpha = Track.locate(keys, t, 3)
	return a[2] + (b[2] - a[2]) * alpha
end

-- Camera in anchor space and field of view at time t.
function Track.camera(keys: { { any } }, t: number): (CFrame, number)
	local a, b, alpha = Track.locate(keys, t, 5)
	local eye = (a[2] :: Vector3):Lerp(b[2], alpha)
	local target = (a[3] :: Vector3):Lerp(b[3], alpha)
	return CFrame.lookAt(eye, target), a[4] + (b[4] - a[4]) * alpha
end

-- Deterministic shake offset (no randomness, so previews match playback).
function Track.shake(t: number, amplitude: number): CFrame
	if amplitude <= 0 then
		return CFrame.new()
	end
	local x = math.sin(t * 61.3) * 0.6 + math.sin(t * 37.9 + 1.7) * 0.4
	local y = math.sin(t * 53.1 + 0.4) * 0.6 + math.sin(t * 29.3 + 2.9) * 0.4
	local r = math.sin(t * 47.7 + 0.9)
	return CFrame.new(x * amplitude * 0.25, y * amplitude * 0.25, 0)
		* CFrame.Angles(y * amplitude * 0.03, x * amplitude * 0.03, r * amplitude * 0.04)
end

-- Camera world CFrame and FOV, easing back to `returnCamera` during the outro when given.
function Track.cameraWorld(
	shots: any,
	t: number,
	anchor: CFrame,
	returnCamera: CFrame?,
	returnFov: number?
): (CFrame, number)
	local localCamera, fov
	local window = shots.cameraReturn
	if t > window.from then
		local base, baseFov = Track.camera(shots.camera, window.from)
		local alpha =
			Track.EASES.sineInOut(math.clamp((t - window.from) / (window.to - window.from), 0, 1))
		-- Without a player camera (previews), pull back behind the user.
		local target = returnCamera
			or anchor * CFrame.lookAt(Vector3.new(0, 6.5, 11), Vector3.new(0, 3.5, 0))
		localCamera = anchor:Inverse() * (anchor * base):Lerp(target, alpha)
		fov = baseFov + ((returnFov or 70) - baseFov) * alpha
	else
		localCamera, fov = Track.camera(shots.camera, t)
	end
	return anchor * localCamera * Track.shake(t, Track.number(shots.tracks.shake, t)), fov
end

return Track
