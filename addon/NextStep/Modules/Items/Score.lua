-- Score des objets (docs/DESIGN.md, « 7. Items ») : le seul endroit où la valeur d'un
-- objet est calculée. Deux étapes : l'objet est-il portable par ce personnage (classe,
-- armure, arme apprise, niveau), puis la somme de ses stats pondérées par les poids de
-- la spécialisation, pour la tranche de niveau du personnage.
--
--   Score.Item(link) -> score | nil         -- nil : pas un équipement, ou inutilisable
--   Score.Compare(link) -> résultat | nil
--       { usable, reason, minLevel, score, old, new, delta, pct, slot, empty, equipped }
--       Bagues et bijoux remplacent le plus faible des deux ; une arme à deux mains se
--       compare à main droite + main gauche ; une arme à une main face à une deux mains
--       portée s'associe à la meilleure pièce des sacs pour l'autre main.
--   Score.IsUpgrade(link, threshold) -> bool, delta, pct
--   Score.Spec() -> clé, source ("setting" | "talents" | "default")
--   Score.Invalidate(what)                    -- équipement, sacs, niveau, talents...
--
-- Stats : celles du client (C_Item.GetItemStats, les chiffres propres à Forever, y
-- compris les suffixes aléatoires « de l'ours »). Poids, aptitudes et traits raciaux :
-- Data/Imported/Polestar/Gear.lua (DB.gear). Algorithme adapté de Polestar
-- (Gear/Gear.lua, GPL-3.0-only, Copyright (c) 2026 The Polestar authors).
--
-- Chaque appel au client passe par Score.Client, que les tests remplacent.

local _, ns = ...

local Score = {}
ns.Score = Score

local function wipe(t)
    for key in pairs(t) do
        t[key] = nil
    end
    return t
end

---------------------------------------------------------------------------
-- Client
---------------------------------------------------------------------------

local function usable(value)
    return ns.Usable(value) and value or nil
end

local Client = {}
Score.Client = Client

function Client.PlayerClass()
    local _, class = UnitClass("player")
    return usable(class)
end

function Client.PlayerLevel()
    return tonumber(usable(UnitLevel("player"))) or 1
end

function Client.PlayerRaceID()
    local _, _, raceID = UnitRace("player")
    return tonumber(usable(raceID))
end

function Client.InventoryLink(slot)
    return GetInventoryItemLink and usable(GetInventoryItemLink("player", slot)) or nil
end

function Client.ItemStats(link)
    local getStats = C_Item and C_Item.GetItemStats
    if not getStats then
        return nil
    end
    local ok, stats = pcall(getStats, link)
    return ok and type(stats) == "table" and stats or nil
end

-- -> equipLoc, classID, subclassID, minLevel, quality, sellPrice, name, icon
function Client.ItemInfo(link)
    if not (C_Item and C_Item.GetItemInfo) then
        return nil
    end
    local ok, name, _, quality, _, minLevel, _, _, _, equipLoc, icon, sellPrice, classID, subclassID =
        pcall(C_Item.GetItemInfo, link)
    if ok and name then
        return equipLoc, classID, subclassID, minLevel, quality, sellPrice, name, icon
    end
    if C_Item.GetItemInfoInstant then
        local okInstant, id, _, _, loc, instantIcon, cls, sub = pcall(C_Item.GetItemInfoInstant, link)
        if okInstant and id then
            return loc, cls, sub, nil, nil, nil, nil, instantIcon
        end
    end
end

function Client.BagSlots(bag)
    return C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag) or 0
end

function Client.BagLink(bag, slot)
    return C_Container and C_Container.GetContainerItemLink
        and usable(C_Container.GetContainerItemLink(bag, slot)) or nil
end

function Client.KnowsSpell(spellID)
    if IsPlayerSpell then
        return IsPlayerSpell(spellID) == true
    end
    return IsSpellKnown and IsSpellKnown(spellID) == true or false
end

