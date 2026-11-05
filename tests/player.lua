-- Joueur simulé pour tester le moteur du guide : il répond comme l'état du
-- joueur décrit dans Modules/Guide/Engine.lua.
--
--   local p = Player.new({ level = 3, class = "MAGE" })
--   p:accept(783); p:objective(7, 1); p:complete(7); p:turnin(7); p:abandon(33)

local Player = {}
Player.__index = Player

function Player.new(options)
    options = options or {}
    return setmetatable({
        ready = options.ready ~= false,
        level = options.level or 1,
        xp = options.xp or 0,
        race = options.race or "HUMAN",
        class = options.class or "WARRIOR",
        faction = options.faction or "Alliance",
        money = options.money or 0,
        log = {},          -- [quête] = { complete = bool, objectives = { [oi] = bool } }
        done = {},         -- [quête] = true : rendue
        items = options.items or {},
        skills = options.skills or {},   -- [ligne] = { rang, rang max }
        spells = options.spells or {},
        standings = options.standings or {},
        area = options.area,
        maps = options.maps or {},   -- [uiMapID] = true : carte du joueur et ses parentes
        bound = options.bound,
        taxi = options.taxi or {},
        explored = options.explored or {},
        distances = options.distances or {},   -- ["map:x:y"] = yards
    }, Player)
end

-- Actions
function Player:accept(q)
    self.log[q] = { complete = false, objectives = {} }
    return self
end
function Player:objective(q, oi)
    self.log[q].objectives[oi] = true
    return self
end
function Player:complete(q)
    self.log[q].complete = true
    return self
end
function Player:turnin(q)
    self.log[q] = nil
    self.done[q] = true
    return self
end
function Player:abandon(q)
    self.log[q] = nil
    return self
end

-- Réponses au moteur
function Player:Ready()
    return self.ready
end
function Player:Level()
    return self.level, self.xp
end
function Player:Race()
    return self.race
end
function Player:Class()
    return self.class
end
function Player:Maps()
    return self.maps
end
function Player:Faction()
    return self.faction
end
function Player:Money()
    return self.money
end
function Player:InLog(q)
    return self.log[q] ~= nil
end
function Player:Complete(q)
    return self.log[q] ~= nil and self.log[q].complete
end
function Player:TurnedIn(q)
    return self.done[q] == true
end
function Player:Objective(q, oi)
    return self.log[q] ~= nil and self.log[q].objectives[oi] == true
end
function Player:LogQuests()
    local list = {}
    for q in pairs(self.log) do
        list[#list + 1] = q
    end
    table.sort(list)
    return list
end
function Player:ItemCount(item)
    return self.items[item] or 0
end
function Player:Skill(line)
    local skill = self.skills[line]
    if skill then
        return skill[1], skill[2]
    end
end
function Player:Knows(spell)
    return self.spells[spell] == true
end
function Player:Standing(faction)
    return self.standings[faction]
end
function Player:InArea(area)
    return area ~= nil and self.area == area
end
function Player:BoundAt(area)
    return area ~= nil and self.bound == area
end
function Player:KnowsTaxi(node)
    return self.taxi[node] == true
end
function Player:Explored(area)
    return self.explored[area] == true
end
function Player:Distance(map, x, y)
    return self.distances[("%d:%s:%s"):format(map, x, y)]
end
function Player:OnCooldown()
    return false
end
function Player:IsUpgrade()
    return nil
end

return Player
