local wow = require("wow")
local Player = require("player")

-- Points de récolte (Modules/UI/Gathering.lua) et métiers (Modules/Professions/Professions.lua).

describe("Points de récolte", function()
    it("enregistre une récolte réussie et fusionne les points proches", function()
        local game = wow.boot({ player = { position = { -9000, 300, 0 } } })
        local gathering = game.ns.Modules:Get("Gathering")
        game:fire("UNIT_SPELLCAST_SENT", "player", "Peacebloom", "cast-1", 2366)
        game:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 2366)
        local nodes = gathering.db.nodes[0]
        expect_eq(#nodes, 1)
        expect_eq(nodes[1].name, "Peacebloom")
        expect_eq(nodes[1].kind, "herb")
        -- Même herbe à quelques mètres : fusionnée.
        game.player.position = { -9005, 305, 0 }
        game:fire("UNIT_SPELLCAST_SENT", "player", "Peacebloom", "cast-2", 2366)
        game:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 2366)
        expect_eq(#nodes, 1)
        expect_eq(nodes[1].count, 2)
        -- Filon plus loin : nouveau point.
        game.player.position = { -9200, 500, 0 }
        game:fire("UNIT_SPELLCAST_SENT", "player", "Copper Vein", "cast-3", 2575)
        game:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-3", 2575)
        expect_eq(#nodes, 2)
        expect_eq(nodes[2].kind, "ore")
        -- Sort ordinaire, ou récolte interrompue : rien.
        game:fire("UNIT_SPELLCAST_SENT", "player", "Kobold", "cast-4", 133)
        game:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-4", 133)
        game:fire("UNIT_SPELLCAST_SENT", "player", "Silverleaf", "cast-5", 2366)
        game:fire("UNIT_SPELLCAST_INTERRUPTED", "player")
        game:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-5", 2366)
        expect_eq(#nodes, 2)
        gathering.db.show.ore = false
        expect_eq(#gathering:Visible(0), 1, "filtre par type")
        expect_eq(#game.errors, 0)
    end)
end)

describe("Métiers", function()
    local function boot(player)
        local game = wow.boot({ player = player })
        local guide = game.ns.Modules:Get("Guide")
        guide:SetState(Player.new({ race = "TAUREN", class = "DRUID", level = 12 }))
        return game, game.ns.Modules:Get("Professions"), guide
    end

    it("reconnaît les métiers par leurs sorts et suit leur rang", function()
        local game, professions = boot({ level = 12, spells = { [2366] = true, [8613] = true } })
        local known = professions:Known()
        expect_eq(#known, 2, "herboristerie et dépeçage")
        local profession, rank = professions:ParseSkillUp("Your skill in Herbalism has increased to 57.")
        expect_eq(profession.key, "HERBALISM")
        expect_eq(rank, 57)
        game:fire("CHAT_MSG_SKILL", "Your skill in Herbalism has increased to 57.")
        expect_eq(professions.char.skills.HERBALISM.rank, 57)
        expect_eq({ professions:SkillOf(182) }, { 57, 75 }, "pour le guide")
        local due = professions:TrainingDue(12)
        expect_eq(#due, 1, "Compagnon : compétence 50 et niveau 10")
        expect_eq(due[1].tier.max, 150)
        expect_eq(#game.errors, 0)
    end)

    it("conseille des paires de métiers avec leurs raisons", function()
        local _, professions = boot()
        local advice = professions:Advice("TAUREN", "DRUID", "leveling")
        expect_eq(#advice, 3)
        local first = advice[1]
        local keys = first.a.key .. "+" .. first.b.key
        expect(keys:find("HERBALISM", 1, true) or keys:find("SKINNING", 1, true), keys)
        expect(#first.reasons > 0, "raisons")
        local endgame = professions:Advice("GNOME", "MAGE", "endgame")
        local all = endgame[1].a.key .. endgame[1].b.key
        expect(all:find("ENCHANTING", 1, true) or all:find("TAILORING", 1, true)
            or all:find("ENGINEERING", 1, true), all)
    end)

    it("ouvre l'onglet Métiers du journal", function()
        local game, professions, guide = boot({ level = 12, spells = { [2366] = true } })
        local rows = professions:Rows(guide.state)
        local texts = {}
        for _, row in ipairs(rows) do
            texts[#texts + 1] = row.text
        end
        local all = table.concat(texts, " | ")
        expect(all:find("Herbalism", 1, true), all)
        expect(all:find("Advice", 1, true), all)
        guide:ToggleJournal("professions")
        expect_eq(#game.errors, 0)
    end)
end)

describe("Valeurs secrètes du chat et des sorts", function()
    it("ignore un message de compétence secret, sans erreur", function()
        local game = wow.boot({ player = { level = 12, spells = { [2366] = true } } })
        local professions = game.ns.Modules:Get("Professions")
        local secret = "Your skill in Herbalism has increased to 60."
        _G.issecretvalue = function(value) return value == secret or value == "secret-guid" end
        game:fire("CHAT_MSG_SKILL", secret)
        expect_eq(professions.char.skills.HERBALISM, nil, "message illisible : rang inchangé")
        local gathering = game.ns.Modules:Get("Gathering")
        game:fire("UNIT_SPELLCAST_SENT", "player", "Peacebloom", "secret-guid", 2366)
        game:fire("UNIT_SPELLCAST_SUCCEEDED", "player", "secret-guid", 2366)
        expect_eq(#game.errors, 0, tostring(game.errors[1]))
        expect(gathering, "récolte toujours suivie")
        _G.issecretvalue = nil
    end)
end)
