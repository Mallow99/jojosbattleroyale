--!strict
-- Currency earned from one match.
local Rewards = {}

export type MatchResult = { qualified: boolean, won: boolean, eliminations: number }

function Rewards.coins(result: MatchResult, economy: any): number
	if not result.qualified then
		return 0
	end
	local coins = economy.matchReward + result.eliminations * economy.eliminationReward
	if result.won then
		coins += economy.winBonus
	end
	return coins
end

return Rewards
