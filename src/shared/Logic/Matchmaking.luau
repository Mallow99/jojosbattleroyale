--!strict
-- Decides when a queue becomes a match.
local Matchmaking = {}

export type Entry = { userId: number, joinedAt: number }
export type Decision = { start: boolean, userIds: { number }, areaScale: number }

local function sorted(entries: { Entry }): { Entry }
	local copy = table.clone(entries)
	table.sort(copy, function(a, b)
		if a.joinedAt == b.joinedAt then
			return a.userId < b.userId
		end
		return a.joinedAt < b.joinedAt
	end)
	return copy
end

-- Starting-zone scale for a match of `count` players.
function Matchmaking.areaScale(count: number, config: any): number
	return math.clamp(count / config.maxPlayers, config.minAreaScale, 1)
end

-- Full match at maxPlayers. After the oldest entry waited fullQueueWait, start with at
-- least minPlayers. `devBypass` starts with anyone queued (explicit development use).
function Matchmaking.decide(
	entries: { Entry },
	now: number,
	config: any,
	devBypass: boolean?
): Decision
	local queue = sorted(entries)
	local count = 0
	local oldestWait = if #queue > 0 then now - queue[1].joinedAt else 0
	if #queue >= config.maxPlayers then
		count = config.maxPlayers
	elseif #queue >= config.minPlayers and oldestWait >= config.fullQueueWait then
		count = #queue
	elseif devBypass and #queue > 0 then
		count = math.min(#queue, config.maxPlayers)
	end
	local userIds = {}
	for i = 1, count do
		table.insert(userIds, queue[i].userId)
	end
	return {
		start = count > 0,
		userIds = userIds,
		areaScale = Matchmaking.areaScale(math.max(count, 1), config),
	}
end

return Matchmaking
