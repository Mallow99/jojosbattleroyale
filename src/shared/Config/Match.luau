--!strict
-- Match pacing and rules. Times are seconds since the match started (deploy start).
local Match = {
	maxPlayers = 32,
	minPlayers = 12,
	-- After this long in queue, a match may start with minPlayers..maxPlayers-1.
	fullQueueWait = 120,
	-- Smallest starting-zone scale used when a match starts below maxPlayers.
	minAreaScale = 0.6,

	-- Match servers wait this long for teleported players before starting anyway.
	arrivalTimeout = 45,
	-- Studio development bypass: start with any number of players after this delay.
	studioStartDelay = 5,

	deployDuration = 40,
	deployAltitude = 900,
	glideFallSpeed = 45,
	glideMaxTime = 30,

	relicRevealAt = 12 * 60,
	activationUnlockAt = 15 * 60,
	hardLimit = 20 * 60,

	activationDuration = 10,
	activationRadius = 18,
	activationMoveTolerance = 3,

	discSwapDuration = 3,
	channelMoveTolerance = 2,

	endScreenDuration = 20,
	stateBroadcastInterval = 1,

	-- Final landmark: the district the activation spot is built in (see map/Districts).
	finalLandmarkDistrict = "The Bar",

	boss = {
		enabled = true,
		standId = "ChariotRequiem",
		displayName = "Silver Chariot Requiem",
		maxHealth = 1500,
		damage = 18,
		attackRange = 8,
		attackCooldown = 1.2,
		moveSpeed = 18,
		aggroRadius = 60,
		leashRadius = 90,
	},

	zone = {
		-- Starting circle: centered on the loot-spawn centroid of the town. The wall is one
		-- Part, so the diameter must stay under Roblox's 2048-stud part size limit.
		startRadius = 1000,
		-- The landmark is kept within this fraction of every phase's radius.
		landmarkMargin = 0.8,
		-- Each phase holds the previous circle until `at`, then shrinks over `duration`.
		phases = {
			{ at = 0, duration = 0, radius = 1.0, damage = 1 },
			{ at = 300, duration = 120, radius = 0.6, damage = 2 },
			{ at = 480, duration = 120, radius = 0.35, damage = 4 },
			{ at = 660, duration = 120, radius = 0.18, damage = 6 },
			{ at = 840, duration = 60, radius = 0.06, damage = 10 },
		},
	},
}

return table.freeze(Match)
