local wow = require("wow")

-- Module Items (Modules/Items/*.lua) : score, spécialisation, récompenses, alerte.

-- Objets simulés, par lien : { loc, class, sub, req, sell, name, stats }.
-- world.equipped : [emplacement] = lien ; world.bags : [sac] = { [emplacement] = lien } ;
-- world.talents : points par arbre ; world.equippedBy : liens équipés par l'alerte.
local function install(world)
    local items = world.items
    _G.C_Item.GetItemStats = function(link)
        local item = items[link]
        return item and item.stats
    end
    _G.C_Item.GetItemInfo = function(link)
        local item = items[link]
        if not item then
            return nil
        end
        return item.name or link, link, item.quality or 2, 10, item.req or 0, "", "", 1, item.loc, "icon",
            item.sell or 0, item.class, item.sub
    end
    _G.C_Item.EquipItemByName = function(link)
        world.equippedBy[#world.equippedBy + 1] = link
    end
    _G.GetInventoryItemLink = function(_, slot)
        return world.equipped[slot]
    end
    _G.C_Container = {
        GetContainerNumSlots = function(bag) return world.bags[bag] and 16 or 0 end,
        GetContainerItemLink = function(bag, slot) return world.bags[bag] and world.bags[bag][slot] end,
    }
    _G.GetTalentTabInfo = function(index)
        return "Tree" .. index, "icon", (world.talents or {})[index] or 0, "file"
    end
end

local function boot(world, player)
    world.equipped = world.equipped or {}
    world.bags = world.bags or {}
    world.equippedBy = {}
    local game = wow.boot({
        player = player or { level = 20, class = "WARRIOR" },
        beforeInit = function()
            install(world)
        end,
    })
    return game, game.ns.Modules:Get("Items"), game.ns.Score
end

local ARMOR, WEAPON = 4, 2

local function chest(str, sub, req)
    return { loc = "INVTYPE_CHEST", class = ARMOR, sub = sub or 3, req = req or 0,
        stats = { ITEM_MOD_STRENGTH_SHORT = str, RESISTANCE0_NAME = 50 } }
end

describe("Items : score", function()
    it("compare un objet à celui qui est porté, avec le gain en pour cent", function()
        local world = { items = { ["item:1"] = chest(5), ["item:2"] = chest(10) }, equipped = { [5] = "item:1" } }
        local game, items, Score = boot(world)
        expect(items.enabled, "module actif")
        local result = Score.Compare("item:2")
        expect(result.usable)
        expect(result.delta > 0, "meilleur")
        expect(result.pct > 50, "gain en pour cent")
        expect(Score.IsUpgrade("item:2", 2))
        expect(not Score.IsUpgrade("item:1", 2), "l'objet porté n'est pas une amélioration")
        expect_eq(Score.Compare("item:1").equipped, true)
        expect_eq(#game.errors, 0)
    end)

    it("refuse l'armure trop lourde et attend le niveau 40 pour la plaque", function()
        local world = { items = { ["item:3"] = chest(20, 4) } }
        local _, _, Score = boot(world)
        local result = Score.Compare("item:3")
        expect(result.usable, "un guerrier portera la plaque")
        expect_eq(result.minLevel, 40)
        expect(not Score.IsUpgrade("item:3"), "pas avant le niveau 40")

        local _, _, mageScore = boot({ items = { ["item:3"] = chest(20, 4) } }, { level = 20, class = "MAGE" })
        local mage = mageScore.Compare("item:3")
        expect_eq(mage.usable, false)
        expect_eq(mage.reason, "armor")
    end)

    it("ne compte pas une arme dont la compétence n'est pas apprise", function()
        local sword = { loc = "INVTYPE_2HWEAPON", class = WEAPON, sub = 8,
            stats = { ITEM_MOD_STRENGTH_SHORT = 10, ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 12 } }
        local world = { items = { ["item:4"] = sword } }
        local _, _, Score = boot(world, { level = 20, class = "WARRIOR", spells = { [196] = true } })
        expect_eq(Score.Compare("item:4").reason, "skill", "seules les haches sont apprises")
        local _, _, learned = boot({ items = { ["item:4"] = sword } },
            { level = 20, class = "WARRIOR", spells = { [202] = true } })
        expect(learned.IsUpgrade("item:4"), "épées à deux mains apprises, emplacement vide")
    end)

    it("compare une arme à deux mains aux deux mains portées", function()
        local world = { items = {
            ["item:10"] = { loc = "INVTYPE_WEAPON", class = WEAPON, sub = 0,
                stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 10 } },
            ["item:11"] = { loc = "INVTYPE_SHIELD", class = ARMOR, sub = 6, stats = { RESISTANCE0_NAME = 400 } },
            ["item:12"] = { loc = "INVTYPE_2HWEAPON", class = WEAPON, sub = 1,
                stats = { ITEM_MOD_DAMAGE_PER_SECOND_SHORT = 14 } },
        }, equipped = { [16] = "item:10", [17] = "item:11" } }
        local _, _, Score = boot(world)
        local result = Score.Compare("item:12")
        expect_eq(result.slot, 16)
        local main, shield = Score.With(Score.Info("item:10"), Score.Weights(), false),
            Score.With(Score.Info("item:11"), Score.Weights(), true)
        expect(math.abs(result.old - (main + shield)) < 1e-6, "main droite + bouclier")
    end)

    it("remplace la plus faible des deux bagues", function()
        local function ring(sta)
            return { loc = "INVTYPE_FINGER", class = ARMOR, sub = 0, stats = { ITEM_MOD_STAMINA_SHORT = sta } }
        end
        local world = { items = { ["item:20"] = ring(8), ["item:21"] = ring(3), ["item:22"] = ring(5) },
            equipped = { [11] = "item:20", [12] = "item:21" } }
        local _, _, Score = boot(world)
        local result = Score.Compare("item:22")
        expect_eq(result.slot, 12, "la bague à 3 s'en va")
        expect(result.delta > 0)
    end)
end)

describe("Items : spécialisation", function()
    it("suit l'arbre de talents le plus fourni, ou le choix du joueur", function()
        local world = { items = {}, talents = { 0, 5, 2 } }
        local _, items, Score = boot(world)
        expect_eq(Score.Spec(), "fury")
        expect_eq(select(2, Score.Spec()), "talents")
        items:CycleSpec()
        expect_eq(Score.Spec(), "arms", "premier choix manuel")
        expect_eq(select(2, Score.Spec()), "setting")
        items:CycleSpec()
        items:CycleSpec()
        items:CycleSpec()
        expect_eq(items.db.spec.WARRIOR, "auto", "retour à l'automatique")
        expect_eq(Score.Spec(), "fury")
    end)

    it("prend la spécialisation habituelle avant le premier point", function()
        local _, _, Score = boot({ items = {} }, { level = 5, class = "MAGE" })
        expect_eq(Score.Spec(), "frost")
        expect_eq(select(2, Score.Spec()), "default")
    end)
end)

describe("Items : infobulle", function()
    it("affiche le gain, l'objet porté ou la raison", function()
        local world = { items = { ["item:1"] = chest(5), ["item:2"] = chest(10), ["item:3"] = chest(1, 4),
            ["item:9"] = { loc = "INVTYPE_CHEST", class = ARMOR, sub = 1, stats = {} } },
            equipped = { [5] = "item:1" } }
        local _, items = boot(world, { level = 20, class = "MAGE" })
        expect(items:TooltipLine("item:9"):find("equipped", 1, true) == nil)
        local text = items:TooltipLine("item:3")
        expect(text:find("cannot wear", 1, true), text)
        local _, warrior = boot(world)
        text = warrior:TooltipLine("item:2")
        expect(text:find("+", 1, true) and text:find("%", 1, true), text)
        expect(warrior:TooltipLine("item:1"):find("equipped", 1, true))
        expect(warrior:TooltipLine("item:3"):find("(level 40)", 1, true), "plaque : niveau 40")
        expect_eq(warrior:TooltipLine("item:404"), nil, "pas un équipement connu")
    end)
end)

describe("Items : récompenses de quête", function()
    it("conseille l'amélioration la plus forte, sinon ce qui se vend le mieux", function()
        local world = { items = {
            ["item:1"] = chest(5), ["item:2"] = chest(10), ["item:3"] = chest(20),
            ["item:30"] = { loc = "INVTYPE_CHEST", class = ARMOR, sub = 1, sell = 120,
                stats = { ITEM_MOD_INTELLECT_SHORT = 3 } },
            ["item:31"] = { loc = "INVTYPE_CHEST", class = ARMOR, sub = 1, sell = 80,
                stats = { ITEM_MOD_INTELLECT_SHORT = 9 } },
        }, equipped = { [5] = "item:1" } }
        local _, items = boot(world)
        local pick, reason, detail = items:RankChoices({
            { link = "item:2" }, { link = "item:3" }, { link = "item:30" },
        })
        expect_eq(pick, 2)
        expect_eq(reason, "upgrade")
        expect(detail.pct > 0)
        expect(items:RewardReason(reason, detail):find("Upgrade for Arms", 1, true))

        pick, reason, detail = items:RankChoices({ { link = "item:30" }, { link = "item:31", count = 2 } })
        expect_eq(pick, 2, "80 x 2 > 120")
        expect_eq(reason, "sell")
        expect_eq(detail, 160)
    end)
end)

describe("Items : alerte d'amélioration", function()
    local function world()
        return { items = { ["item:1"] = chest(5), ["item:2"] = chest(10) }, equipped = { [5] = "item:1" },
            bags = { [0] = {} } }
    end

    it("signale une amélioration qui arrive dans les sacs, une seule fois", function()
        local w = world()
        local game, items = boot(w)
        game:fire("BAG_UPDATE_DELAYED")
        expect(not items.alert or not items.alertItems, "rien dans les sacs")
        w.bags[0][3] = "item:2"
        game:fire("BAG_UPDATE_DELAYED")
        expect_eq(#items.alertItems, 1)
        expect_eq(items.alertItems[1].link, "item:2")
        items:HideAlert()
        game:fire("BAG_UPDATE_DELAYED")
        expect_eq(items.alertItems, nil, "déjà signalée")
        expect_eq(#game.errors, 0)
    end)

    it("attend la fin du combat, puis cesse d'écouter", function()
        local w = world()
        local game, items = boot(w)
        game.inCombat = true
        w.bags[0][1] = "item:2"
        game:fire("BAG_UPDATE_DELAYED")
        expect_eq(items.alertItems, nil, "rien en combat")
        expect(game:isEventRegistered("PLAYER_REGEN_ENABLED"))
        game.inCombat = false
        game:fire("PLAYER_REGEN_ENABLED")
        expect_eq(#items.alertItems, 1)
        expect(not game:isEventRegistered("PLAYER_REGEN_ENABLED"))
    end)

    it("équipe l'objet cliqué, et rien si l'option est coupée", function()
        local w = world()
        local game, items = boot(w)
        w.bags[0][1] = "item:2"
        game:fire("BAG_UPDATE_DELAYED")
        items:EquipFromAlert(items.alertItems[1])
        expect_eq(w.equippedBy, { "item:2" })
        expect_eq(items.alertItems, nil, "encart fermé")

        local w2 = world()
        local game2, items2 = boot(w2)
        items2.db.alert = false
        w2.bags[0][1] = "item:2"
        game2:fire("BAG_UPDATE_DELAYED")
        expect_eq(items2.alertItems, nil)
    end)
end)
