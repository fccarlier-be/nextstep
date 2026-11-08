local wow = require("wow")

-- Sacs et banque (Modules/UI/Inventory.lua).

-- Conteneurs simulés : world.bags[sac] = { [emplacement] = { id, count, quality, link } }.
local function install(world)
    _G.C_Container = {
        GetContainerNumSlots = function(bag) return world.bags[bag] and 4 or 0 end,
        GetContainerItemInfo = function(bag, slot)
            local item = world.bags[bag] and world.bags[bag][slot]
            return item and { itemID = item.id, stackCount = item.count or 1, quality = item.quality or 1,
                hyperlink = item.link, hasNoValue = false }
        end,
    }
    _G.GetRealmName = function() return "Forever" end
    _G.UnitName = function() return world.name end
end

local function boot(world, saved)
    world.name = world.name or "Beorn"
    local game = wow.boot({ saved = saved, beforeInit = function() install(world) end })
    return game, game.ns.Modules:Get("Inventory")
end

describe("Sacs et banque", function()
    it("retient les sacs, et la banque à chaque visite", function()
        local world = { bags = { [0] = { { id = 2589, count = 12 }, { id = 2589, count = 8 } }, [-1] = {
            { id = 2589, count = 20 }, { id = 4306, count = 5 } } } }
        local game, inventory = boot(world)
        game:fire("BAG_UPDATE_DELAYED")
        local me = inventory.db.characters["Beorn - Forever"]
        expect_eq(me.bags[2589], 20, "deux piles additionnées")
        expect_eq(next(me.bank), nil, "banque pas encore vue")
        game:fire("BANKFRAME_OPENED")
        expect_eq(me.bank[2589], 20)
        expect_eq(me.bank[4306], 5)
        expect(me.bankTime, "date de la visite")
        expect_eq(me.freeSlots, 2, "places libres du sac à dos (4 places, 2 prises)")
        expect_eq(#game.errors, 0)
    end)

    it("compte les objets de tous les personnages dans l'infobulle", function()
        local world = { bags = { [0] = { { id = 2589, count = 3 } } } }
        local game, inventory = boot(world)
        game:fire("BAG_UPDATE_DELAYED")
        local saved = wow.saved()
        local world2 = { name = "Thrall", bags = { [0] = { { id = 2589, count = 7 } } } }
        local game2, inventory2 = boot(world2, saved)
        game2:fire("BAG_UPDATE_DELAYED")
        local lines = inventory2:TooltipLines(2589)
        local text = table.concat(lines, " | ")
        expect(text:find("Beorn : 3", 1, true), text)
        expect(text:find("Thrall : 7", 1, true), text)
        expect(text:find("Total: 10", 1, true), text)
        expect_eq(#inventory:TooltipLines(9999), 0)
        expect_eq(#game.errors + #game2.errors, 0)
    end)

    it("marque la camelote et les améliorations", function()
        local world = { bags = { [0] = { { id = 100, quality = 0 }, { id = 200, quality = 2, link = "item:200" } } } }
        local game, inventory = boot(world)
        local _, junk = inventory:MarksFor(0, 1)
        expect(junk, "objet gris : camelote")
        game.ns.Modules:Get("Junk").db.keep[100] = true
        _, junk = inventory:MarksFor(0, 1)
        expect(not junk, "exception de la camelote")
        game.ns.Score.IsUpgrade = function() return true end
        local upgrade = inventory:MarksFor(0, 2)
        expect(upgrade, "amélioration d'après le module Items")
        expect_eq(#game.errors, 0)
    end)

    it("montre les sacs et la banque d'un personnage, avec une recherche", function()
        local world = { bags = { [0] = { { id = 2589, count = 3 } }, [-1] = { { id = 4306, count = 5 } } } }
        local game, inventory = boot(world)
        _G.C_Item.GetItemInfo = function(id)
            local names = { [2589] = "Linen Cloth", [4306] = "Silk Cloth" }
            return names[id], nil, 1
        end
        game:fire("BAG_UPDATE_DELAYED")
        game:fire("BANKFRAME_OPENED")
        local rows = inventory:ViewRows("Beorn - Forever")
        local texts = {}
        for _, row in ipairs(rows) do
            texts[#texts + 1] = row.text
        end
        local all = table.concat(texts, " | ")
        expect(all:find("Linen Cloth", 1, true) and all:find("Silk Cloth", 1, true), all)
        rows = inventory:ViewRows("Beorn - Forever", "silk")
        texts = {}
        for _, row in ipairs(rows) do
            texts[#texts + 1] = row.text
        end
        all = table.concat(texts, " | ")
        expect(not all:find("Linen", 1, true) and all:find("Silk", 1, true), "recherche : " .. all)
        SlashCmdList.NEXTSTEP("bank")
        expect_eq(#game.errors, 0)
    end)
end)
