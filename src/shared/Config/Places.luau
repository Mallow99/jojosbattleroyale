--!strict
-- Experience wiring. Leave ids nil until the private development experience exists;
-- with nil ids the lobby reports that matches must be tested by opening the match place.
local Places: {
	lobbyPlaceId: number?,
	matchPlaceId: number?,
	purchasesEnabled: boolean,
	coinProducts: { { productId: number?, coins: number } },
} =
	{
		lobbyPlaceId = nil,
		matchPlaceId = nil,
		-- Real purchases stay disabled until persistence and receipt handling are verified.
		purchasesEnabled = false,
		coinProducts = {
			{ productId = nil, coins = 500 },
			{ productId = nil, coins = 1200 },
		},
	}

return table.freeze(Places)