-- Points dépensés dans l'arbre de talents index (1 à 3), nil si inconnu. Deux
-- signatures : Classic (nom, icône, points...) ou moderne (id, nom, description,
-- icône, points...).
function Client.TalentPoints(index)
    if not GetTalentTabInfo then
        return nil
    end
    local ok, a, _, c, _, e = pcall(GetTalentTabInfo, index)
    if not ok then
        return nil
    end
    return tonumber(usable(type(a) == "number" and e or c))
end

---------------------------------------------------------------------------
-- Faits sur les objets
---------------------------------------------------------------------------

-- Emplacement d'équipement (INVTYPE_*) -> type d'inventaire.
local EQUIP_LOC = {
    INVTYPE_HEAD = 1, INVTYPE_NECK = 2, INVTYPE_SHOULDER = 3, INVTYPE_BODY = 4, INVTYPE_CHEST = 5,
    INVTYPE_WAIST = 6, INVTYPE_LEGS = 7, INVTYPE_FEET = 8, INVTYPE_WRIST = 9, INVTYPE_HAND = 10,
    INVTYPE_FINGER = 11, INVTYPE_TRINKET = 12, INVTYPE_WEAPON = 13, INVTYPE_SHIELD = 14, INVTYPE_RANGED = 15,
    INVTYPE_CLOAK = 16, INVTYPE_2HWEAPON = 17, INVTYPE_BAG = 18, INVTYPE_TABARD = 19, INVTYPE_ROBE = 20,
    INVTYPE_WEAPONMAINHAND = 21, INVTYPE_WEAPONOFFHAND = 22, INVTYPE_HOLDABLE = 23, INVTYPE_AMMO = 24,
    INVTYPE_THROWN = 25, INVTYPE_RANGEDRIGHT = 26, INVTYPE_QUIVER = 27, INVTYPE_RELIC = 28,
}

-- Type d'inventaire -> emplacement(s) du personnage. Chemise, tabard, sacs, munitions
-- et carquois ne sont pas notés.
local SLOTS_OF = {
    [1] = { 1 }, [2] = { 2 }, [3] = { 3 }, [5] = { 5 }, [20] = { 5 }, [6] = { 6 }, [7] = { 7 }, [8] = { 8 },
    [9] = { 9 }, [10] = { 10 }, [11] = { 11, 12 }, [12] = { 13, 14 }, [16] = { 15 },
    [13] = { 16, 17 }, [21] = { 16 }, [17] = { 16 }, [22] = { 17 }, [14] = { 17 }, [23] = { 17 },
    [15] = { 18 }, [25] = { 18 }, [26] = { 18 }, [28] = { 18 },
}
Score.SLOTS_OF = SLOTS_OF

local EQUIPPED_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }
local MAIN, OFF = 16, 17
local RANGED_INV = { [15] = true, [25] = true, [26] = true }
local MELEE_INV = { [13] = true, [17] = true, [21] = true, [22] = true }
local OFFHAND_INV = { [14] = true, [22] = true, [23] = true }
-- Pièces de la classe Armure que toutes les classes portent, quel que soit le sous-type.
local ANY_ARMOR_INV = { [2] = true, [11] = true, [12] = true, [16] = true, [23] = true }
local OFFHAND_DPS = 0.5      -- la main gauche frappe à moitié
local DUAL_WIELD_SPELL = 674
local ARMOR, WEAPON = 4, 2   -- classes d'objets

