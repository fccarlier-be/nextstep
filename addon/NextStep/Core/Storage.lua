-- Sauvegardes (SavedVariables) : NextStepDB pour le compte, NextStepCharDB par personnage.
-- Chaque table porte un numéro de schéma ; les migrations la font évoluer d'une
-- version à la suivante, puis les valeurs par défaut manquantes sont ajoutées.

local _, ns = ...
local L = ns.L

local Storage = {}
ns.Storage = Storage

Storage.SCHEMA = 1

-- migrations.account[n](db) fait passer une table du schéma n - 1 au schéma n.
Storage.migrations = { account = {}, char = {} }

local ACCOUNT_DEFAULTS = { modules = {} }
local CHAR_DEFAULTS = { modules = {} }

-- Ajoute à target les clés de defaults qui lui manquent, sans écraser l'existant.
local function applyDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            applyDefaults(target[key], value)
        elseif target[key] == nil then
            target[key] = value
        end
    end
    return target
end
Storage.ApplyDefaults = applyDefaults

local function prepare(saved, migrations, defaults)
    local db = type(saved) == "table" and saved or {}
    if db.schema == nil then
        -- Table neuve : rien à migrer.
        db.schema = Storage.SCHEMA
    elseif db.schema > Storage.SCHEMA then
        ns:Print(L["Saved data comes from a newer version of NextStep: it was left untouched."])
    else
        for version = db.schema + 1, Storage.SCHEMA do
            if migrations[version] then
                migrations[version](db)
            end
            db.schema = version
        end
    end
    return applyDefaults(db, defaults)
end

function Storage:Init()
    NextStepDB = prepare(NextStepDB, self.migrations.account, ACCOUNT_DEFAULTS)
    NextStepCharDB = prepare(NextStepCharDB, self.migrations.char, CHAR_DEFAULTS)
    ns.db, ns.char = NextStepDB, NextStepCharDB
end

-- Réglages d'un module, communs au compte.
function Storage:ModuleSettings(name, defaults)
    local settings = ns.db.modules[name] or {}
    ns.db.modules[name] = settings
    return applyDefaults(settings, defaults or {})
end

-- Données d'un module propres au personnage.
function Storage:ModuleCharData(name, defaults)
    local data = ns.char.modules[name] or {}
    ns.char.modules[name] = data
    return applyDefaults(data, defaults or {})
end
