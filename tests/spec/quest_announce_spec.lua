local wow = require("wow")

-- Annonce au groupe (Modules/UI/QuestAnnounce.lua) : « quête prête à rendre » dans le
-- chat du groupe.

local function boot(inGroup)
    local sent = {}
    local game = wow.boot({
        beforeInit = function()
            _G.IsInGroup = function() return inGroup end
            _G.IsInRaid = function() return false end
            _G.GetQuestLink = function(q) return ("|cffffff00|Hquest:%d:30|h[Quest %d]|h|r"):format(q, q) end
            _G.SendChatMessage = function(text, channel) sent[#sent + 1] = { text = text, channel = channel } end
        end,
    })
    return game, sent
end

local function cleanup()
    _G.IsInGroup, _G.IsInRaid, _G.GetQuestLink, _G.SendChatMessage = nil, nil, nil, nil
end

describe("Annonce au groupe", function()
    it("annonce au groupe une quête qui devient prête à rendre", function()
        local game, sent = boot(true)
        game:acceptQuest(783, { { finished = false } })
        game:fire("QUEST_LOG_UPDATE")
        expect_eq(#sent, 0, "rien au premier relevé")
        game:completeQuest(783)
        game:fire("QUEST_LOG_UPDATE")
        expect_eq(#sent, 1)
        expect_eq(sent[1].channel, "PARTY")
        expect(sent[1].text:find("{rt1} NextStep: |cffffff00|Hquest:783:30|h[Quest 783]|h|r is ready to turn in",
            1, true), sent[1].text)
        game:fire("QUEST_LOG_UPDATE")
        expect_eq(#sent, 1, "une seule fois")
        expect_eq(#game.errors, 0)
        cleanup()
    end)

    it("annonce chaque objectif terminé, sauf le dernier (la quête est alors prête)", function()
        local game, sent = boot(true)
        local first = { finished = false, text = "Guerrier tué : 7/8" }
        local second = { finished = false, text = "Tête de murloc : 3/8" }
        game:acceptQuest(783, { first, second })
        game:fire("QUEST_LOG_UPDATE")
        first.finished, first.text = true, "Guerrier tué : 8/8"
        game:fire("QUEST_LOG_UPDATE")
        expect_eq(#sent, 1)
        expect(sent[1].text:find("{rt1} NextStep: |cffffff00|Hquest:783:30|h[Quest 783]|h|r - Guerrier tué : 8/8",
            1, true), sent[1].text)
        game:fire("QUEST_LOG_UPDATE")
        expect_eq(#sent, 1, "une seule fois")
        game:completeQuest(783)
        game:fire("QUEST_LOG_UPDATE")
        expect_eq(#sent, 2)
        expect(sent[2].text:find("is ready to turn in", 1, true), "seul « prête à rendre » pour le dernier")
        game.ns.Modules:Get("QuestAnnounce").db.objectives = false
        game:acceptQuest(784, { { finished = false, text = "x" } })
        game:fire("QUEST_LOG_UPDATE")
        game:findQuest(784).objectives[1].finished = true
        game:fire("QUEST_LOG_UPDATE")
        expect_eq(#sent, 2, "option coupée")
        expect_eq(#game.errors, 0)
        cleanup()
    end)

    it("se tait hors groupe, au /reload et pour une quête prise déjà prête", function()
        local game, sent = boot(false)
        game:acceptQuest(783, { { finished = false } })
        game:fire("QUEST_LOG_UPDATE")
        game:completeQuest(783)
        game:fire("QUEST_LOG_UPDATE")
        expect_eq(#sent, 0, "hors groupe")
        _G.IsInGroup = function() return true end
        game:acceptQuest(784, {})
        game:completeQuest(784)
        game:fire("QUEST_LOG_UPDATE")
        expect_eq(#sent, 0, "déjà prête en l'acceptant")
        cleanup()
    end)
end)
