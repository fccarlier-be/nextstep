local wow = require("wow")

-- Camelote (Modules/UI/Junk.lua) : vente des objets gris chez le marchand.

-- Sacs simulés : [sac] = { [emplacement] = { itemID, quality, count, noValue } } ;
-- world.sold : objets vendus (UseContainerItem), world.prices : [objet] = prix.
local function installBags(world)
    world.sold = {}
    _G.C_Container = {
        GetContainerNumSlots = function(bag) return world.bags[bag] and 16 or 0 end,
        GetContainerItemInfo = function(bag, slot)
            local item = world.bags[bag] and world.bags[bag][slot]
            if not item then
                return nil
            end
            return { itemID = item.id, quality = item.quality, stackCount = item.count or 1,
                hasNoValue = item.noValue or false }
        end,
        UseContainerItem = function(bag, slot)
            world.sold[#world.sold + 1] = world.bags[bag][slot].id
            world.bags[bag][slot] = nil
        end,
    }
    _G.C_Item = { GetItemInfo = function(id)
        return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, world.prices[id] or 0
    end }
end

local function boot(world)
    local game = wow.boot({
        beforeInit = function()
            installBags(world)
        end,
    })
    return game, game.ns.Modules:Get("Junk")
end

describe("Camelote", function()
    it("vend les objets gris à l'ouverture d'un marchand, avec un résumé", function()
        local world = {
            bags = { [0] = {
                [1] = { id = 100, quality = 0, count = 3 },       -- gris : vendu
                [2] = { id = 200, quality = 1 },                  -- blanc : gardé
                [3] = { id = 300, quality = 0, noValue = true },  -- gris sans valeur : gardé
            } },
            prices = { [100] = 25 },
        }
        local game = boot(world)
        local before = #game.chat
        game:fire("MERCHANT_SHOW")
        expect_eq(world.sold, { 100 })
        local text = table.concat(game.chat, " ", before + 1)
        expect(text:find("Junk sold: 1 items", 1, true), text)
        expect(text:find("75", 1, true), "prix de la pile : 3 x 25")
    end)

    it("n'en vend que douze par visite, pour pouvoir les racheter", function()
        local bag = {}
        for slot = 1, 15 do
            bag[slot] = { id = 1000 + slot, quality = 0 }
        end
        local world = { bags = { [0] = bag }, prices = {} }
        local game = boot(world)
        game:fire("MERCHANT_SHOW")
        expect_eq(#world.sold, 12)
        expect(table.concat(game.chat, " "):find("3 more grey items", 1, true), "les trois autres signalés")
    end)

    it("garde les exceptions et ne vend rien avec Maj enfoncée", function()
        local world = { bags = { [0] = { [1] = { id = 100, quality = 0 }, [2] = { id = 101, quality = 0 } } },
            prices = {} }
        local game, junk = boot(world)
        SlashCmdList.NEXTSTEP("keep |cff9d9d9d|Hitem:100::::::::|h[Junk]|h|r")
        expect(junk.db.keep[100], "exception ajoutée depuis un lien")
        _G.IsShiftKeyDown = function() return true end
        game:fire("MERCHANT_SHOW")
        expect_eq(#world.sold, 0, "Maj : rien")
        _G.IsShiftKeyDown = nil
        game:fire("MERCHANT_SHOW")
        expect_eq(world.sold, { 101 }, "l'exception reste")
        SlashCmdList.NEXTSTEP("keep 100")
        expect(not junk.db.keep[100], "exception retirée")
        expect_eq(#game.errors, 0)
    end)
end)
