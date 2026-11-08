local wow = require("wow")

-- Fenêtres déplaçables (Modules/UI/Windows.lua).

-- Fenêtre de Blizzard simulée : scripts accrochés, points, déplacement.
local function newWindow()
    local window = { hooks = {}, points = { { "TOPLEFT", "UIParent", "TOPLEFT", 16, -116 } }, shown = false }
    function window.SetMovable(self, movable) self.movable = movable end
    function window.SetClampedToScreen() end
    function window.RegisterForDrag(self, button) self.drag = button end
    function window.HookScript(self, script, fn)
        self.hooks[script] = self.hooks[script] or {}
        table.insert(self.hooks[script], fn)
    end
    function window.IsShown(self) return self.shown end
    function window.IsProtected() return false end
    function window.ClearAllPoints(self) self.points = {} end
    function window.SetPoint(self, ...) self.points[#self.points + 1] = { ... } end
    function window.GetPoint(self, index)
        local point = self.points[index]
        return point[1], point[2], point[3], point[4], point[5]
    end
    function window.StartMoving(self) self.moving = true end
    function window.StopMovingOrSizing(self)
        self.moving = false
        self.points = { { "CENTER", "UIParent", "CENTER", 120.4, 30.6 } }
    end
    function window.Show() error("Show souillerait la fenêtre") end
    function window.Hide() error("Hide souillerait la fenêtre") end
    return window
end

local function run(window, script, ...)
    for _, fn in ipairs(window.hooks[script] or {}) do
        fn(window, ...)
    end
end

describe("Fenêtres déplaçables", function()
    it("rend une fenêtre déplaçable et retient sa position", function()
        local window = newWindow()
        local game = wow.boot({ beforeInit = function() _G.CharacterFrame = window end })
        local module = game.ns.Modules:Get("Windows")
        expect(window.movable and window.drag == "LeftButton", "déplaçable au clic gauche")

        run(window, "OnDragStart")
        expect(window.moving, "déplacement commencé")
        run(window, "OnDragStop")
        expect_eq(module.db.points.CharacterFrame, { "CENTER", "CENTER", 120, 31 })

        -- Blizzard la replace à l'ouverture : NextStep rend la position retenue.
        window.points = { { "TOPLEFT", "UIParent", "TOPLEFT", 16, -116 } }
        window.shown = true
        run(window, "OnShow")
        expect_eq(window.points[1][1], "CENTER")
        expect_eq(window.points[1][4], 120)

        -- Clic : la fenêtre passe au premier plan.
        local raised = 0
        window.Raise = function() raised = raised + 1 end
        run(window, "OnMouseDown", "LeftButton")
        expect_eq(raised, 1, "passée devant les autres")

        -- Alt + clic droit : position oubliée.
        _G.IsAltKeyDown = function() return true end
        run(window, "OnMouseUp", "RightButton")
        _G.IsAltKeyDown = nil
        expect_eq(module.db.points.CharacterFrame, nil)
        expect_eq(#game.errors, 0)
    end)

    it("prend en charge les fenêtres chargées à la demande", function()
        local game = wow.boot()
        local window = newWindow()
        _G.ClassTrainerFrame = window
        game:fire("ADDON_LOADED", "Blizzard_TrainerUI")
        expect(window.movable, "fenêtre du maître prise en charge à son chargement")
        expect_eq(#game.errors, 0)
    end)
end)
