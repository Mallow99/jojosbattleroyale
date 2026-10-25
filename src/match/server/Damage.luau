--!strict
-- All damage goes through here so kills can be credited.
local Damage = {}

local CREDIT_WINDOW = 15

local lastHit: { [Humanoid]: { attacker: Player, at: number } } = setmetatable({}, { __mode = "k" }) :: any

-- Finds the Humanoid that owns a part (characters, the boss).
function Damage.humanoidOf(part: Instance): Humanoid?
	local current: Instance? = part.Parent
	while current and current ~= workspace do
		local humanoid = current:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return humanoid
		end
		current = current.Parent
	end
	return nil
end

function Damage.apply(victim: Humanoid, amount: number, attacker: Player?)
	if victim.Health <= 0 or amount <= 0 then
		return
	end
	if attacker then
		lastHit[victim] = { attacker = attacker, at = os.clock() }
	end
	victim:TakeDamage(amount)
end

function Damage.killerOf(victim: Humanoid): Player?
	local hit = lastHit[victim]
	if hit and os.clock() - hit.at <= CREDIT_WINDOW and hit.attacker.Parent then
		return hit.attacker
	end
	return nil
end

return Damage
