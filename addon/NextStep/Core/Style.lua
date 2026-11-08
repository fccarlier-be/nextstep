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

-- Dégradé d'opacité d'une texture : alpha de minAlpha (bas, ou gauche) à maxAlpha
-- (haut, ou droite), dans la couleur donnée. API moderne (SetGradient + CreateColor),
-- sinon l'ancienne (SetGradientAlpha) ; sans l'une ni l'autre, aplat à maxAlpha.
function Style.Gradient(texture, orientation, color, minAlpha, maxAlpha)
    local r, g, b = color[1], color[2], color[3]
    if texture.SetGradient and CreateColor then
        local ok = pcall(texture.SetGradient, texture, orientation, CreateColor(r, g, b, minAlpha),
            CreateColor(r, g, b, maxAlpha))
        if ok then
            return texture
        end
    end
    if texture.SetGradientAlpha then
        texture:SetGradientAlpha(orientation, r, g, b, minAlpha, r, g, b, maxAlpha)
    else
        texture:SetVertexColor(r, g, b, maxAlpha)
    end
    return texture
end

-- Reflet : voile clair en haut d'un cadre, qui s'efface vers le bas (donne du relief
-- sans toucher à la couleur de fond, que le survol peut changer).
function Style.Sheen(frame, strength)
    local texture = frame:CreateTexture(nil, "BACKGROUND", nil, 2)
    texture:SetTexture(WHITE)
    texture:SetAllPoints()
    return Style.Gradient(texture, "VERTICAL", { 1, 1, 1 }, 0, strength or 0.06)
end

-- Trait doré qui s'estompe aux deux bouts (sous une barre de titre).
function Style.FadeLine(parent, color, height)
    local holder = {}
    local left = parent:CreateTexture(nil, "ARTWORK")
    left:SetTexture(WHITE)
    left:SetHeight(height or 1)
    Style.Gradient(left, "HORIZONTAL", color or Style.COLORS.gold, 0, 1)
    local right = parent:CreateTexture(nil, "ARTWORK")
    right:SetTexture(WHITE)
    right:SetHeight(height or 1)
    Style.Gradient(right, "HORIZONTAL", color or Style.COLORS.gold, 1, 0)
    function holder.Place(_, anchor, y)
        left:ClearAllPoints()
        left:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, y or 0)
        left:SetPoint("BOTTOMRIGHT", anchor, "BOTTOM", 0, y or 0)
        right:ClearAllPoints()
        right:SetPoint("BOTTOMLEFT", anchor, "BOTTOM", 0, y or 0)
        right:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, y or 0)
    end
    holder.left, holder.right = left, right
    return holder
end

-- Coins dorés : petits équerres aux quatre coins d'un cadre.
local CORNER = 9
function Style.Corners(frame, color)
    color = color or Style.COLORS.gold
    for _, corner in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        local h = frame:CreateTexture(nil, "OVERLAY")
        h:SetTexture(WHITE)
        h:SetVertexColor(color[1], color[2], color[3], 1)
        h:SetSize(CORNER, 2)
        h:SetPoint(corner)
        local v = frame:CreateTexture(nil, "OVERLAY")
        v:SetTexture(WHITE)
        v:SetVertexColor(color[1], color[2], color[3], 1)
        v:SetSize(2, CORNER)
        v:SetPoint(corner)
    end
end

-- Cadre au style NextStep : fond sombre avec reflet, ombre portée, liseré et coins dorés.
function Style.Frame(frame, borderColor)
    local bg = Style.Fill(frame, Style.COLORS.background)
    Style.Sheen(frame, 0.05)
    local shadow = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    shadow:SetTexture(WHITE)
    shadow:SetVertexColor(0, 0, 0, 0.45)
    shadow:SetPoint("TOPLEFT", -3, 3)
    shadow:SetPoint("BOTTOMRIGHT", 3, -3)
    Style.Border(frame, borderColor or Style.COLORS.goldDim)
    Style.Corners(frame)
    return bg
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
    frame:SetToplevel(true)      -- un clic la passe devant les autres fenêtres de NextStep
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()
    Style.Frame(frame)

    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(36)
    Style.Fill(header, Style.COLORS.header)
    Style.Sheen(header, 0.08)
    Style.FadeLine(header, Style.COLORS.gold):Place(header, 0)
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
    Style.Sheen(button, 0.09)
    -- Liseré discret, qui s'allume au survol.
    button.edges = Style.Border(button, { 0.6, 0.5, 0.25, 0.35 })
    local function setEdges(self, alpha)
        for _, edge in ipairs(self.edges) do
            edge:SetVertexColor(Style.COLORS.goldDim[1], Style.COLORS.goldDim[2], Style.COLORS.goldDim[3], alpha)
        end
    end
    button.mark = Style.Line(button, Style.COLORS.gold, 2)
    button.mark:SetPoint("BOTTOMLEFT")
    button.mark:SetPoint("BOTTOMRIGHT")
    button.mark:Hide()
    button.text = Style.Text(button, "GameFontNormal", Style.COLORS.gold, "CENTER")
    button.text:SetPoint("CENTER")
    button.text:SetText(label)
    button:SetScript("OnEnter", function(self)
        self.bg:SetVertexColor(unpackColor(Style.COLORS.cardHover))
        setEdges(self, 1)
    end)
    button:SetScript("OnLeave", function(self)
        self.bg:SetVertexColor(unpackColor(self.active and Style.COLORS.cardSelected or Style.COLORS.panel))
        setEdges(self, 0.35)
    end)
    -- Appui : le texte s'enfonce d'un pixel.
    button:SetScript("OnMouseDown", function(self)
        self.text:SetPoint("CENTER", 1, -1)
    end)
    button:SetScript("OnMouseUp", function(self)
        self.text:SetPoint("CENTER", 0, 0)
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
