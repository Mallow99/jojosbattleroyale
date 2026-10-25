--!strict
-- Gameplay rule tests for the pure modules in src/shared. Run: lune run tests/gameplay/run.luau
-- These exercise game rules only; they are not Roblox engine or playtest results.
local Gacha = require("../../src/shared/Logic/Gacha")
local GachaConfig = require("../../src/shared/Config/Gacha")
local DiscSlots = require("../../src/shared/Logic/DiscSlots")
local Channel = require("../../src/shared/Logic/Channel")
local MatchClock = require("../../src/shared/Logic/MatchClock")
local Zone = require("../../src/shared/Logic/Zone")
local Matchmaking = require("../../src/shared/Logic/Matchmaking")
local Rewards = require("../../src/shared/Logic/Rewards")
local Weighted = require("../../src/shared/Logic/Weighted")
local MatchConfig = require("../../src/shared/Config/Match")
local Economy = require("../../src/shared/Config/Economy")
local Stands = require("../../src/shared/Config/Stands")
local Items = require("../../src/shared/Config/Items")

local passed, failed = 0, 0
local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL: " .. name .. "\n  " .. tostring(err))
	end
end
local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-9)
end

-- Seeded stand-in for Roblox's Random.
local function seeded(seed: number)
	math.randomseed(seed)
	return {
		NextNumber = function(_self)
			return math.random()
		end,
	}
