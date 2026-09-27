-- ✨ ASCENSION SHOP (the boutique beside the spawn): premium weapons, each behind an Ascension
-- level, kept when you Ascend again. Same list UI as the Gadget Shop (Menus/Shop).

local Shop = require(script.Parent.Shop)

local AscensionShop = {}

function AscensionShop.Build(root: Frame)
	return Shop.BuildList(root, true)
end

return AscensionShop
