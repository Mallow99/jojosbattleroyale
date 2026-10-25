--!strict
-- Shared mutable state for one match, so services can read it without requiring each other.
export type Participant = {
	userId: number,
	name: string,
	alive: boolean,
	leftEarly: boolean,
	placement: number?,
	eliminations: number,
}

local MatchState = {
	matchId = "",
	expected = nil :: number?,
	areaScale = 1,
	started = false,
	ended = false,
	startedAt = 0,
	phase = "Waiting",
	participants = {} :: { [number]: Participant },
	winner = nil :: number?,
	relicRevealed = false,
	activationOpen = false,
	carrier = nil :: Player?,
	-- Studio-only speed-up for testing late-match phases (workspace attribute DevTimeScale).
	timeScale = 1,
}

function MatchState.elapsed(): number
	if not MatchState.started then
		return 0
	end
	return (os.clock() - MatchState.startedAt) * MatchState.timeScale
end

function MatchState.isAlive(player: Player): boolean
	local participant = MatchState.participants[player.UserId]
	return participant ~= nil and participant.alive and not MatchState.ended
end

function MatchState.aliveCount(): number
	local count = 0
	for _, participant in MatchState.participants do
		if participant.alive then
			count += 1
		end
	end
	return count
end

function MatchState.alivePlayers(): { Player }
	local list = {}
	for userId, participant in MatchState.participants do
		local player = game:GetService("Players"):GetPlayerByUserId(userId)
		if participant.alive and player then
			table.insert(list, player)
		end
	end
	return list
end

function MatchState.rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

function MatchState.humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

return MatchState