-- Stats du client -> clés des poids. Les autres clés sont ignorées.
local CLIENT_STATS = {
    ITEM_MOD_STRENGTH_SHORT = "str", ITEM_MOD_AGILITY_SHORT = "agi", ITEM_MOD_STAMINA_SHORT = "sta",
    ITEM_MOD_INTELLECT_SHORT = "int", ITEM_MOD_SPIRIT_SHORT = "spi", RESISTANCE0_NAME = "armor",
    ITEM_MOD_HEALTH_SHORT = "health", ITEM_MOD_MANA_SHORT = "mana",
    ITEM_MOD_DAMAGE_PER_SECOND_SHORT = "dps",
    ITEM_MOD_ATTACK_POWER_SHORT = "ap", ITEM_MOD_RANGED_ATTACK_POWER_SHORT = "rap",
    ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "sp", ITEM_MOD_SPELL_POWER_SHORT = "sp",
    ITEM_MOD_SPELL_HEALING_DONE_SHORT = "heal",
    ITEM_MOD_MANA_REGENERATION_SHORT = "mp5", ITEM_MOD_POWER_REGEN0_SHORT = "mp5",
    ITEM_MOD_HEALTH_REGEN_SHORT = "hp5", ITEM_MOD_HEALTH_REGENERATION_SHORT = "hp5",
    ITEM_MOD_CRIT_RATING_SHORT = "crit", ITEM_MOD_CRIT_MELEE_RATING_SHORT = "crit",
    ITEM_MOD_HIT_RATING_SHORT = "hit", ITEM_MOD_HIT_MELEE_RATING_SHORT = "hit",
    ITEM_MOD_CRIT_SPELL_RATING_SHORT = "spellCrit", ITEM_MOD_HIT_SPELL_RATING_SHORT = "spellHit",
    ITEM_MOD_DEFENSE_SKILL_RATING_SHORT = "defense", ITEM_MOD_DODGE_RATING_SHORT = "dodge",
    ITEM_MOD_PARRY_RATING_SHORT = "parry", ITEM_MOD_BLOCK_RATING_SHORT = "block",
    ITEM_MOD_BLOCK_VALUE_SHORT = "blockValue",
}

-- Sous-type d'arme -> sort de la compétence d'arme (un maître d'armes l'enseigne).
local WEAPON_SPELL = {
    [0] = 196, [1] = 197, [2] = 264, [3] = 266, [4] = 198, [5] = 199, [6] = 200, [7] = 201,
    [8] = 202, [10] = 227, [13] = 15590, [15] = 1180, [16] = 2567, [18] = 5011, [19] = 5009,
}

function Score.ItemID(link)
    if type(link) == "number" then
        return link
    end
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

-- Caches par lien, vidés quand la réponse peut changer ; plafonnés (hôtel des ventes).
local CACHE_CAP = 400
local infoCache, infoCount = {}, 0
local resultCache, resultCount = {}, 0

local function clientStats(link)
    local stats = Client.ItemStats(link)
    if not stats then
        return nil
    end
    local out = {}
    for key, value in pairs(stats) do
        local name = CLIENT_STATS[key]
        if name and type(value) == "number" and ns.Usable(value) then
            out[name] = (out[name] or 0) + value
        end
    end
    return out
end

-- Caractéristiques importées (DB.itemStats, format de Polestar_ItemDB) : pour les
-- objets que le client n'a pas encore en cache (butin des donjons, objets à venir).
--   "<emplacement> <niveau d'objet> <niveau requis> <qualité> <classe> <sous-classe>
--    [<stat><n> ...] [dmin<n> dmax<n> speed<ms>] [cls<masque>] [uniq1]"
local UNTOKEN = { mpr = "mp5", hpr = "hp5" }
function Score.ParseStats(text)
    local inv, req, quality, class, sub = text:match("^(%d+) %d+ (%d+) (%d+) (%d+) (%d+)")
    if not inv then
        return nil
    end
    local info = { inv = tonumber(inv), req = tonumber(req), quality = tonumber(quality),
        class = tonumber(class), subclass = tonumber(sub), allow = 0, stats = {} }
    local dmin, dmax, speed
    for key, value in text:gmatch("(%a+)(%-?%d+)") do
        value = tonumber(value)
        if key == "dmin" then
            dmin = value
        elseif key == "dmax" then
            dmax = value
        elseif key == "speed" then
            speed = value
        elseif key == "cls" then
            info.allow = value
        elseif key ~= "uniq" then
            info.stats[UNTOKEN[key] or key] = value
        end
    end
    if dmin and dmax and speed and speed > 0 then
        info.stats.dps = math.floor((dmin + dmax) / 2 / (speed / 1000) * 10 + 0.5) / 10
    end
    return info
