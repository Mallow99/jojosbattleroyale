--!strict
-- At most one uninterruptible action per player (disc swap, heal, activation).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Channel = require(Shared.Logic.Channel)
local MatchState = require(script.Parent.MatchState)

local Channels = {}

type Callbacks = { onComplete: (() -> ())?, onCancel: ((reason: string) -> ())? }
type Active = {
	kind: string,
	channel: Channel.Channel,
	origin: Vector3,
	callbacks: Callbacks,
	interrupt: string?,
}

local active: { [Player]: Active } = {}
local event = Net.event("Channel")

function Channels.busy(player: Player): boolean
	return active[player] ~= nil
end

function Channels.kind(player: Player): string?
	local entry = active[player]
	return if entry then entry.kind else nil
end

function Channels.start(
	player: Player,
	kind: string,
	duration: number,
	moveTolerance: number,
	callbacks: Callbacks
): boolean
	local root, humanoid = MatchState.rootOf(player), MatchState.humanoidOf(player)
	if active[player] or not root or not humanoid or humanoid.Health <= 0 then
		return false
	end
	active[player] = {
		kind = kind,
		channel = Channel.new(os.clock(), duration, moveTolerance, humanoid.Health),
		origin = root.Position,
		callbacks = callbacks,
		interrupt = nil,
	}
	event:FireClient(player, { kind = kind, duration = duration })
	return true
end

-- Cancels the player's channel on the next step.
function Channels.interrupt(player: Player, reason: string)
	local entry = active[player]
	if entry then
		entry.interrupt = reason
	end
end

function Channels.step()
	local now = os.clock()
	for player, entry in active do
		local root, humanoid = MatchState.rootOf(player), MatchState.humanoidOf(player)
		local interrupt = entry.interrupt
		if not root or not humanoid or player.Parent == nil then
			interrupt = interrupt or "died"
		end
		local moved = if root then (root.Position - entry.origin).Magnitude else 0
		local health = if humanoid then humanoid.Health else 0
		Channel.step(entry.channel, now, moved, health, interrupt)
		local status = entry.channel.status
		if status ~= "running" then
			active[player] = nil
			if player.Parent then
				event:FireClient(player, {
					kind = entry.kind,
					done = true,
					status = status,
					reason = entry.channel.reason,
				})
			end
			if status == "complete" and entry.callbacks.onComplete then
				task.spawn(entry.callbacks.onComplete)
			elseif status == "cancelled" and entry.callbacks.onCancel then
				task.spawn(entry.callbacks.onCancel, entry.channel.reason or "cancelled")
			end
		end
	end
end

function Channels.clear(player: Player)
	active[player] = nil
end

return Channels
