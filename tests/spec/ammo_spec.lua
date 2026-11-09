local wow = require("wow")

-- Munitions du chasseur (Modules/Items/Ammo.lua).

-- Objets simulés : classe et sous-classe (2 arme : 2 arc, 3 fusil ; 6 projectile :
-- 2 flèche, 3 balle).
local ITEMS = {
    [2504] = { 2, 2 },     -- arc
    [2508] = { 2, 3 },     -- fusil
    [2512] = { 6, 2 },     -- flèche grossière
    [2516] = { 6, 3 },     -- balle légère
    [117] = { 0, 0 },      -- viande
}

-- Ghrawt, archer de Razor Hill (Horde) : 1, 362, -4764 dans les données importées.
local RAZOR_HILL = { 362 + 30, -4764 + 40, 1 }

local function install(world)
    _G.C_Container = {
        GetContainerNumSlots = function(bag) return bag == 0 and 8 or 0 end,
        GetContainerItemInfo = function(bag, slot)
            local item = bag == 0 and world.bags[slot]
            return item and { itemID = item[1], stackCount = item[2] }
        end,
    }
    _G.C_Item.GetItemInfoInstant = function(item)
        local info = ITEMS[item]
        if info then
            return item, nil, nil, nil, nil, info[1], info[2]
        end
    end
    _G.GetInventoryItemID = function(_, slot)
        return slot == 18 and world.ranged or nil
    end
    _G.GetMerchantNumItems = function() return #(world.merchant or {}) end
    _G.GetMerchantItemID = function(i) return world.merchant[i] end
    _G.C_Map.GetPlayerMapPosition = function()
        return { GetXY = function() return 0.5, 0.25 end }
    end
end

local function boot(world, options)
    options = options or {}
    world.bags = world.bags or {}
    local game = wow.boot({
        faction = options.faction or "Horde",
        saved = options.saved,
        player = { class = options.class or "HUNTER", level = options.level or 12, position = RAZOR_HILL,
            map = 1411 },
        beforeInit = function() install(world) end,
    })
    return game, game.ns.Modules:Get("Ammo")
end

describe("Munitions du chasseur", function()
    it("lit les vendeurs importés", function()
        local _, ammo = boot({})
        local ghrawt = ammo.Imported()[3165]
        expect(ghrawt, "Ghrawt importé")
        expect_eq(ghrawt.kinds, "a")
        expect_eq(ghrawt.faction, "H")
        expect_eq(ghrawt.instance, 1)
        expect_eq(ghrawt.name, "Ghrawt")
        expect(ghrawt.map and ghrawt.x and ghrawt.y, "point sur la carte du client")
    end)

    it("alerte quand les flèches passent sous le seuil, puis quand il n'y en a plus", function()
        local world = { ranged = 2504, bags = { { 2512, 150 }, { 117, 5 } } }
        local game, ammo = boot(world)
        game:fire("BAG_UPDATE_DELAYED")
        expect(ammo.alert and ammo.alert:IsShown() ~= false, "alerte affichée")
        expect_eq(ammo.alertVendor and ammo.alertVendor.npc, 3165, "Ghrawt, le plus proche")
        expect(ammo.alert.title.text:find("150", 1, true), "nombre restant")
        expect(ammo.alert.vendor.text:find("Ghrawt", 1, true), "vendeur nommé")
        expect(ammo.alert.buy.text:find("Sharp Arrow", 1, true), "flèche du niveau 10")
        local shown = #game.chat
        game:fire("BAG_UPDATE_DELAYED")
        expect_eq(#game.chat, shown, "pas de nouvelle alerte au même niveau")
        world.bags[1] = nil
        game:fire("BAG_UPDATE_DELAYED")
        expect_eq(#game.chat, shown + 1, "nouvelle alerte : plus de flèches")
        expect(ammo.alert.title.text:find("Out of arrows", 1, true))
        world.bags[1] = { 2512, 1000 }
        game:fire("BAG_UPDATE_DELAYED")
        expect_eq(ammo.warned, 0, "réarmée après le plein")
        expect_eq(#game.errors, 0)
    end)

    it("pointe la flèche du guide sur le vendeur", function()
        local world = { ranged = 2504, bags = { { 2512, 10 } } }
        local game, ammo = boot(world)
        game:fire("BAG_UPDATE_DELAYED")
        local guide = game.ns.Modules:Get("Guide")
        local pointed
        guide.PointTo = function(_, point, label)
            pointed = { point = point, label = label }
        end
        expect(ammo:PointToVendor(), "vendeur pointable")
        expect_eq(pointed.point.map, ammo.Imported()[3165].map)
        expect(pointed.label:find("Ghrawt", 1, true))
    end)

    it("attend la fin du combat", function()
        local world = { ranged = 2504, bags = { { 2512, 10 } } }
        local game, ammo = boot(world)
        game.inCombat = true
        game:fire("BAG_UPDATE_DELAYED")
        expect(not ammo.alert, "rien en combat")
        game.inCombat = false
        game:fire("PLAYER_REGEN_ENABLED")
        expect(ammo.alert, "affichée après le combat")
    end)

    it("ne concerne que le chasseur armé d'un arc, d'une arbalète ou d'un fusil", function()
        local _, warrior = boot({ ranged = 2504, bags = { { 2512, 10 } } }, { class = "WARRIOR" })
        warrior:Check()
        expect(not warrior.alert, "pas pour un guerrier")
        local _, unarmed = boot({ bags = { { 2512, 10 } } })
        unarmed:Check()
        expect(not unarmed.alert, "pas sans arme à distance")
    end)

    it("ne propose pas les vendeurs de l'autre faction", function()
        local _, ammo = boot({ ranged = 2504 }, { faction = "Alliance" })
        for _, vendor in ipairs(ammo:Vendors("a")) do
            expect(vendor.npc ~= 3165, "Ghrawt est de la Horde")
        end
    end)

    it("apprend ce que vend un marchand", function()
        local world = { ranged = 2508, bags = { { 2516, 10 } }, merchant = { 2512, 117 } }
        local game, ammo = boot(world)
        game:setUnit("npc", { guid = "Creature-0-1-1-1-3165-0000000001", name = "Ghrawt" })
        game:fire("MERCHANT_SHOW")
        local learned = ammo.db.vendors[3165]
        expect(learned, "Ghrawt retenu")
        expect_eq(learned.a, true)
        expect_eq(learned.b, false)
        for _, vendor in ipairs(ammo:Vendors("b")) do
            expect(vendor.npc ~= 3165, "Ghrawt ne vend pas de balles")
        end
        -- Un marchand inconnu de l'import, qui vend des balles.
        world.merchant = { 2516 }
        game:setUnit("npc", { guid = "Creature-0-1-1-1-99999-0000000002", name = "Bob" })
        game:fire("MERCHANT_SHOW")
        local vendor = ammo:Nearest("b")
        expect_eq(vendor and vendor.npc, 99999, "le marchand vu, à l'endroit du joueur")
        expect_eq(vendor.confirmed, true)
        expect_eq(vendor.x, 50)
        expect_eq(#game.errors, 0)
    end)
end)
