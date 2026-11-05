-- Sorts à apprendre chez le maître de classe (docs/DESIGN.md, « Sorts à apprendre ») :
-- d'après les tables de What's Training (DB.trainerSpells), les sorts de la classe
-- jusqu'au niveau du personnage qu'il ne connaît pas encore, selon sa race, sa
-- faction, ses talents et ses compétences, avec leur coût.
--
-- Un sort se connaît par IsPlayerSpell (State:Knows). Un rang dépassé peut ne plus
-- être signalé comme connu : un sort est donc tenu pour connu dès qu'un sort connu
-- l'exige (rang suivant). Un prérequis appris pendant la même visite compte aussi.
--
-- [À vérifier] sur Forever : exactitude des tables pour chaque classe ; rangs
-- inférieurs vus par IsPlayerSpell.

local _, ns = ...
local L = ns.L

local Guide = ns.Modules:Get("Guide")

local function contains(list, value)
    for _, item in ipairs(list or {}) do
        if item == value then
            return true
        end
    end
    return false
end

-- Sorts connus : ceux du client, plus les prérequis des sorts connus (rangs dépassés).
local function knownSet(byLevel, state)
    local known = {}
    local levels = {}
    for level in pairs(byLevel) do
        levels[#levels + 1] = level
    end
    table.sort(levels, function(a, b) return a > b end)
    for _, level in ipairs(levels) do
        for _, spell in ipairs(byLevel[level]) do
            if known[spell.id] or state:Knows(spell.id) then
                known[spell.id] = true
                for _, req in ipairs(spell.req or {}) do
                    known[req] = true
                end
            end
        end
    end
    return known, levels
end

local function applies(spell, state, known, future)
    if spell.races and not contains(spell.races, state:Race()) then
        return false
    end
    if spell.faction and spell.faction ~= state:Faction() then
        return false
    end
    if spell.talent and not known[spell.talent] and not state:Knows(spell.talent) then
        return false
    end
    if spell.skill and not future and (state:Skill(spell.skill[1]) or 0) < spell.skill[2] then
        return false
    end
    return true
end

-- Sorts qui deviennent possibles entre minLevel et maxLevel, en apprenant tout au
-- fur et à mesure (known est complété). future : les compétences (poisons) ne sont
-- pas vérifiées, on ne peut pas prévoir leur rang.
local function learnable(byLevel, levels, state, known, minLevel, maxLevel, future)
    local list, total = {}, 0
    for _, level in ipairs(levels) do
        if level >= minLevel and level <= maxLevel then
            for _, spell in ipairs(byLevel[level]) do
                if not known[spell.id] and applies(spell, state, known, future) then
                    local ready = true
                    for _, req in ipairs(spell.req or {}) do
                        -- Prérequis absent des tables (talent, quête) : le client le dit.
                        if not known[req] and not state:Knows(req) then
                            ready = false
                        end
                    end
                    if ready then
                        -- Appris pendant la même visite : ses rangs suivants deviennent possibles.
                        known[spell.id] = true
                        list[#list + 1] = { id = spell.id, cost = spell.cost, level = level }
                        total = total + spell.cost
                    end
                end
            end
        end
    end
    return list, total
end

local function classData(state)
    local byLevel = state and ns.DB.trainerSpells[state:Class()]
    if not byLevel then
        return nil
    end
    local known, levels = knownSet(byLevel, state)
    table.sort(levels)
    return byLevel, levels, known
end

-- Sorts à apprendre jusqu'au niveau maxLevel (niveau du personnage par défaut) :
-- liste { id, cost, level } triée par niveau, et coût total. nil si la classe n'a
-- pas de données.
function Guide:SpellsToLearn(state, maxLevel)
    state = state or self.state
    local byLevel, levels, known = classData(state)
    if not byLevel then
        return nil, 0
    end
    return learnable(byLevel, levels, state, known, 1, maxLevel or state:Level(), false)
end

-- Plan des sorts : ce qui est possible maintenant, puis chaque niveau à venir qui
-- apporte de nouveaux sorts, jusqu'à maxLevel (60 par défaut). Liste de groupes
-- { level (nil : maintenant), spells, total }.
local MAX_LEVEL = 60

function Guide:SpellPlan(state, maxLevel)
    state = state or self.state
    local byLevel, levels, known = classData(state)
    if not byLevel then
        return nil
    end
    local level = state:Level()
    local spells, total = learnable(byLevel, levels, state, known, 1, level, false)
    local plan = { { level = nil, spells = spells, total = total } }
    for next = level + 1, maxLevel or MAX_LEVEL do
        if byLevel[next] then
            spells, total = learnable(byLevel, levels, state, known, next, next, true)
            if #spells > 0 then
                plan[#plan + 1] = { level = next, spells = spells, total = total }
            end
        end
    end
    return plan
end

-- Prochain niveau où le maître aura de nouveaux sorts, et leur nombre.
function Guide:NextTrainerLevel(state)
    local plan = self:SpellPlan(state)
    local next = plan and plan[2]
    if next then
        return next.level, #next.spells
    end
end

---------------------------------------------------------------------------
-- Libellés
---------------------------------------------------------------------------

-- Somme d'argent lisible : « 1 po 20 pa 5 pc », icônes du jeu si possible.
function Guide.FormatMoney(copper)
    if GetCoinTextureString then
        return GetCoinTextureString(copper)
    end
    local gold, silver, rest = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if gold > 0 then
        parts[#parts + 1] = L["%d g"]:format(gold)
    end
    if silver > 0 then
        parts[#parts + 1] = L["%d s"]:format(silver)
    end
    if rest > 0 or #parts == 0 then
        parts[#parts + 1] = L["%d c"]:format(rest)
    end
    return table.concat(parts, " ")
end

local function spellName(id)
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    return name or ns.DB:GetName("spell", id) or ("#" .. id)
end

-- Résumé : « 3 sorts à apprendre (1 po 20 pa) », ou nil s'il n'y a rien.
function Guide:SpellsSummary(state)
    local list, total = self:SpellsToLearn(state)
    if not list or #list == 0 then
        return nil
    end
    return L["%d spells to learn (%s)"]:format(#list, Guide.FormatMoney(total)), list, total
end

-- Infobulle : un sort par ligne avec son coût, l'argent manquant, le prochain niveau.
function Guide:SpellsTooltip(state)
    state = state or self.state
    local list, total = self:SpellsToLearn(state)
    local lines = {}
    for _, spell in ipairs(list or {}) do
        lines[#lines + 1] = ("%s - %s"):format(spellName(spell.id), Guide.FormatMoney(spell.cost))
    end
    if list and #list > 0 then
        lines[#lines + 1] = L["Total: %s"]:format(Guide.FormatMoney(total))
        local money = state:Money() or 0
        if money < total then
            lines[#lines + 1] = "|cffff8040" .. L["Missing: %s"]:format(Guide.FormatMoney(total - money)) .. "|r"
        end
    end
    local next, count = self:NextTrainerLevel(state)
    if next then
        lines[#lines + 1] = L["Level %d: %d new spells"]:format(next, count)
    end
    return table.concat(lines, "\n")
end

-- /ns spells : la liste dans le chat.
function Guide:PrintSpells()
    local list, total = self:SpellsToLearn()
    if not list then
        ns:Print(L["No trainer data for your class."])
        return
    end
    if #list == 0 then
        ns:Print(L["Nothing to learn at your trainer for now."])
    else
        ns:Print(L["%d spells to learn (%s)"]:format(#list, Guide.FormatMoney(total)))
        for _, spell in ipairs(list) do
            DEFAULT_CHAT_FRAME:AddMessage(("  [%d] %s - %s"):format(spell.level, spellName(spell.id),
                Guide.FormatMoney(spell.cost)))
        end
    end
    local next, count = self:NextTrainerLevel()
    if next then
        DEFAULT_CHAT_FRAME:AddMessage("  " .. L["Level %d: %d new spells"]:format(next, count))
    end
end
