-- Métiers (docs/DESIGN.md, « 6. Métiers »).
--
--   rangs     : Forever n'a plus GetNumSkillLines ; le niveau de maîtrise vient des sorts
--               connus (Apprenti à Artisan), le rang des messages « Votre compétence en …
--               augmente jusqu'à N » et de la fenêtre du métier ouverte (char.skills) ;
--   conseiller: un score par paire de métiers principaux, d'après la race, la classe et
--               l'objectif choisi (leveling, or, fin de jeu), avec ses raisons ;
--   journal   : onglet « Métiers » : métiers connus et leur rang, prochain maître,
--               routes de métier de Polestar (les suivre d'un clic), conseils ;
--   guide     : rappel quand un métier atteint le plafond de sa maîtrise.
--
-- Les rangs servent aussi au guide (State:Skill), pour les étapes des routes de métier.
--
-- Sur Forever, le texte de CHAT_MSG_SKILL est secret (erreur en jeu du 2026-11-08) : il
-- est ignoré, et le rang vient de la fenêtre du métier.
-- [À vérifier] sur Forever : ERR_SKILL_UP_SI / SKILL_RANK_UP (CHAT_MSG_SKILL), fenêtre
-- du métier (C_TradeSkillUI.GetTradeSkillLine ou GetTradeSkillLine), bonus raciaux.

local _, ns = ...
local L = ns.L

local Professions = ns.Modules:New("Professions", {
    title = L["Professions"],
    description = L["Tracks your professions, advises which ones to take, and reminds you to see the trainer."],
    defaults = { goal = "leveling" },
    charDefaults = { skills = {} },   -- [clé] = { rank, max }
})

local Guide = ns.Modules:Get("Guide")
local C = ns.Style.COLORS

-- Métiers : clé, ligne de compétence, sorts d'Apprenti, Compagnon, Expert, Artisan,
-- nom (traduit), genre : primary, gathering (principal de récolte), secondary.
local LIST = {
    { key = "HERBALISM", line = 182, spells = { 2366, 2368, 3570, 11993 }, name = L["Herbalism"], kind = "gathering" },
    { key = "MINING", line = 186, spells = { 2575, 2576, 3564, 10248 }, name = L["Mining"], kind = "gathering" },
    { key = "SKINNING", line = 393, spells = { 8613, 8617, 8618, 10768 }, name = L["Skinning"], kind = "gathering" },
    { key = "ALCHEMY", line = 171, spells = { 2259, 3101, 3464, 11611 }, name = L["Alchemy"], kind = "primary" },
    { key = "BLACKSMITHING", line = 164, spells = { 2018, 3100, 3538, 9785 }, name = L["Blacksmithing"],
        kind = "primary" },
    { key = "ENCHANTING", line = 333, spells = { 7411, 7412, 7413, 13920 }, name = L["Enchanting"], kind = "primary" },
    { key = "ENGINEERING", line = 202, spells = { 4036, 4037, 4038, 12656 }, name = L["Engineering"],
        kind = "primary" },
    { key = "LEATHERWORKING", line = 165, spells = { 2108, 3104, 3811, 10662 }, name = L["Leatherworking"],
        kind = "primary" },
    { key = "TAILORING", line = 197, spells = { 3908, 3909, 3910, 12180 }, name = L["Tailoring"], kind = "primary" },
    { key = "FIRST_AID", line = 129, spells = { 3273, 3274, 7924, 10846 }, name = L["First Aid"], kind = "secondary" },
    { key = "COOKING", line = 185, spells = { 2550, 3102, 3413, 18260 }, name = L["Cooking"], kind = "secondary" },
    { key = "FISHING", line = 356, spells = { 7620, 7731, 7732, 18248 }, name = L["Fishing"], kind = "secondary" },
}
Professions.LIST = LIST

-- Maîtrises : plafond de compétence, niveau du personnage et compétence pour l'apprendre.
local TIERS = {
    { name = L["Apprentice"], max = 75, level = 1, skill = 0 },
    { name = L["Journeyman"], max = 150, level = 10, skill = 50 },
    { name = L["Expert"], max = 225, level = 20, skill = 125 },
    { name = L["Artisan"], max = 300, level = 35, skill = 200 },
}
Professions.TIERS = TIERS

-- Conseiller : points par race, par classe et par objectif.
-- [À vérifier] bonus raciaux de Forever (ceux du Classic : Gnome, Tauren).
Professions.ADVICE = {
    race = { GNOME = { ENGINEERING = 3 }, TAUREN = { HERBALISM = 3 } },
    class = {
        WARRIOR = { MINING = 2, BLACKSMITHING = 3, ENGINEERING = 1 },
        PALADIN = { MINING = 2, BLACKSMITHING = 3 },
        HUNTER = { SKINNING = 2, LEATHERWORKING = 3, ENGINEERING = 2 },
        ROGUE = { SKINNING = 2, LEATHERWORKING = 3, ENGINEERING = 1 },
        PRIEST = { TAILORING = 3, ENCHANTING = 2 },
        SHAMAN = { SKINNING = 2, LEATHERWORKING = 3 },
        MAGE = { TAILORING = 3, ENCHANTING = 2 },
        WARLOCK = { TAILORING = 3, ENCHANTING = 2 },
        DRUID = { SKINNING = 2, LEATHERWORKING = 3, HERBALISM = 1 },
    },
    goal = {
        leveling = { HERBALISM = 2, MINING = 2, SKINNING = 3 },
        gold = { HERBALISM = 3, MINING = 3, SKINNING = 2 },
        endgame = { ALCHEMY = 3, ENCHANTING = 2, ENGINEERING = 2, BLACKSMITHING = 1 },
    },
    -- Paires qui vont bien ensemble (la récolte nourrit l'artisanat).
    pairs = { HERBALISM = "ALCHEMY", MINING = "BLACKSMITHING", SKINNING = "LEATHERWORKING" },
}

local GOALS = { "leveling", "gold", "endgame" }
local GOAL_LABELS = { leveling = L["leveling"], gold = L["gold"], endgame = L["end game"] }

local function byKey(key)
    for _, profession in ipairs(LIST) do
        if profession.key == key then
            return profession
        end
    end
end
Professions.ByKey = byKey

---------------------------------------------------------------------------
-- Rangs
---------------------------------------------------------------------------

local function knows(spell)
    if IsPlayerSpell then
        return IsPlayerSpell(spell) == true
    end
    return IsSpellKnown and IsSpellKnown(spell) == true or false
end

-- Maîtrise connue (1 à 4), ou nil si le métier n'est pas appris.
function Professions:Tier(profession)
    local tier
    for index, spell in ipairs(profession.spells) do
        if knows(spell) then
            tier = index
        end
    end
    return tier
end

-- Métiers appris : { profession, tier, rank (peut être nil), max }.
function Professions:Known()
    local list = {}
    for _, profession in ipairs(LIST) do
        local tier = self:Tier(profession)
        local seen = self.char.skills[profession.key]
        if tier or seen then
            tier = tier or 1
            list[#list + 1] = { profession = profession, tier = tier, rank = seen and seen.rank,
                max = TIERS[tier].max }
        end
    end
    return list
end

function Professions:SetRank(key, rank, max)
    if not (key and rank) then
        return
    end
    self.char.skills[key] = { rank = rank, max = max or (self.char.skills[key] or {}).max }
    if Guide and Guide.state and Guide.state.Invalidate then
        Guide.state:Invalidate("skills")
    end
end

-- Profession d'après son nom affiché (traduit), ou nil.
function Professions.FromName(name)
    if type(name) ~= "string" then
        return nil
    end
    name = name:lower()
    for _, profession in ipairs(LIST) do
        local display = C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName
            and C_TradeSkillUI.GetTradeSkillDisplayName(profession.line)
        if (profession.name and profession.name:lower() == name)
            or (type(display) == "string" and display:lower() == name) then
            return profession
        end
    end
end

-- « Votre compétence en Herboristerie augmente jusqu'à 57. » -> profession, 57.
function Professions:ParseSkillUp(message)
    -- Sur Forever, le texte des messages du chat peut être secret : illisible, ignoré
    -- (le rang vient alors de la fenêtre du métier).
    if type(message) ~= "string" or not ns.Usable(message) then
        return nil
    end
    local template = SKILL_RANK_UP or "Your skill in %s has increased to %d."
    -- Modèle du client -> motif Lua : %s et %d deviennent des captures.
    local pattern = template:gsub("%%s", "\1"):gsub("%%d", "\2")
    pattern = pattern:gsub("[%^%$%(%)%.%[%]%*%+%-%?]", "%%%0")
    pattern = "^" .. pattern:gsub("\1", "(.+)"):gsub("\2", "(%%d+)") .. "$"
    local name, rank = message:match(pattern)
    local profession = Professions.FromName(name)
    if profession and tonumber(rank) then
        return profession, tonumber(rank)
    end
end

-- Fenêtre du métier ouverte : son rang.
function Professions:ReadTradeSkill()
    local name, rank, max
    if C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillLine then
        local ok, a, b, c = pcall(C_TradeSkillUI.GetTradeSkillLine)
        if ok then
            name, rank, max = a, b, c
        end
    end
    if not name and GetTradeSkillLine then
        name, rank, max = GetTradeSkillLine()
    end
    local profession = Professions.FromName(name)
    if profession and tonumber(rank) then
        self:SetRank(profession.key, tonumber(rank), tonumber(max))
    end
end

-- Pour le guide (State:Skill) : rang, plafond d'un métier d'après sa ligne ou son nom.
function Professions:SkillOf(line, name)
    for _, profession in ipairs(LIST) do
        if profession.line == line or (name and Professions.FromName(name) == profession) then
            local seen = self.char.skills[profession.key]
            local tier = self:Tier(profession)
            if seen or tier then
                return seen and seen.rank or 1, TIERS[tier or 1].max
            end
        end
    end
end

-- Maîtrise suivante à apprendre maintenant : { profession, tier } ; le métier est au
-- plafond (à 25 près) et le niveau du personnage suffit.
function Professions:TrainingDue(level)
    local list = {}
    for _, entry in ipairs(self:Known()) do
        local next = TIERS[entry.tier + 1]
        if next and entry.rank and entry.rank >= next.skill and level >= next.level then
            list[#list + 1] = { profession = entry.profession, tier = next, rank = entry.rank, max = entry.max }
        end
    end
    return list
end

---------------------------------------------------------------------------
-- Conseiller
---------------------------------------------------------------------------

-- Meilleures paires de métiers principaux : { a, b, score, reasons }.
function Professions:Advice(race, class, goal)
    local advice = Professions.ADVICE
    local function points(key)
        local total, reasons = 0, {}
        local r = advice.race[race or ""] and advice.race[race][key]
        if r then
            total = total + r
            reasons[#reasons + 1] = L["racial bonus"]
        end
        local c = advice.class[class or ""] and advice.class[class][key]
        if c then
            total = total + c
            reasons[#reasons + 1] = L["suits your class"]
        end
        local g = advice.goal[goal or "leveling"] and advice.goal[goal or "leveling"][key]
        if g then
            total = total + g
            reasons[#reasons + 1] = L["good for %s"]:format(GOAL_LABELS[goal or "leveling"])
        end
        return total, reasons
    end
    local primaries = {}
    for _, profession in ipairs(LIST) do
        if profession.kind ~= "secondary" then
            primaries[#primaries + 1] = profession
        end
    end
    local combos = {}
    for i = 1, #primaries do
        for j = i + 1, #primaries do
            local a, b = primaries[i], primaries[j]
            local sa, ra = points(a.key)
            local sb, rb = points(b.key)
            local score = sa + sb
            local reasons = {}
            for _, reason in ipairs(ra) do
                reasons[#reasons + 1] = a.name .. " : " .. reason
            end
            for _, reason in ipairs(rb) do
                reasons[#reasons + 1] = b.name .. " : " .. reason
            end
            if advice.pairs[a.key] == b.key or advice.pairs[b.key] == a.key then
                score = score + 2
                reasons[#reasons + 1] = L["one gathers what the other crafts"]
            end
            if a.kind == "gathering" and b.kind == "gathering" and goal ~= "endgame" then
                score = score + 1
                reasons[#reasons + 1] = L["two gathering professions: gold while leveling"]
            end
            combos[#combos + 1] = { a = a, b = b, score = score, reasons = reasons }
        end
    end
    table.sort(combos, function(x, y)
        if x.score ~= y.score then
            return x.score > y.score
        end
        return x.a.key .. x.b.key < y.a.key .. y.b.key
    end)
    return { combos[1], combos[2], combos[3] }
end

---------------------------------------------------------------------------
-- Onglet du journal
---------------------------------------------------------------------------

-- Routes de métier de Polestar pour une profession.
function Professions:Routes(profession)
    local list = {}
    local key = profession.key:lower():gsub("_", "")
    for _, guide in ns.DB:IterateGuides() do
        local id = guide.id:lower():gsub("[%-_]", "")
        if guide.category == "Professions" and id:find(key, 1, true) then
            list[#list + 1] = guide
        end
    end
    table.sort(list, function(a, b) return (a.minLevel or 0) < (b.minLevel or 0) end)
    return list
end

function Professions:Rows(state)
    local rows = {}
    local level = state and state:Level() or 1
    rows[#rows + 1] = { header = true, text = L["Your professions"] }
    local known = self:Known()
    if #known == 0 then
        rows[#rows + 1] = { text = L["No profession learned yet."], color = C.muted }
    end
    for _, entry in ipairs(known) do
        local rank = entry.rank and ("%d / %d"):format(entry.rank, entry.max) or ("? / %d"):format(entry.max)
        rows[#rows + 1] = { text = ("%s (%s)"):format(entry.profession.name, TIERS[entry.tier].name), right = rank,
            color = C.text }
        local next = TIERS[entry.tier + 1]
        if next then
            local ready = entry.rank and entry.rank >= next.skill and level >= next.level
            rows[#rows + 1] = { text = L["Next: %s at skill %d and level %d"]:format(next.name, next.skill, next.level),
                indent = 1, color = ready and C.green or C.muted }
        end
        for _, guide in ipairs(self:Routes(entry.profession)) do
            rows[#rows + 1] = {
                text = L["Route: %s"]:format(ns.GuideLabels.Guide(guide)), indent = 1, color = C.blue,
                onClick = Guide and function()
                    Guide:FollowFromJournal(guide)
                end,
            }
        end
    end
    local race, class = state and state:Race(), state and state:Class()
    rows[#rows + 1] = { header = true, text = L["Advice (goal: %s)"]:format(GOAL_LABELS[self.db.goal]) }
    rows[#rows + 1] = { text = L["Goal: %s (click to change)"]:format(GOAL_LABELS[self.db.goal]), color = C.gold,
        onClick = function()
            for index, goal in ipairs(GOALS) do
                if goal == self.db.goal then
                    self.db.goal = GOALS[index % #GOALS + 1]
                    break
                end
            end
            self:UpdateTab()
        end }
    for index, combo in ipairs(self:Advice(race, class, self.db.goal)) do
        rows[#rows + 1] = { text = ("%d. %s + %s"):format(index, combo.a.name, combo.b.name), color = C.text,
            right = L["score %d"]:format(combo.score) }
        for _, reason in ipairs(combo.reasons) do
            rows[#rows + 1] = { text = reason, indent = 2, color = C.muted }
        end
    end
    rows[#rows + 1] = { text = L["Also useful: First Aid, Cooking and Fishing."], color = C.muted }
    return rows
end

function Professions:UpdateTab(body)
    body = body or self.body
    if not (body and body:IsShown()) then
        return
    end
    body.list:SetRows(self:Rows(Guide and Guide.state), true)
end

if Guide then
    Guide:AddJournalTab({
        key = "professions",
        label = L["Professions"],
        create = function(parent)
            local size = Guide.JOURNAL_BODY
            local body = CreateFrame("Frame", nil, parent)
            body.list = Guide.RowList(body, size.width, size.height)
            body.list:SetPoint("TOPLEFT")
            Professions.body = body
            return body
        end,
        update = function(body)
            Professions:UpdateTab(body)
        end,
    })
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------

function Professions:OnEnable()
    self:RegisterEvent("CHAT_MSG_SKILL", function(_, _, message)
        local profession, rank = self:ParseSkillUp(message)
        if profession then
            self:SetRank(profession.key, rank)
            self:UpdateTab()
        end
    end)
    for _, event in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "CRAFT_SHOW" }) do
        self:RegisterEvent(event, function()
            ns.SafeCall(self.ReadTradeSkill, self)
        end)
    end
end

-- Options : objectif du conseiller.
function Professions:BuildOptions(panel, anchor)
    local function label()
        return L["Advice goal: %s"]:format(GOAL_LABELS[self.db.goal] or self.db.goal)
    end
    local button = ns.Options.AddButton(panel, label(), 260, function(frame)
        for index, goal in ipairs(GOALS) do
            if goal == self.db.goal then
                self.db.goal = GOALS[index % #GOALS + 1]
                break
            end
        end
        frame:SetLabel(label())
        self:UpdateTab()
    end)
    button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -10)
    return button
end
