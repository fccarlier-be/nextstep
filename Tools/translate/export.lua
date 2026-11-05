-- Exporte les textes de guide encore en anglais (ni Polestar, ni les formules de
-- Locales/GuideTexts_frFR.lua, ni Locales/GuideNotes_frFR.lua ne les traduisent),
-- pour les traduire par lots.
--
--   luajit Tools/translate/export.lua                     -- compte par faction et catégorie
--   luajit Tools/translate/export.lua Alliance/Class alliance-class
--
-- Le second appel écrit Tools/translate/alliance-class.texts.txt (un texte par ligne,
-- retours à la ligne écrits \n) et alliance-class.en.txt (leurs paragraphes, sans
-- doublon). Traduire chaque ligne de .en.txt dans .fr.txt, puis lancer
-- Tools/translate/build.py. À lancer depuis la racine du dépôt.

GetLocale = function() return "frFR" end

local texts = { shared = {}, guides = {} }
local templates = {}
local guides = {}
local DB = {}
function DB:AddTexts(_, id, build)
    local target = texts.shared
    if id then
        target = texts.guides[id] or {}
        texts.guides[id] = target
    end
    for english, french in pairs(build()) do
        target[english] = french
    end
end
function DB:AddTemplates(_, build)
    for english, french in pairs(build()) do
        templates[english] = french
    end
end
function DB.AddGuide(build)
    guides[#guides + 1] = build()
end
setmetatable(DB, { __index = function() return function() end end })
NextStep = { DB = DB }
local ns = { DB = DB }

dofile("addon/NextStep/Data/Imported/Polestar/Texts_frFR.lua")
assert(loadfile("addon/NextStep/Locales/GuideTexts_frFR.lua"))("NextStep", ns)
local notes = loadfile("addon/NextStep/Locales/GuideNotes_frFR.lua")
if notes then
    notes("NextStep", ns)
end

local FILES = {
    common = "addon/NextStep/Data/Imported/Polestar/Guides.lua",
    Alliance = "addon/NextStep_Alliance/Data/Guides.lua",
    Horde = "addon/NextStep_Horde/Data/Guides.lua",
}
local origin = {}
for name, path in pairs(FILES) do
    local before = #guides
    dofile(path)
    for index = before + 1, #guides do
        origin[guides[index]] = name
    end
end

local function templated(text)
    local count = 0
    local template = text:gsub("{%a+:%d+}", function()
        count = count + 1
        return "{" .. count .. "}"
    end)
    return templates[template] ~= nil, template
end

local wanted, batch = arg[1], arg[2]
local seen, list, stats = {}, {}, {}
local function check(guide, text)
    if not text or seen[text] then
        return
    end
    local own = texts.guides[guide.id]
    if (own and own[text]) or texts.shared[text] then
        return
    end
    local done, template = templated(text)
    if done or not template:gsub("{%d+}", ""):find("%a") then
        return
    end
    seen[text] = true
    local key = origin[guide] .. "/" .. (guide.category or "?")
    stats[key] = (stats[key] or 0) + 1
    if key == wanted then
        list[#list + 1] = text
    end
end
for _, guide in ipairs(guides) do
    check(guide, guide.title)
    check(guide, guide.why)
    for _, step in ipairs(guide.steps or {}) do
        check(guide, step.title)
        check(guide, step.note)
        for _, goal in ipairs(step.goals) do
            check(guide, goal.note)
            check(guide, goal.text)
        end
    end
end

local keys = {}
for key in pairs(stats) do
    keys[#keys + 1] = key
end
table.sort(keys)
for _, key in ipairs(keys) do
    print(("%-28s %5d"):format(key, stats[key]))
end

if batch then
    local textsFile = assert(io.open("Tools/translate/" .. batch .. ".texts.txt", "wb"))
    local paragraphsFile = assert(io.open("Tools/translate/" .. batch .. ".en.txt", "wb"))
    local paragraphs = {}
    for _, text in ipairs(list) do
        textsFile:write((text:gsub("\n", "\\n")), "\n")
        for paragraph in (text .. "\n"):gmatch("(.-)\n") do
            if not paragraphs[paragraph] then
                paragraphs[paragraph] = true
                paragraphsFile:write(paragraph, "\n")
            end
        end
    end
    textsFile:close()
    paragraphsFile:close()
    print(("%d textes exportés dans Tools/translate/%s.*"):format(#list, batch))
end