end
local function fixed(values: { number })
	local i = 0
	return {
		NextNumber = function(_self)
			i += 1
			return values[(i - 1) % #values + 1]
		end,
	}
end

-- Config integrity --------------------------------------------------------------------
test("every skin belongs to a configured Stand and rarity", function()
	for _, skin in GachaConfig.skins do
		assert(Stands.byId[skin.standId], "unknown stand " .. skin.standId)
		assert(GachaConfig.rates[skin.rarity], "unknown rarity " .. skin.rarity)
	end
end)

test("rarity rates sum to 1", function()
	local total = 0
	for _, rate in GachaConfig.rates do
		total += rate
	end
	assert(near(total, 1), "rates sum to " .. total)
end)

test("limited banner pools and featured skins exist", function()
	for _, banner in GachaConfig.limitedRotation.banners do
		for _, id in banner.pool do
			assert(GachaConfig.skinsById[id], banner.id .. " pool has unknown " .. id)
		end
		for _, id in banner.featured do
			assert(
				table.find(banner.pool, id),
				banner.id .. " features " .. id .. " outside its pool"
			)
		end
	end
end)

test("zone phases are ordered and shrink", function()
	local phases = MatchConfig.zone.phases
	for i = 2, #phases do
		assert(
			phases[i].at >= phases[i - 1].at + phases[i - 1].duration,
			"phase " .. i .. " overlaps"
		)
		assert(phases[i].radius < phases[i - 1].radius, "phase " .. i .. " does not shrink")
	end
	local last = phases[#phases]
	assert(
		last.at + last.duration <= MatchConfig.activationUnlockAt,
		"final circle settles after activation unlocks"
	)
end)

-- Gacha -------------------------------------------------------------------------------
test("standard and rotating limited banner are active", function()
	local epoch = GachaConfig.limitedRotation.epoch
	local period = GachaConfig.limitedRotation.periodSeconds
	local before = Gacha.activeBanners(GachaConfig, epoch - 1)
	assert(#before == 1 and before[1].banner.id == "Standard", "only standard before epoch")
	local first = Gacha.activeBanners(GachaConfig, epoch + 10)
	assert(#first == 2 and first[2].banner.id == "StardustCrusaders", "first limited banner")
	assert(first[2].endsAt == epoch + period, "first banner end time")
	local second = Gacha.activeBanners(GachaConfig, epoch + period)
	assert(second[2].banner.id == "DiamondIsUnbreakable", "rotates after one period")
	local wrapped = Gacha.activeBanners(GachaConfig, epoch + period * 3 + 5)
	assert(wrapped[2].banner.id == "StardustCrusaders", "rotation wraps")
	assert(
		Gacha.findActive(GachaConfig, epoch + period, "StardustCrusaders") == nil,
		"ended banner is not pullable"
	)
end)

test("displayed odds sum to 1 on every banner", function()
	local banners = { GachaConfig.standardBanner }
	for _, banner in GachaConfig.limitedRotation.banners do
		table.insert(banners, banner)
	end
	for _, banner in banners do
		local total = 0
		for _, entry in Gacha.odds(GachaConfig, banner) do
			total += entry.chance
		end
		assert(near(total, 1, 1e-6), banner.id .. " odds sum to " .. total)
	end
end)

test("featured skins get the configured share of their rarity", function()
	local banner = GachaConfig.limitedRotation.banners[3]
	local featured, other = 0, 0
	for _, entry in Gacha.odds(GachaConfig, banner) do
		if entry.rarity == "Legendary" then
			if table.find(banner.featured, entry.skinId) then
				featured += entry.chance
			else
				other += entry.chance
			end
		end
	end
	-- Golden Wind features both of its Legendaries, so they take the whole tier.
	assert(
		other == 0 and near(featured, 0.05, 1e-9),
		"legendary split " .. featured .. "/" .. other
	)
end)

test("hard pity guarantees a Legendary by pull 20", function()
	local state = Gacha.newState()
	-- 0.0 always rolls Common without pity.
	local rng = fixed({ 0 })
	for pull = 1, GachaConfig.hardPity - 1 do
		local result = Gacha.pull(GachaConfig, GachaConfig.standardBanner, state, rng)
		assert(result.rarity == "Common", "pull " .. pull .. " should be Common")
	end
	assert(state.pity.Standard == GachaConfig.hardPity - 1, "pity counter")
	local result = Gacha.pull(GachaConfig, GachaConfig.standardBanner, state, rng)
	assert(result.rarity == "Legendary" and result.pity, "pull 20 must be a pity Legendary")
	assert(state.pity.Standard == 0, "pity resets after Legendary")
end)

test("pity groups are separate per banner group", function()
	local state = Gacha.newState()
	local rng = fixed({ 0 })
	Gacha.pull(GachaConfig, GachaConfig.standardBanner, state, rng)
	Gacha.pull(GachaConfig, GachaConfig.limitedRotation.banners[1], state, rng)
	Gacha.pull(GachaConfig, GachaConfig.limitedRotation.banners[2], state, rng)
	assert(
		state.pity.Standard == 1 and state.pity.Limited == 2,
		"limited pity carries across rotation"
	)
end)

test("duplicates grant shards and crafting spends them", function()
	local state = Gacha.newState()
	local rng = fixed({ 0 })
	local first = Gacha.pull(GachaConfig, GachaConfig.standardBanner, state, rng)
	assert(not first.duplicate and state.owned[first.skinId], "first copy is owned")
	local second = Gacha.pull(GachaConfig, GachaConfig.standardBanner, state, rng)
	assert(
		second.skinId == first.skinId and second.duplicate and state.shards == 1,
		"duplicate shard"
	)
	local ok, reason = Gacha.craft(GachaConfig, state, "StonePlatinum")
	assert(not ok and reason == "Not enough shards", "craft needs shards")
	state.shards = 12
	assert(Gacha.craft(GachaConfig, state, "StonePlatinum"), "craft succeeds")
	assert(state.shards == 0 and state.owned.StonePlatinum, "craft spends and grants")
	assert(not Gacha.craft(GachaConfig, state, "StonePlatinum"), "cannot craft owned skin")
end)

test("limited banner only drops skins from its pool", function()
	local banner = GachaConfig.limitedRotation.banners[2]
	local state = Gacha.newState()
	local rng = seeded(7)
	for _ = 1, 500 do
		local result = Gacha.pull(GachaConfig, banner, state, rng)
		assert(
			table.find(banner.pool, result.skinId),
			"dropped " .. result.skinId .. " outside pool"
		)
	end
end)

test("observed rarity frequencies match rates without pity", function()
	local config = table.clone(GachaConfig)
	config.hardPity = math.huge
	local state = Gacha.newState()
	local rng = seeded(12345)
	local counts = { Common = 0, Rare = 0, Legendary = 0 }
	local n = 20000
	for _ = 1, n do
		local result = Gacha.pull(config, GachaConfig.standardBanner, state, rng)
		counts[result.rarity] += 1
	end
	for rarity, rate in GachaConfig.rates do
		assert(
			math.abs(counts[rarity] / n - rate) < 0.015,
			rarity .. " frequency " .. counts[rarity] / n
		)
	end
end)

-- Discs -------------------------------------------------------------------------------
test("discs fill active then spare, and a third replaces the spare", function()
	local slots = DiscSlots.new()
	local a, b, c =
		DiscSlots.newDisc("1", "StarPlatinum"),
		DiscSlots.newDisc("2", "TheWorld"),
		DiscSlots.newDisc("3", "TheHand")
	assert(DiscSlots.add(slots, a) == "active", "first disc is active")
	assert(DiscSlots.add(slots, b) == "spare", "second disc is spare")
	local slot, replaced = DiscSlots.add(slots, c)
	assert(slot == "spare" and replaced == b and slots.active == a, "third replaces spare")
end)

test("swapping keeps cooldowns with the disc", function()
	local slots = DiscSlots.new()
	local a, b = DiscSlots.newDisc("1", "StarPlatinum"), DiscSlots.newDisc("2", "TheWorld")
	DiscSlots.add(slots, a)
	DiscSlots.add(slots, b)
	DiscSlots.startCooldown(a, "Barrage", 100, 10)
	assert(DiscSlots.swap(slots) and slots.active == b and slots.spare == a, "swap")
	assert(not DiscSlots.isReady(a, "Barrage", 105), "cooldown survives swap")
	assert(DiscSlots.isReady(a, "Barrage", 110), "cooldown expires on time")
	assert(DiscSlots.isReady(b, "Barrage", 100), "other disc unaffected")
end)

test("swap needs a spare, and death drops everything", function()
	local slots = DiscSlots.new()
	DiscSlots.add(slots, DiscSlots.newDisc("1", "StarPlatinum"))
	assert(not DiscSlots.swap(slots), "no swap without spare")
	DiscSlots.add(slots, DiscSlots.newDisc("2", "TheWorld"))
	local dropped = DiscSlots.dropAll(slots)
	assert(#dropped == 2 and slots.active == nil and slots.spare == nil, "drop all")
end)

-- Channel (activation, swap, heal) ----------------------------------------------------
test("activation completes after ten uninterrupted seconds", function()
	local ch =
		Channel.new(0, MatchConfig.activationDuration, MatchConfig.activationMoveTolerance, 100)
	Channel.step(ch, 9.9, 0.5, 100, nil)
	assert(ch.status == "running" and near(Channel.progress(ch, 5), 0.5), "still running")
	Channel.step(ch, 10, 0.5, 100, nil)
	assert(ch.status == "complete", "complete at 10s")
end)

test("activation cancels on movement, damage, death or Stand change", function()
	local cases = {
		{ moved = 4, health = 100, interrupt = nil, reason = "moved" },
		{ moved = 0, health = 99, interrupt = nil, reason = "damaged" },
		{ moved = 0, health = 0, interrupt = nil, reason = "died" },
		{ moved = 0, health = 100, interrupt = "stand changed", reason = "stand changed" },
	}
	for _, case in cases do
		local ch = Channel.new(0, 10, 3, 100)
		Channel.step(ch, 5, case.moved, case.health, case.interrupt)
		assert(ch.status == "cancelled" and ch.reason == case.reason, "expected " .. case.reason)
		Channel.step(ch, 11, 0, 100, nil)
		assert(ch.status == "cancelled", "cancelled channel stays cancelled")
	end
end)

-- Match clock -------------------------------------------------------------------------
test("phases follow the configured schedule", function()
	assert(MatchClock.phase(0, MatchConfig) == "Deploying", "deploying")
	assert(MatchClock.phase(MatchConfig.deployDuration, MatchConfig) == "Looting", "looting")
	assert(MatchClock.phase(12 * 60, MatchConfig) == "RelicRevealed", "relic at 12:00")
	assert(MatchClock.phase(15 * 60, MatchConfig) == "ActivationOpen", "activation at 15:00")
	assert(MatchClock.phase(20 * 60, MatchConfig) == "Ended", "hard limit 20:00")
	local name, inSeconds = MatchClock.nextEvent(700, MatchConfig)
	assert(name == "Requiem Arrow appears" and inSeconds == 20, "next event")
end)

test("only activation wins; last survivor does not win automatically", function()
	assert(not MatchClock.outcome(900, 1, nil, MatchConfig).ended, "last survivor must activate")
	local win = MatchClock.outcome(950, 3, 42, MatchConfig)
	assert(win.ended and win.winner == 42, "activation wins")
	local timeout = MatchClock.outcome(1200, 2, nil, MatchConfig)
	assert(
		timeout.ended and timeout.winner == nil and timeout.reason == "timeout",
		"timeout, no winner"
	)
	assert(MatchClock.outcome(600, 0, nil, MatchConfig).reason == "no survivors", "everyone died")
end)

-- Zone --------------------------------------------------------------------------------
test("zone shrinks on schedule and keeps the landmark inside", function()
	local origin = { x = 0, z = 0, radius = 1000 }
	local landmark = { x = 700, z = 300, radius = 0 }
	local z0 = Zone.at(0, MatchConfig.zone, origin, landmark)
	assert(z0.radius == 1000 and not z0.shrinking, "starts at full size")
	local mid = Zone.at(360, MatchConfig.zone, origin, landmark)
	assert(mid.shrinking and mid.radius < 1000 and mid.radius > 600, "shrinking in phase 2")
	local final = Zone.at(1000, MatchConfig.zone, origin, landmark)
	assert(near(final.radius, 60, 1e-6) and final.nextChangeIn == nil, "final radius")
	for t = 0, 1200, 15 do
		local circle = Zone.at(t, MatchConfig.zone, origin, landmark)
		assert(Zone.contains(circle, landmark.x, landmark.z), "landmark outside zone at " .. t)
	end
end)

test("zone target matches the settled circle", function()
	local origin = { x = 0, z = 0, radius = 1000 }
	local landmark = { x = 100, z = 0, radius = 0 }
	local target = Zone.target(500, MatchConfig.zone, origin, landmark)
	local settled = Zone.at(600, MatchConfig.zone, origin, landmark)
	assert(
		near(target.radius, settled.radius) and near(target.x, settled.x),
		"target equals settled phase"
	)
end)

-- Matchmaking -------------------------------------------------------------------------
local function entries(n: number, joinedAt: number)
	local list = {}
	for i = 1, n do
		table.insert(list, { userId = i, joinedAt = joinedAt + i * 0.01 })
	end
	return list
end

test("matchmaking starts at 32 immediately", function()
	local decision = Matchmaking.decide(entries(40, 0), 1, MatchConfig)
	assert(decision.start and #decision.userIds == 32 and decision.areaScale == 1, "full match")
	assert(decision.userIds[1] == 1 and decision.userIds[32] == 32, "oldest entries first")
end)

test("matchmaking waits two minutes before a reduced match", function()
	assert(not Matchmaking.decide(entries(20, 0), 60, MatchConfig).start, "waits for more players")
	local reduced = Matchmaking.decide(entries(20, 0), 121, MatchConfig)
	assert(
		reduced.start and #reduced.userIds == 20 and near(reduced.areaScale, 20 / 32),
		"reduced match"
	)
	assert(not Matchmaking.decide(entries(11, 0), 999, MatchConfig).start, "below 12 keeps waiting")
	local small = Matchmaking.decide(entries(12, 0), 121, MatchConfig)
	assert(small.areaScale == MatchConfig.minAreaScale, "area scale floor")
end)

test("development bypass is explicit", function()
	assert(not Matchmaking.decide(entries(1, 0), 1, MatchConfig).start, "no bypass by default")
	assert(Matchmaking.decide(entries(1, 0), 1, MatchConfig, true).start, "bypass starts with one")
end)

-- Rewards and loot --------------------------------------------------------------------
test("rewards: one pull per qualifying match, one more for winning", function()
	local cost = GachaConfig.pullCost
	assert(
		Rewards.coins({ qualified = true, won = false, eliminations = 3 }, Economy) == cost,
		"match reward"
	)
	assert(
		Rewards.coins({ qualified = true, won = true, eliminations = 0 }, Economy) == cost * 2,
		"win bonus"
	)
	assert(
		Rewards.coins({ qualified = false, won = false, eliminations = 5 }, Economy) == 0,
		"left early"
	)
end)

test("weighted pick respects weights and every loot kind is reachable", function()
	local seen = {}
	for roll = 0, 0.999, 0.01 do
		local entry = Weighted.pick(Items.lootWeights, function(e)
			return e.weight
		end, roll)
		seen[entry.kind] = true
	end
	for _, entry in Items.lootWeights do
		assert(seen[entry.kind], entry.kind .. " never picked")
	end
	local first = Weighted.pick(Items.lootWeights, function(e)
		return e.weight
	end, 0)
	assert(first.kind == Items.lootWeights[1].kind, "roll 0 picks first entry")
end)

print(
	string.format(
		"%d passed, %d failed (gameplay rule tests; not Roblox engine tests)",
		passed,
		failed
	)
)
if failed > 0 then
	error("gameplay tests failed")
end