end

-- -> { id, link, inv, req, quality, class, subclass, allow, sellPrice, name, icon, stats } | nil
local function buildInfo(link)
    if type(link) ~= "string" then
        return nil
    end
    local id = Score.ItemID(link)
    local imported = id and ns.DB.itemStats and ns.DB.itemStats[id]
    imported = imported and Score.ParseStats(imported)
    local equipLoc, class, subclass, minLevel, quality, sellPrice, name, icon = Client.ItemInfo(link)
    local inv = EQUIP_LOC[equipLoc or ""] or (imported and imported.inv)
    if not (inv and SLOTS_OF[inv]) then
        return nil
    end
    local stats = clientStats(link)
    if not stats or next(stats) == nil then
        stats = imported and imported.stats or stats
    end
    if not stats then
        return nil
    end
    return {
        id = id, link = link, inv = inv, req = tonumber(minLevel) or (imported and imported.req) or 0,
        quality = quality or (imported and imported.quality), class = class or (imported and imported.class),
        subclass = subclass or (imported and imported.subclass), allow = imported and imported.allow or 0,
        sellPrice = tonumber(sellPrice) or 0, name = name, icon = icon, stats = stats,
    }
end

-- Lien d'un objet par son identifiant : celui du client s'il le connaît, sinon « item:<id> ».
function Score.LinkOf(id)
    if C_Item and C_Item.GetItemInfo then
        local ok, _, link = pcall(C_Item.GetItemInfo, id)
        if ok and type(link) == "string" and ns.Usable(link) then
            return link
        end
    end
    return "item:" .. id
end

function Score.Info(link)
    if link == nil then
        return nil
    end
    local hit = infoCache[link]
    if hit ~= nil then
        return hit or nil
    end
    if infoCount >= CACHE_CAP then
        wipe(infoCache)
        infoCount = 0
    end
    local info = buildInfo(link)
    infoCache[link] = info or false
    infoCount = infoCount + 1
    return info
end

---------------------------------------------------------------------------
-- Personnage : classe, niveau, spécialisation, poids
---------------------------------------------------------------------------

local player = {}
local specKey, specSource, weights, band

local function gear()
    return ns.DB.gear or {}
end

-- Choix de spécialisation par classe ({ [classe] = "auto" | clé }), fourni par le module.
Score.choices = {}

function Score.Player()
    if not player.class then
        player.class = Client.PlayerClass()
        player.level = Client.PlayerLevel()
        player.raceID = Client.PlayerRaceID()
    end
    return player
end

function Score.Specs(class)
    local meta = gear().classes and gear().classes[class]
    return meta and meta.specs or {}
end

-- L'arbre de talents le plus fourni ; avant le premier point, la spécialisation
-- habituelle de la classe pour monter en niveau.
function Score.DetectSpec(class)
    local meta = gear().classes and gear().classes[class]
    if not meta then
        return nil, "default"
    end
    local best, bestPoints = nil, 0
    for index, spec in ipairs(meta.specs) do
        local points = Client.TalentPoints(index)
        if points and points > bestPoints then
            best, bestPoints = spec.key, points
        end
    end
    if best then
        return best, "talents"
    end
    return meta.default, "default"
end

-- Ajoute un petit poids à la DPS d'arme de mêlée là où la spécialisation n'en a pas
-- (lanceurs de sorts, druides) : à bas niveau ils frappent aussi avec leur arme. En
-- Farouche, 14 points de puissance d'attaque valent 1 DPS (Forever : les formes
-- frappent avec la DPS de l'arme).
local MELEE_DPS, AP_PER_DPS = 0.01, 14
local function withMeleeDps(list, class, key)
    if not list or list.dps ~= nil then
        return list
    end
    local copy = {}
    for name, value in pairs(list) do
        copy[name] = value
    end
    copy.dps = (class == "DRUID" and key == "feral" and list.ap) and AP_PER_DPS * list.ap or MELEE_DPS
    return copy
