local wow = require("wow")
local Player = require("player")
local autoplay = require("autoplay")

local DEFAULT_RACE = { Alliance = "HUMAN", Horde = "ORC" }

-- Description courte de l'étape où le joueur automatique est resté bloqué.
local function describeStuck(guide, report)
    if not report.step then
        return "trop de tours"
    end
    local entry = report.result.steps[report.step]
    local parts = { "étape " .. report.step .. " (" .. tostring(entry.status) .. ")" }
    for j, goal in ipairs(guide.steps[report.step].goals) do
        local status = entry.goals and entry.goals[j]
        parts[#parts + 1] = ("%s %s = %s"):format(goal.t, tostring(goal.quest or goal.item or goal.npc or ""),
            status and status.status or "?")
    end
    return table.concat(parts, ", ")
end

describe("Parcours automatique des guides importés", function()
    for _, faction in ipairs({ "Alliance", "Horde" }) do
        it("termine chaque guide jouable par un personnage " .. faction, function()
            local ns = wow.boot({ faction = faction }).ns
            local count = 0
            local filter = function(guide)
                return (guide.faction or faction) == faction
            end
            for id, guide in ns.DB:IterateGuides(filter) do
                local player = Player.new({
                    faction = faction,
                    race = guide.races and guide.races[1] or DEFAULT_RACE[faction],
                    class = guide.classes and guide.classes[1] or "WARRIOR",
                })
                local ok, report = autoplay(ns.GuideEngine, guide, player)
                expect(ok, id .. " bloqué : " .. describeStuck(guide, report))
                count = count + 1
            end
            expect(count > 150, faction .. " : " .. count .. " guides")
        end)
    end
end)
