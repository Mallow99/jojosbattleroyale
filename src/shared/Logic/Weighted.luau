--!strict
-- Weighted random choice over `{ weight: number }` entries.
local Weighted = {}

function Weighted.pick<T>(entries: { T }, weightOf: (T) -> number, roll: number): T
	local total = 0
	for _, entry in entries do
		total += weightOf(entry)
	end
	local target = roll * total
	local cumulative = 0
	for _, entry in entries do
		cumulative += weightOf(entry)
		if target < cumulative then
			return entry
		end
	end
	return entries[#entries]
end

return Weighted