end

-- Poids d'une spécialisation à un niveau : la première tranche qui le couvre (la
-- dernière au-delà), sinon la table de Polestar. -> poids, tranche { upTo, source }
function Score.WeightsFor(class, key, level)
    local bands = gear().bands and gear().bands[class] and gear().bands[class][key]
    if bands and #bands > 0 then
        local pick = bands[#bands]
        for _, candidate in ipairs(bands) do
            if level <= candidate.upTo then
                pick = candidate
                break
            end
        end
        return withMeleeDps(pick.weights, class, key), pick
    end
    local list = gear().weights and gear().weights[class] and gear().weights[class][key]
    return withMeleeDps(list, class, key), list and { upTo = 60, source = "polestar" } or nil
end

local function resolveSpec()
    local me = Score.Player()
    local class = me.class
    if not (class and gear().weights and gear().weights[class]) then
        specKey, specSource, weights, band = nil, "default", nil, nil
        return
    end
    local chosen = Score.choices[class]
    if chosen and chosen ~= "auto" and gear().weights[class][chosen] then
        specKey, specSource = chosen, "setting"
    else
        specKey, specSource = Score.DetectSpec(class)
    end
    weights, band = Score.WeightsFor(class, specKey, me.level)
end

function Score.Spec()
    if not specSource then
        resolveSpec()
    end
    return specKey, specSource, band
end

function Score.Weights()
    if not specSource then
        resolveSpec()
    end
    return weights
end

---------------------------------------------------------------------------
-- Port et score
---------------------------------------------------------------------------

local function canDualWield()
    local prof = gear().proficiency and gear().proficiency[Score.Player().class]
    if prof and prof.dualWield and Score.Player().level >= prof.dualWield then
        return true
    end
    return Client.KnowsSpell(DUAL_WIELD_SPELL)
end

-- Compétences d'armes connues ; false si le client n'en connaît aucune (alors toute
-- arme que la classe peut apprendre compte).
local weaponSkills
local function knowsWeapon(subclass)
    if weaponSkills == nil then
        weaponSkills = false
        local known, any = {}, false
        for sub, spell in pairs(WEAPON_SPELL) do
            if Client.KnowsSpell(spell) then
                known[sub], any = true, true
            end
        end
        if any then
            weaponSkills = known
        end
    end
    return not weaponSkills or WEAPON_SPELL[subclass] == nil or weaponSkills[subclass] == true
end

-- -> utilisable, raison ("armor" | "weapon" | "skill" | "dualwield"), niveau requis
function Score.Usability(info)
    local me = Score.Player()
    local prof = gear().proficiency and gear().proficiency[me.class]
    local minLevel = info.req or 0
    if not prof then
        return true, nil, minLevel
    end
    -- Objet réservé à certaines classes (masque de bits des classes).
    local meta = gear().classes and gear().classes[me.class]
    if info.allow and info.allow > 0 and meta and math.floor(info.allow / meta.bit) % 2 ~= 1 then
        return false, "class", minLevel
    end
    local sub = info.subclass
    if info.class == ARMOR and sub and not ANY_ARMOR_INV[info.inv] then
        if sub >= 1 and sub <= 4 then
            if sub > prof.armor then
                if not (prof.armorAt40 and sub <= prof.armorAt40) then
                    return false, "armor", minLevel
                end
                minLevel = math.max(minLevel, 40)
            end
        elseif sub == 6 then
            if not prof.shield then
                return false, "armor", minLevel
            end
        elseif sub == 7 or sub == 8 or sub == 9 then
            if prof.relic ~= sub then
                return false, "armor", minLevel
            end
        end
    elseif info.class == WEAPON and sub then
        if sub == 20 or (sub ~= 14 and not prof.weapons[sub]) then
            return false, "weapon", minLevel
        end
        if not knowsWeapon(sub) then
            return false, "skill", minLevel
        end
        if info.inv == 22 and not canDualWield() then
            return false, "dualwield", minLevel
        end
    end
    return true, nil, minLevel
end

local function racialBonus(info, list, asOffhand)
    local racial = gear().racials and gear().racials[Score.Player().raceID or 0]
    if not racial then
        return 0
    end
    local bonus = 0
    local crit = racial.weaponCrit
    if crit and info.class == WEAPON and not asOffhand and crit.subclasses[info.subclass] then
        bonus = bonus + ((list.crit or 0) + (list.spellCrit or 0)) * crit.pct
    end
    for stat, mult in pairs(racial.statMult or {}) do
        if info.stats[stat] then
            bonus = bonus + (list[stat] or 0) * info.stats[stat] * (mult - 1)
        end
    end
    return bonus
end

function Score.With(info, list, asOffhand)
    local total = 0
    for stat, value in pairs(info.stats) do
        if stat == "dps" then
            if RANGED_INV[info.inv] then
                total = total + (list.rdps or 0) * value
            elseif MELEE_INV[info.inv] then
                total = total + (list.dps or 0) * value * (asOffhand and OFFHAND_DPS or 1)
            end
        else
            total = total + (list[stat] or 0) * value
        end
    end
    return total + racialBonus(info, list, asOffhand)
end

function Score.Item(link)
    local info = Score.Info(link)
    local list = Score.Weights()
    if not (info and list) or not Score.Usability(info) then
        return nil
    end
    return Score.With(info, list, OFFHAND_INV[info.inv] or false)
end

---------------------------------------------------------------------------
-- Équipement porté et sacs
---------------------------------------------------------------------------

local equipped = { link = {}, info = {}, score = {} }
local equippedDirty = true
local bagMain, bagOff = {}, {}
local bagsDirty = true

local function refreshEquipped(list)
    if not equippedDirty then
        return
    end
    for _, slot in ipairs(EQUIPPED_SLOTS) do
        local link = Client.InventoryLink(slot)
        local info = link and Score.Info(link)
        equipped.link[slot] = link or false
        equipped.info[slot] = info or false
        equipped.score[slot] = info and Score.With(info, list, slot == OFF) or 0
    end
    equippedDirty = false
end

-- Garde les deux meilleures pièces : { score1, lien1, score2, lien2 }.
local function keepBest(best, link, value)
    if best[1] == nil or value > best[1] then
        best[3], best[4] = best[1], best[2]
        best[1], best[2] = value, link
    elseif best[3] == nil or value > best[3] then
        best[3], best[4] = value, link
    end
end

-- Meilleure arme à une main et meilleure pièce de main gauche des sacs, portables
-- maintenant : pour compléter une arme à une main quand une deux mains est portée.
local function refreshBags(list)
    if not bagsDirty then
        return
    end
    bagsDirty = false
    wipe(bagMain)
    wipe(bagOff)
    local dual = canDualWield()
    for bag = 0, 4 do
        for slot = 1, Client.BagSlots(bag) do
            local link = Client.BagLink(bag, slot)
            local info = link and Score.Info(link)
            if info then
                local ok, _, minLevel = Score.Usability(info)
                if ok and minLevel <= Score.Player().level then
                    local inv = info.inv
                    if inv == 13 or inv == 21 then
                        keepBest(bagMain, link, Score.With(info, list, false))
                    end
                    if (OFFHAND_INV[inv] and (inv ~= 22 or dual)) or (inv == 13 and dual) then
                        keepBest(bagOff, link, Score.With(info, list, true))
                    end
                end
            end
        end
    end
end

local function bagBest(best, except)
    if best[1] and best[2] ~= except then
        return best[1]
    end
    return best[3] or 0
end

---------------------------------------------------------------------------
-- Comparaison
---------------------------------------------------------------------------

local function option(result, slot, old, new, empty)
    local delta = new - old
    if result.delta == nil or delta > result.delta then
        result.slot, result.old, result.new, result.delta = slot, old, new, delta
        result.empty = empty and true or false
    end
end

local function compare(link)
    local info = Score.Info(link)
    local list = Score.Weights()
    if not (info and list) then
        return nil
    end
    local ok, reason, minLevel = Score.Usability(info)
    local result = { usable = ok, reason = reason, minLevel = minLevel, equipped = false, info = info }
    if not ok then
        return result
    end
    refreshEquipped(list)
    local inv = info.inv
    local slots = SLOTS_OF[inv]
    for _, slot in ipairs(slots) do
        if equipped.link[slot] == link then
            result.equipped, result.slot = true, slot
        end
    end
    result.score = Score.With(info, list, OFFHAND_INV[inv] or false)
    local score = equipped.score
    if result.equipped then
        result.old, result.new, result.delta = score[result.slot], score[result.slot], 0
    elseif inv == 11 or inv == 12 then
        local a, b = slots[1], slots[2]
        -- Le plus faible des deux s'en va ; un emplacement vide est le plus faible.
        local slot = (not equipped.link[a] and a) or (not equipped.link[b] and b)
            or (score[b] < score[a] and b or a)
        option(result, slot, score[slot], result.score, not equipped.link[slot])
    elseif inv == 17 then
        option(result, MAIN, score[MAIN] + score[OFF], result.score,
            not equipped.link[MAIN] and not equipped.link[OFF])
    elseif inv == 13 or inv == 21 or OFFHAND_INV[inv] then
        local main = equipped.info[MAIN]
        local twoHander = main and main.inv == 17
        if twoHander then
            refreshBags(list)
        end
        if inv == 13 or inv == 21 then
            if twoHander then
                option(result, MAIN, score[MAIN], result.score + bagBest(bagOff, link), false)
            else
                option(result, MAIN, score[MAIN], result.score, not equipped.link[MAIN])
            end
        end
        if OFFHAND_INV[inv] or (inv == 13 and canDualWield()) then
            local asOff = OFFHAND_INV[inv] and result.score or Score.With(info, list, true)
            if twoHander then
                option(result, OFF, score[MAIN], asOff + bagBest(bagMain, link), false)
            else
                option(result, OFF, score[OFF], asOff, not equipped.link[OFF])
            end
        end
    else
        local slot = slots[1]
        option(result, slot, score[slot], result.score, not equipped.link[slot])
    end
    if result.old and result.old > 0 and not result.empty then
        result.pct = result.delta / result.old * 100
    end
    return result
end

-- Résultat en lecture seule, mis en cache par lien.
function Score.Compare(link)
    if link == nil then
        return nil
    end
    local hit = resultCache[link]
    if hit ~= nil then
        return hit or nil
    end
    if resultCount >= CACHE_CAP then
        wipe(resultCache)
        resultCount = 0
    end
    local result = compare(link)
    resultCache[link] = result or false
    resultCount = resultCount + 1
    return result
end

-- Amélioration : portable maintenant, meilleure d'au moins threshold % (tout gain
-- remplit un emplacement vide).
function Score.IsUpgrade(link, threshold)
    local result = Score.Compare(link)
    if not (result and result.usable and result.delta) or result.equipped then
        return false, result and result.delta, result and result.pct
    end
    local up = result.delta > 0 and (result.minLevel or 0) <= Score.Player().level
    if up and result.pct then
        up = result.pct >= (threshold or 0)
    end
    return up, result.delta, result.pct
end

---------------------------------------------------------------------------
-- Fraîcheur
---------------------------------------------------------------------------

-- what : "equipment", "bags", "level", "spec", "skills", "items" (infos reçues).
function Score.Invalidate(what)
    if what == "level" or what == "spec" or what == "player" then
        specSource = nil
    end
    if what == "level" or what == "player" then
        player.class = nil
    end
    if what == "items" or what == "player" then
        wipe(infoCache)
        infoCount = 0
    end
    weaponSkills = nil
    if what ~= "bags" then
        equippedDirty = true
    end
    bagsDirty = true
    wipe(resultCache)
    resultCount = 0
end
