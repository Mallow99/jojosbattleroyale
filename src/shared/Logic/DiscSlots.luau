--!strict
-- One active Stand disc and one spare. Cooldowns live on the disc, so they carry over
-- while it is stored, dropped or picked up by someone else.
local DiscSlots = {}

export type Disc = { uid: string, standId: string, cooldowns: { [string]: number } }
export type Slots = { active: Disc?, spare: Disc? }

function DiscSlots.new(): Slots
	return { active = nil, spare = nil }
end

function DiscSlots.newDisc(uid: string, standId: string): Disc
	return { uid = uid, standId = standId, cooldowns = {} }
end

-- Adds a found disc. Fills the active slot, then the spare. With both full the spare is
-- replaced and returned so the caller can drop it in the world.
function DiscSlots.add(slots: Slots, disc: Disc): (string, Disc?)
	if slots.active == nil then
		slots.active = disc
		return "active", nil
	elseif slots.spare == nil then
		slots.spare = disc
		return "spare", nil
	end
	local replaced = slots.spare
	slots.spare = disc
	return "spare", replaced
end

function DiscSlots.canSwap(slots: Slots): boolean
	return slots.spare ~= nil
end

function DiscSlots.swap(slots: Slots): boolean
	if slots.spare == nil then
		return false
	end
	slots.active, slots.spare = slots.spare, slots.active
	return true
end

function DiscSlots.dropSpare(slots: Slots): Disc?
	local disc = slots.spare
	slots.spare = nil
	return disc
end

function DiscSlots.dropAll(slots: Slots): { Disc }
	local dropped = {}
	for _, key in { "active", "spare" } do
		local disc = (slots :: any)[key]
		if disc then
			table.insert(dropped, disc)
		end
	end
	slots.active = nil
	slots.spare = nil
	return dropped
end

function DiscSlots.isReady(disc: Disc, ability: string, now: number): boolean
	return (disc.cooldowns[ability] or 0) <= now
end

function DiscSlots.startCooldown(disc: Disc, ability: string, now: number, duration: number)
	disc.cooldowns[ability] = now + duration
end

return DiscSlots
