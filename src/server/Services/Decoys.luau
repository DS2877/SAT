-- Registry of active Decoy Ducks. Dependency-free so Combat, GadgetService and GuardianService
-- can all share it without circular requires.

local Decoys = {}

export type Decoy = {
	Root: BasePart,
	Owner: Player,
	Pop: (Decoy, Player?) -> (),
}

local active: { Decoy } = {}

function Decoys.Add(decoy: Decoy)
	table.insert(active, decoy)
end

function Decoys.Remove(decoy: Decoy)
	local index = table.find(active, decoy)
	if index then
		table.remove(active, index)
	end
end

function Decoys.Nearest(position: Vector3, range: number): Decoy?
	local best, bestDistance = nil, range
	for _, decoy in active do
		local distance = (decoy.Root.Position - position).Magnitude
		if distance <= bestDistance then
			best, bestDistance = decoy, distance
		end
	end
	return best
end

-- Pops the nearest decoy within range. Returns true if one popped.
function Decoys.PopNear(position: Vector3, range: number, by: Player?): boolean
	local decoy = Decoys.Nearest(position, range)
	if decoy then
		decoy:Pop(by)
		return true
	end
	return false
end

return Decoys
