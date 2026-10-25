--!strict
-- A timed action that must not be interrupted: Requiem Arrow activation, disc swaps
-- and healing. The caller reports movement, health and interruptions every step.
local Channel = {}

export type Channel = {
	duration: number,
	startedAt: number,
	moveTolerance: number,
	startHealth: number,
	status: "running" | "complete" | "cancelled",
	reason: string?,
}

function Channel.new(now: number, duration: number, moveTolerance: number, health: number): Channel
	return {
		duration = duration,
		startedAt = now,
		moveTolerance = moveTolerance,
		startHealth = health,
		status = "running",
		reason = nil,
	}
end

function Channel.progress(channel: Channel, now: number): number
	return math.clamp((now - channel.startedAt) / channel.duration, 0, 1)
end

-- `moved` is the distance from where the channel started. `interrupted` is any other
-- cancel reason (death, Stand change) or nil.
function Channel.step(
	channel: Channel,
	now: number,
	moved: number,
	health: number,
	interrupted: string?
): Channel
	if channel.status ~= "running" then
		return channel
	end
	local reason = interrupted
	if reason == nil and health <= 0 then
		reason = "died"
	elseif reason == nil and health < channel.startHealth then
		reason = "damaged"
	elseif reason == nil and moved > channel.moveTolerance then
		reason = "moved"
	end
	if reason then
		channel.status = "cancelled"
		channel.reason = reason
	elseif now - channel.startedAt >= channel.duration then
		channel.status = "complete"
	end
	return channel
end

return Channel
