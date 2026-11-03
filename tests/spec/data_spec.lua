local wow = require("wow")

local ELWYNN = "forever/alliance/human/01-elwynn-forest"
local WESTFALL = "forever/alliance/02-westfall"

local function countGuides(DB, filter)
    local count = 0
    for _ in DB:IterateGuides(filter) do
        count = count + 1
    end
    return count
end

local function byFaction(faction)
    return function(guide)
        return guide.faction == faction
    end
end

-- Remplace des fonctions du client avant le chargement (noms fournis par le jeu).
local function withClient(apis)
    return function()
        for name, api in pairs(apis) do
            _G[name] = api
        end
    end
end

describe("Données importées", function()
    it("ne charge que les guides de la faction du personnage", function()
        local alliance = wow.boot({ faction = "Alliance" }).ns.DB
        expect(countGuides(alliance, byFaction("Alliance")) > 0, "des guides Alliance")
        expect_eq(countGuides(alliance, byFaction("Horde")), 0, "aucun guide Horde")
        local common = countGuides(alliance, function(guide)
            return guide.faction == nil
        end)
        expect(common > 0, "des guides communs (classes, métiers...)")

        local horde = wow.boot({ faction = "Horde" }).ns.DB
        expect(countGuides(horde, byFaction("Horde")) > 0, "des guides Horde")
        expect_eq(countGuides(horde, byFaction("Alliance")), 0, "aucun guide Alliance")
    end)

    it("conserve la structure d'un guide de départ", function()
        local DB = wow.boot({ faction = "Alliance" }).ns.DB
        local guide = DB:GetGuide(ELWYNN)
        expect(guide, "guide de la forêt d'Elwynn")
        expect_eq(guide.races, { "HUMAN" })
        expect_eq(guide.zone, 1429)
        expect_eq(guide.next, { WESTFALL })
        local first = guide.steps[1].goals[1]
        expect_eq(first.t, "accept")
        expect_eq(first.quest, 783)
        expect_eq(first.npc, 823)
        expect(first.npcName == nil and first.title == nil, "les noms anglais sont retirés des objectifs")
    end)

    it("convertit les jetons de race au format du client", function()
        local DB = wow.boot({ faction = "Horde" }).ns.DB
        local valid = { HUMAN = true, DWARF = true, GNOME = true, NIGHTELF = true, ORC = true,
            TROLL = true, TAUREN = true, SCOURGE = true, SKYBORNE = true }
        for id, guide in DB:IterateGuides() do
            for _, race in ipairs(guide.races or {}) do
                expect(valid[race], id .. " : jeton de race inconnu " .. race)
            end
        end
    end)

    it("référence les maîtres candidats dans la réserve du guide", function()
        local guide = wow.boot({ faction = "Alliance" }).ns.DB:GetGuide(ELWYNN)
        local found = false
        for _, step in ipairs(guide.steps) do
            for _, goal in ipairs(step.goals) do
                if goal.candidates then
                    found = true
                    for _, index in ipairs(goal.candidates) do
                        expect(guide.pool[index] and guide.pool[index].npc, "index valide dans pool")
                    end
                end
            end
        end
        expect(found, "au moins une étape « voir le maître »")
    end)

    it("donne les noms anglais sur un client anglais", function()
        local DB = wow.boot({ locale = "enUS" }).ns.DB
        expect_eq(DB:GetName("npc", 197), "Marshal McBride")
        expect_eq(DB:GetName("quest", 7), "Kobold Camp Cleanup")
    end)

    it("donne les noms français sur un client français", function()
        local DB = wow.boot({ locale = "frFR" }).ns.DB
        expect_eq(DB:GetName("quest", 7), "Nettoyer le camp des kobolds")
    end)

    it("préfère la variante d'un guide en anglais", function()
        local DB = wow.boot({ locale = "enUS", faction = "Alliance" }).ns.DB
        local westfall = DB:GetGuide(WESTFALL)
        expect_eq(DB:GetName("zone", 1453), "Stormwind City")
        expect_eq(DB:GetName("zone", 1453, westfall), "Stormwind")
    end)

    it("utilise le nom fourni par le client quand la traduction manque", function()
        local DB = wow.boot({
            locale = "frFR",
            beforeInit = withClient({
                C_Map = {
                    GetAreaInfo = function(id)
                        return id == 24 and "Abbaye de Comté-du-Nord" or nil
                    end,
                },
            }),
        }).ns.DB
        expect_eq(DB:Render("{area:24}"), "Abbaye de Comté-du-Nord")
    end)

    it("traduit et complète un texte de guide", function()
        local DB = wow.boot({ locale = "frFR", faction = "Alliance" }).ns.DB
        local guide = DB:GetGuide(WESTFALL)
        local rendered = DB:Render("Back to {area:108}", guide)
        expect(rendered:find("^Retour à "), "texte traduit : " .. rendered)
        expect(not rendered:find("{"), "plus aucun {genre:id} : " .. rendered)
    end)

    it("affiche ? pour un nom introuvable", function()
        local DB = wow.boot({ locale = "enUS" }).ns.DB
        expect_eq(DB:Render("Talk to {npc:999999999}"), "Talk to ?")
    end)

    it("enregistre la source, les guides retirés et les repères de cartes", function()
        local DB = wow.boot().ns.DB
        expect_eq(DB.sources[1].name, "Polestar")
        expect(next(DB.retired), "des anciens identifiants de guides")
        expect(DB.mapFrames.era[1429], "repère « era » de la forêt d'Elwynn")
    end)

    it("charge les superpositions de la carte sans brouillard", function()
        local DB = wow.boot().ns.DB
        local client
        for _, source in ipairs(DB.sources) do
            if source.name == "Client Forever" then
                client = source
            end
        end
        expect(client and client.version, "source « Client Forever » et sa version")
        local maps, overlays = 0, 0
        for mapArtID, list in pairs(DB.mapOverlays) do
            maps = maps + 1
            for _, overlay in ipairs(list) do
                overlays = overlays + 1
                local width, height = overlay[1], overlay[2]
                local tiles = math.ceil(width / 256) * math.ceil(height / 256)
                expect_eq(#overlay, 4 + tiles, ("tuiles de la carte %d (%dx%d)"):format(mapArtID, width, height))
            end
        end
        expect(maps > 50 and overlays > 1000, ("%d cartes, %d superpositions"):format(maps, overlays))
    end)
end)

local function readText(path)
    local file = assert(io.open(path, "rb"), "fichier manquant : " .. path)
    local content = file:read("*a")
    file:close()
    return content
end

local function contains(text, part)
    return text:find(part, 1, true) ~= nil
end

describe("Licences livrées avec l'addon", function()
    it("inclut le texte de la GPL, identique à celui du dépôt", function()
        expect(readText("addon/NextStep/LICENSE.txt") == readText("LICENSE"),
            "addon/NextStep/LICENSE.txt doit être une copie de LICENSE")
    end)

    it("place les notices des sources à côté de chaque dossier de données importées", function()
        local folders = {
            "addon/NextStep/Data/Imported/Polestar/",
            "addon/NextStep_Alliance/Data/",
            "addon/NextStep_Horde/Data/",
        }
        for _, folder in ipairs(folders) do
            local notice = readText(folder .. "LICENSE-DATA.txt")
            expect(contains(notice, "Copyright (c) 2026 The Polestar authors"), folder .. " : copyright de Polestar")
            expect(contains(notice, "Copyright (c) 2017-2021 Eric Mauser (Shagu)"),
                folder .. " : notice MIT de pfQuest")
            expect(contains(notice, "CMaNGOS"), folder .. " : crédit de CMaNGOS")
        end
        local common = readText(folders[1] .. "LICENSE-DATA.txt")
        expect(contains(common, "Copyright Yendi"), "crédit de DingDB (noms frFR)")
        expect(contains(common, "# Credits of Ding's game data"), "CREDITS.md de DingDB recopié")
    end)

    it("rappelle la licence et le copyright de Polestar en tête des fichiers générés", function()
        local files = {
            "addon/NextStep/Data/Imported/Polestar/Guides.lua",
            "addon/NextStep/Data/Imported/Polestar/Meta.lua",
            "addon/NextStep/Data/Imported/Polestar/Names_enUS.lua",
            "addon/NextStep/Data/Imported/Polestar/Names_frFR.lua",
            "addon/NextStep/Data/Imported/Polestar/Texts_frFR.lua",
            "addon/NextStep_Alliance/Data/Guides.lua",
            "addon/NextStep_Horde/Data/Guides.lua",
        }
        for _, path in ipairs(files) do
            local head = readText(path):sub(1, 400)
            expect(contains(head, "Copyright (c) 2026 The Polestar authors"), path .. " : copyright")
            expect(contains(head, "GPL-3.0-only"), path .. " : licence")
        end
    end)
end)
