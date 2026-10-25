--!strict
-- Match phases from elapsed time, and the end-of-match decision.
local MatchClock = {}

export type Phase = "Deploying" | "Looting" | "RelicRevealed" | "ActivationOpen" | "Ended"

function MatchClock.phase(elapsed: number, config: any): Phase
	if elapsed >= config.hardLimit then
		return "Ended"
	elseif elapsed >= config.activationUnlockAt then
		return "ActivationOpen"
	elseif elapsed >= config.relicRevealAt then
		return "RelicRevealed"
	elseif elapsed < config.deployDuration then
		return "Deploying"
	end
	return "Looting"
end

-- Seconds until the next scheduled phase change, and its name. nil after the hard limit.
function MatchClock.nextEvent(elapsed: number, config: any): (string?, number?)
	local events: { { name: string, at: number } } = {
		{ name = "Drop ends", at = config.deployDuration },
		{ name = "Requiem Arrow appears", at = config.relicRevealAt },
		{ name = "Activation unlocks", at = config.activationUnlockAt },
		{ name = "Time limit", at = config.hardLimit },
	}
	for _, event in events do
		if elapsed < event.at then
			return event.name, event.at - elapsed
		end
	end
	return nil, nil
end

export type Outcome = { ended: boolean, winner: number?, reason: string? }

-- Victory only comes from a completed activation. A last survivor must still activate;
-- the hard limit or everyone dying ends the match with no winner.
function MatchClock.outcome(
	elapsed: number,
	alive: number,
	activatedBy: number?,
	config: any
): Outcome
	if activatedBy then
		return { ended = true, winner = activatedBy, reason = "activated" }
	elseif elapsed >= config.hardLimit then
		return { ended = true, winner = nil, reason = "timeout" }
	elseif alive <= 0 then
		return { ended = true, winner = nil, reason = "no survivors" }
	end
	return { ended = false, winner = nil, reason = nil }
end

return MatchClock
