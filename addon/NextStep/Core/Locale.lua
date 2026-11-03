-- Traductions. Les clés sont les textes anglais : une clé sans traduction
-- s'affiche telle quelle, ce qui fait de l'anglais la langue par défaut.

local _, ns = ...

ns.L = setmetatable({}, {
    __index = function(_, key)
        return key
    end,
})
