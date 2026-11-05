local wow = require("wow")
local Player = require("player")

-- Objets de quête dans les sacs (Modules/UI/QuestItems.lua).
local GUIDE_ID = "test/items"

local function addGuide(ns)
    ns.DB.AddGuide(function() return {
        id = GUIDE_ID, title = "Items", category = "Test", minLevel = 1, maxLevel = 10,
        steps = {
            { title = "Stew", goals = {
                { t = "collect", quest = 38, item = 731, count = 3 },
                { t = "collect", quest = 38, item = 732, count = 3 },
                { t = "collect", quest = 99, item = 900, count = 1 },
            } },
        },
    } end)
end

-- Sacs simulés : [sac] = { [emplacement] = { itemID, quest } } ; quest : objet de quête
-- selon le client (GetContainerItemQuestInfo).
local function installBags(world)
    world.bags = world.bags or {}
    _G.C_Container = {
        GetContainerItemInfo = function(bag, slot)
            local entry = world.bags[bag] and world.bags[bag][slot]
            return entry and { itemID = entry.itemID } or nil
        end,
        GetContainerItemQuestInfo = function(bag, slot)
            local entry = world.bags[bag] and world.bags[bag][slot]
            return { isQuestItem = entry and entry.quest ~= nil or false, questID = entry and entry.quest }
        end,
    }
end

local function boot(world)
    world = world or {}
    local game = wow.boot({
        faction = "Alliance",
        beforeInit = function(ns)
            addGuide(ns)
            installBags(world)
        end,
    })
    local module = game.ns.Modules:Get("QuestItems")
    local Guide = game.ns.Modules:Get("Guide")
    return game, module, Guide, world
end

-- Bouton d'objet simulé : sac, emplacement, texture de la marque enregistrée.
local function button(bag, slot)
    local b = setmetatable({}, { __index = function() return function() end end })
    function b.GetBagID() return bag end
    function b.GetID() return slot end
    function b.CreateTexture()
        local texture = setmetatable({}, { __index = function() return function() end end })
        function texture.Show(self) self.shown = true end
        function texture.Hide(self) self.shown = false end
        b.mark = texture
        return texture
    end
    return b
end

describe("Objets de quête", function()
    it("retient les objets que le guide demande pour les quêtes du journal", function()
        local game, module, Guide = boot()
        Guide:SetState(Player.new():accept(38))
        Guide:Start(GUIDE_ID)
        local items = module:GuideItems()
        expect_eq(items[731], 38)
        expect_eq(items[732], 38)
        expect_eq(items[900], nil, "quête 99 absente du journal")
        expect_eq(#game.errors, 0)
    end)

    it("marque les objets de quête dans les sacs, et seulement eux", function()
        local world = { bags = { [0] = {
            [1] = { itemID = 731 },              -- demandé par le guide
            [2] = { itemID = 5000 },             -- objet ordinaire
            [3] = { itemID = 6000, quest = 77 }, -- objet de quête selon le client
        } } }
        local game, module, Guide = boot(world)
        Guide:SetState(Player.new():accept(38))
        Guide:Start(GUIDE_ID)
        module:Rebuild()
        local b1, b2, b3 = button(0, 1), button(0, 2), button(0, 3)
        _G.C_QuestLog.GetLogIndexForQuestID = function(q) return q == 77 and 1 or nil end
        module:UpdateButton(b1)
        module:UpdateButton(b2)
        module:UpdateButton(b3)
        expect(b1.mark and b1.mark.shown, "ingrédient du guide marqué")
        expect(not rawget(b2, "mark"), "objet ordinaire sans marque")
        expect(b3.mark and b3.mark.shown, "objet de quête du client marqué")

        expect_eq(module:TooltipLine(0, 3, 6000) ~= nil, true, "infobulle")
        expect_eq(module:TooltipLine(0, 2, 5000), nil)
        -- Bouton de rachat du marchand : pas de sac, emplacement 0. Le client refuse
        -- ces valeurs (erreur Lua) : on ne l'interroge pas.
        _G.C_Container.GetContainerItemQuestInfo = function(bag, slot)
            assert(type(bag) == "number" and slot >= 1, "emplacement invalide")
            return { isQuestItem = false }
        end
        expect_eq(module:TooltipLine(nil, 0, 3172), nil, "rachat chez le marchand")
        expect_eq(#game.errors, 0)

        -- La quête 38 est rendue : l'ingrédient n'est plus marqué.
        Guide:SetState(Player.new())
        module:Rebuild()
        module:UpdateButton(b1)
        expect(not b1.mark.shown, "plus de marque après la quête")

        game.ns.Modules:SetEnabled("QuestItems", false)
        expect(not b3.mark.shown, "module désactivé : marques cachées")
        expect_eq(#game.errors, 0)
    end)
end)
