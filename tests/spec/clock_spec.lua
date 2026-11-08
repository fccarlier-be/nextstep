local wow = require("wow")

-- Horloge (Modules/UI/Clock.lua) : alarmes, minuteurs, chronomètre.

local function boot(options)
    options = options or {}
    local world = { now = options.now or 1000000 }
    local game = wow.boot({
        saved = options.saved,
        beforeInit = function()
            _G.time = function() return world.now end
            _G.PlaySound = function() world.sounds = (world.sounds or 0) + 1 end
        end,
    })
    return game, game.ns.Modules:Get("Clock"), world
end

describe("Horloge", function()
    it("lit les heures et met en forme les durées", function()
        local _, clock = boot()
        expect_eq({ clock.ParseTime("7:30") }, { 7, 30 })
        expect_eq({ clock.ParseTime("19h05") }, { 19, 5 })
        expect_eq({ clock.ParseTime("21") }, { 21, 0 })
        expect_eq(clock.ParseTime("25:00"), nil)
        expect_eq(clock.FormatDuration(65), "1:05")
        expect_eq(clock.FormatDuration(3725), "1:02:05")
    end)

    it("sonne un minuteur à l'heure, une seule fois", function()
        local game, clock, world = boot()
        clock:AddTimer(300, "Pain")
        expect_eq(#clock:Check(world.now + 100, 10, 0, 10, 0, "d"), 0)
        local fired = clock:Check(world.now + 300, 10, 5, 10, 5, "d")
        expect_eq(#fired, 1)
        expect(fired[1]:find("Pain", 1, true))
        expect_eq(#clock.char.timers, 0, "retiré")
        expect_eq(world.sounds, 1, "un son")
        expect(clock.alertFrame, "alerte au centre")
        expect_eq(#game.errors, 0)
    end)

    it("sonne une alarme une fois par jour, à l'heure locale ou serveur", function()
        local _, clock, world = boot()
        clock:AddAlarm(20, 30, "Raid")
        clock:AddAlarm(8, 0, "Serveur", true)
        expect_eq(#clock:Check(world.now, 20, 30, 1, 0, "j1"), 1, "heure locale")
        expect_eq(#clock:Check(world.now + 10, 20, 30, 1, 0, "j1"), 0, "pas deux fois dans la minute")
        expect_eq(#clock:Check(world.now, 20, 30, 1, 0, "j2"), 1, "le lendemain")
        expect_eq(#clock:Check(world.now, 3, 0, 8, 0, "j2"), 1, "heure du serveur")
    end)

    it("garde les minuteurs d'une session à l'autre et signale ceux finis hors ligne", function()
        local _, clock = boot()
        clock:AddTimer(60, "Court")
        clock:AddTimer(7200, "Long")
        local saved = wow.saved()
        local game2, clock2, world2 = boot({ saved = saved, now = 1000000 + 600 })
        expect_eq(#clock2.char.timers, 1, "le long continue")
        expect(clock2.lastAlert and clock2.lastAlert:find("Court", 1, true), "fini pendant l'absence")
        expect(world2.sounds and world2.sounds >= 1)
        expect_eq(#game2.errors, 0)
    end)

    it("chronomètre et commandes", function()
        local game, clock, world = boot()
        clock:StopwatchToggle()
        world.now = world.now + 42
        expect_eq(clock:StopwatchTime(), 42)
        clock:StopwatchToggle()
        world.now = world.now + 100
        expect_eq(clock:StopwatchTime(), 42, "en pause")
        clock:StopwatchReset()
        expect_eq(clock:StopwatchTime(), 0)
        SlashCmdList.NEXTSTEP("timer 2,5 Thé")
        expect_eq(clock.char.timers[1].name, "Thé")
        expect_eq(clock.char.timers[1].ends, world.now + 150)
        SlashCmdList.NEXTSTEP("alarm 21:15 Donjon")
        expect_eq(clock.char.alarms[1].hour, 21)
        SlashCmdList.NEXTSTEP("clock")
        expect_eq(#game.errors, 0)
    end)
end)
