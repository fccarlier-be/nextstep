-- Couche d'accès aux données : le reste de l'addon ne lit jamais les tables de
-- données directement. Les fichiers générés (Data/Imported, Data des addons de
-- faction) remplissent cette couche ; le format est décrit dans docs/DATA_FORMAT.md.

local _, ns = ...

local DB = {}
ns.DB = DB

DB.guides = {}      -- [id] = guide
DB.order = {}       -- identifiants dans l'ordre de chargement
DB.names = {}       -- [locale][genre][id] = nom
DB.texts = {}       -- [locale] = { shared = { [anglais] = traduit }, guides = { [id] = { ... } } }
DB.templates = {}   -- [locale] = { [modèle anglais avec {1}, {2}...] = modèle traduit }
DB.mapFrames = {}   -- [repère] = { [uiMapID] = cadre }
DB.mapOverlays = {} -- [UiMapArtID] = { { largeur, hauteur, x, y, FileDataID... } } (carte sans brouillard)
DB.retired = {}     -- [ancien identifiant de guide] = true
DB.trainerSpells = {} -- [classe] = { [niveau] = { { id, cost, req, talent, races, faction, skill } } }
DB.sources = {}
DB.learned = nil    -- [genre][id] = nom vu en jeu (module Names), dans la langue du client
DB.resolvers = {}   -- [genre] = function(id) -> nom ; dernier recours avant l'anglais

local function clientLocale()
    local locale = GetLocale()
    if locale == "enGB" then
        return "enUS"
    end
    return locale
end

DB.locale = clientLocale()

---------------------------------------------------------------------------
-- Remplissage (appelé par les fichiers de données)
---------------------------------------------------------------------------

