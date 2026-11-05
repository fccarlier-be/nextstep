-- Style des fenêtres de NextStep (docs/DESIGN.md, « Style des fenêtres ») : sombre et
-- doré. Aplats de couleur (texture blanche teintée), liserés dorés, boutons plats,
-- barres d'avancement et icônes, sans modèle XML du client.

local _, ns = ...

local Style = {}
ns.Style = Style

local WHITE = "Interface\\Buttons\\WHITE8X8"

Style.COLORS = {
    background = { 0.055, 0.055, 0.07, 0.96 },
    header = { 0.02, 0.02, 0.03, 0.98 },
    panel = { 0.09, 0.09, 0.11, 0.9 },
    card = { 0.12, 0.12, 0.15, 0.85 },
    cardHover = { 0.18, 0.17, 0.13, 0.95 },
    cardSelected = { 0.22, 0.18, 0.08, 0.95 },
    gold = { 1, 0.82, 0 },
    goldDim = { 0.6, 0.5, 0.25 },
    text = { 0.95, 0.95, 0.95 },
    muted = { 0.6, 0.6, 0.62 },
    blue = { 0.4, 0.8, 1 },
    green = { 0.4, 0.9, 0.4 },
    orange = { 1, 0.5, 0.25 },
    track = { 0, 0, 0, 0.6 },
}

local function unpackColor(color, alpha)
    return color[1], color[2], color[3], alpha or color[4] or 1
end

-- Aplat de couleur sur toute la surface d'un cadre (ou d'une zone donnée).
function Style.Fill(frame, color, layer)
    local texture = frame:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetTexture(WHITE)
    texture:SetAllPoints()
    texture:SetVertexColor(unpackColor(color))
    return texture
end

-- Trait horizontal (séparateur) sous un point d'ancrage.
function Style.Line(parent, color, height)
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetTexture(WHITE)
    line:SetHeight(height or 1)
    line:SetVertexColor(unpackColor(color or Style.COLORS.goldDim))
    return line
end

-- Bordure fine sur les quatre côtés d'un cadre.
function Style.Border(frame, color)
    local sides = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local texture = frame:CreateTexture(nil, "BORDER")
        texture:SetTexture(WHITE)
        texture:SetVertexColor(unpackColor(color or Style.COLORS.goldDim))
        if side == "TOP" or side == "BOTTOM" then
            texture:SetPoint(side .. "LEFT")
            texture:SetPoint(side .. "RIGHT")
            texture:SetHeight(1)
        else
            texture:SetPoint("TOP" .. side)
            texture:SetPoint("BOTTOM" .. side)
            texture:SetWidth(1)
        end
        sides[#sides + 1] = texture
    end
    return sides
end

function Style.Text(parent, template, color, justify)
    local text = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
    text:SetJustifyH(justify or "LEFT")
    if color then
        text:SetTextColor(unpackColor(color))
    end
    return text
end

-- Fenêtre principale : fond sombre, bordure dorée, barre de titre avec le logo,
-- déplaçable par la barre, fermée par la croix et Échap (name requis).
function Style.Window(name, width, height, title)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetSize(width, height)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()
    Style.Fill(frame, Style.COLORS.background)
    Style.Border(frame, Style.COLORS.goldDim)

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(36)
    Style.Fill(header, Style.COLORS.header)
    local underline = Style.Line(header, Style.COLORS.gold)
    underline:SetPoint("BOTTOMLEFT")
    underline:SetPoint("BOTTOMRIGHT")
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    frame.header = header

    local logo = header:CreateTexture(nil, "ARTWORK")
    logo:SetTexture("Interface\\AddOns\\NextStep\\Media\\IconSmall")
    logo:SetSize(26, 26)
    logo:SetPoint("LEFT", 8, 0)
    local label = Style.Text(header, "GameFontNormalLarge", Style.COLORS.gold)
    label:SetPoint("LEFT", logo, "RIGHT", 8, 0)
    label:SetText(title)
    frame.title = label

    local close = Style.Button(header, "×", 26, 26, function() frame:Hide() end)
    close:SetPoint("RIGHT", -6, 0)
    close.text:SetFontObject("GameFontNormalLarge")

    if name and UISpecialFrames then
        table.insert(UISpecialFrames, name)
    end
    return frame
end

-- Bouton plat : aplat sombre, texte doré, survol éclairé ; SetActive pour un onglet.
function Style.Button(parent, label, width, height, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    button.bg = Style.Fill(button, Style.COLORS.panel, "BACKGROUND")
    button.mark = Style.Line(button, Style.COLORS.gold, 2)
    button.mark:SetPoint("BOTTOMLEFT")
    button.mark:SetPoint("BOTTOMRIGHT")
    button.mark:Hide()
    button.text = Style.Text(button, "GameFontNormal", Style.COLORS.gold, "CENTER")
    button.text:SetPoint("CENTER")
    button.text:SetText(label)
    button:SetScript("OnEnter", function(self)
        self.bg:SetVertexColor(unpackColor(Style.COLORS.cardHover))
    end)
    button:SetScript("OnLeave", function(self)
        self.bg:SetVertexColor(unpackColor(self.active and Style.COLORS.cardSelected or Style.COLORS.panel))
    end)
    button:SetScript("OnClick", onClick)
    function button.SetActive(self, active)
        self.active = active
        self.mark:SetShown(active)
        self.bg:SetVertexColor(unpackColor(active and Style.COLORS.cardSelected or Style.COLORS.panel))
    end
    function button.SetLabel(self, text)
        self.text:SetText(text)
    end
    -- Désactivé : texte et icône estompés.
    local setEnabled = button.SetEnabled
    function button.SetEnabled(self, enabled)
        setEnabled(self, enabled)
        self.text:SetAlpha(enabled and 1 or 0.35)
        if rawget(self, "icon") then
            self.icon:SetAlpha(enabled and 1 or 0.35)
        end
    end
    return button
end

-- Bouton plat avec une icône au centre (barre de titre).
function Style.IconButton(parent, texture, size, onClick)
    local button = Style.Button(parent, "", size, size, onClick)
    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetTexture(texture)
    button.icon:SetPoint("TOPLEFT", 3, -3)
    button.icon:SetPoint("BOTTOMRIGHT", -3, 3)
    return button
end

-- Barre d'avancement dorée (0 à 1).
function Style.Progress(parent, width, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetSize(width, height or 4)
    bar:SetStatusBarTexture(WHITE)
    bar:SetStatusBarColor(unpackColor(Style.COLORS.gold))
    bar:SetMinMaxValues(0, 1)
    Style.Fill(bar, Style.COLORS.track)
    return bar
end

-- Icône carrée, coins rognés (bord des icônes du jeu).
function Style.Icon(parent, size, texture)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetSize(size, size)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    if texture then
        icon:SetTexture(texture)
    end
    return icon
end
