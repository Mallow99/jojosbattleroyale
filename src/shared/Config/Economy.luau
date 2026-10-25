--!strict
-- Earned currency. A match qualifies if the player was in it at the start and did not
-- leave before being eliminated or the match ending.
return table.freeze({
	currencyName = "Coins",
	matchReward = 100,
	winBonus = 100,
	eliminationReward = 0,
	-- Studio only: temporary (unsaved) profiles start with this many coins for testing.
	studioTestCoins = 2000,
})