-- G(function() return { ... } end) : un constructeur par guide, pour rester sous la
-- limite de constantes par fonction de Lua 5.1.
-- Corrections propres à NextStep (Data/Overrides/), appliquées à chaque guide chargé.
DB.guideFixes = {}
function DB:AddGuideFix(fix)
    self.guideFixes[#self.guideFixes + 1] = fix
    -- Guides déjà chargés : corrigés tout de suite.
    for _, guide in pairs(self.guides) do
        fix(guide)
    end
end

function DB.AddGuide(build)
    local guide = build()
    for _, fix in ipairs(DB.guideFixes) do
        fix(guide)
    end
    if not DB.guides[guide.id] then
        DB.order[#DB.order + 1] = guide.id
    end
    DB.guides[guide.id] = guide
end

function DB:AddNames(locale, kind, build)
    local byKind = self.names[locale] or {}
    self.names[locale] = byKind
    local names = byKind[kind] or {}
    byKind[kind] = names
    for id, name in pairs(build()) do
        names[id] = name
    end
end

-- guideID nil : traductions communes à tous les guides.
function DB:AddTexts(locale, guideID, build)
    local texts = self.texts[locale] or { shared = {}, guides = {} }
    self.texts[locale] = texts
    local target = texts.shared
    if guideID then
        target = texts.guides[guideID] or {}
        texts.guides[guideID] = target
    end
    for english, translated in pairs(build()) do
        target[english] = translated
    end
end

-- Formules récurrentes des guides (Locales/GuideTexts_*.lua) : les noms y sont
-- remplacés par {1}, {2}... dans l'ordre du texte.
function DB:AddTemplates(locale, build)
    local templates = self.templates[locale] or {}
    self.templates[locale] = templates
    for english, translated in pairs(build()) do
        templates[english] = translated
    end
end

function DB:AddMapFrames(frame, build)
    self.mapFrames[frame] = build()
end

-- Superpositions d'une carte, explorées ou non : taille, décalage et tuiles de 256 pixels,
-- rangée par rangée (forme de C_MapExplorationInfo.GetExploredMapTextures).
function DB:AddMapOverlays(mapArtID, build)
    self.mapOverlays[mapArtID] = build()
end

-- Sorts du maître de classe, par niveau (tables de What's Training).
function DB:AddTrainerSpells(class, build)
    self.trainerSpells[class] = build()
end

function DB:RetireGuides(list)
    for _, id in ipairs(list) do
        self.retired[id] = true
    end
end

function DB:SetSource(source)
    self.sources[#self.sources + 1] = source
end

function DB:SetLearnedNames(names)
    self.learned = names
end

function DB:SetResolver(kind, resolver)
    self.resolvers[kind] = resolver
end

---------------------------------------------------------------------------
-- Lecture
---------------------------------------------------------------------------

function DB:GetGuide(id)
    return self.guides[id]
end

-- Parcourt les guides dans leur ordre de chargement ; filter(guide) facultatif.
function DB:IterateGuides(filter)
    local index = 0
    return function()
        while true do
            index = index + 1
            local id = self.order[index]
            if not id then
                return nil
            end
            local guide = self.guides[id]
            if not filter or filter(guide) then
                return id, guide
            end
        end
    end
end

-- Noms fournis par le client, dans sa langue. [À vérifier] sur Forever.
local CLIENT_NAMES = {
    area = function(id)
        return C_Map and C_Map.GetAreaInfo and C_Map.GetAreaInfo(id)
    end,
    zone = function(id)
        local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(id)
        return info and info.name
    end,
    spell = function(id)
        return C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    end,
    item = function(id)
        return C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    end,
    quest = function(id)
        return C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
    end,
}

local function lookup(names, kind, id)
    local byKind = names and names[kind]
    return byKind and byKind[id]
end

local function clientName(kind, id)
    local get = CLIENT_NAMES[kind]
    if get then
        local name = get(id)
        if type(name) == "string" and name ~= "" then
            return name
        end
    end
end

local function resolved(self, kind, id)
    local resolver = self.resolvers[kind]
    return resolver and resolver(id)
end

-- Nom d'une entité dans la langue du client. guide (facultatif) : un guide peut
-- employer une variante anglaise adaptée à ses phrases (souvent sans article).
-- Ordre : nom vu en jeu, traduction importée, nom du client, résolveur (infobulle),
-- variante du guide, nom anglais importé. En anglais, la variante du guide passe en premier.
function DB:GetName(kind, id, guide)
    local variant = guide and guide.names and guide.names[kind .. ":" .. id]
    if self.locale == "enUS" then
        return variant or lookup(self.names.enUS, kind, id) or clientName(kind, id)
    end
    return lookup(self.learned, kind, id) or lookup(self.names[self.locale], kind, id)
        or clientName(kind, id) or resolved(self, kind, id)
        or variant or lookup(self.names.enUS, kind, id)
end

-- Traduction par modèle : les noms deviennent {1}, {2}..., le modèle est traduit,
-- puis les noms reprennent leur place (éventuellement dans un autre ordre).
local function translateTemplate(templates, text)
    local names = {}
    local template = text:gsub("{%a+:%d+}", function(name)
        names[#names + 1] = name
        return "{" .. #names .. "}"
    end)
    local translated = templates[template]
    if not translated then
        return nil
    end
    return (translated:gsub("{(%d+)}", function(index)
        return names[tonumber(index)] or ""
    end))
end

-- Traduction d'un texte de guide : traduction de Polestar, sinon formule récurrente
-- traduite par NextStep, sinon l'anglais.
function DB:Translate(text, guide)
    if not text then
        return text
    end
    local texts = self.texts[self.locale]
    if texts then
        local own = guide and texts.guides[guide.id]
        local translated = own and own[text] or texts.shared[text]
        if translated then
            return translated
        end
    end
    local templates = self.templates[self.locale]
    return templates and translateTemplate(templates, text) or text
end

-- Texte prêt à afficher : traduit, puis {genre:id} remplacés par les noms.
function DB:Render(text, guide)
    if not text then
        return nil
    end
    return (self:Translate(text, guide):gsub("{(%a+):(%d+)}", function(kind, id)
        return self:GetName(kind, tonumber(id), guide) or "?"
    end))
end
