local addonName, DF = ...

-- ============================================================
-- AURA BLACKLIST - OPTIONS GUI
-- Single-list UI for blacklisting buffs and debuffs.
-- Called from Options/Options.lua via DF.BuildAuraBlacklistPage()
-- ============================================================

local pairs, ipairs = pairs, ipairs
local tinsert = table.insert
local wipe = wipe
local CreateFrame = CreateFrame

-- ============================================================
-- MAIN PAGE BUILD
-- ============================================================

function DF.BuildAuraBlacklistPage(guiRef, pageRef, dbRef)
    -- Build frames once; subsequent calls just refresh widget data
    if pageRef._auraBlacklistBuilt then
        if pageRef._buffWidget then pageRef._buffWidget:Refresh() end
        if pageRef._debuffWidget then pageRef._debuffWidget:Refresh() end
        if pageRef._customBuffWidget then pageRef._customBuffWidget:Refresh() end
        if pageRef._customDebuffWidget then pageRef._customDebuffWidget:Refresh() end
        if pageRef._updateDropdownText then pageRef._updateDropdownText() end
        return
    end
    pageRef._auraBlacklistBuilt = true

    local GUI = guiRef
    local page = pageRef
    local parent = page.child

    -- ========== THEME ==========
    local function GetThemeColor()
        return GUI.GetThemeColor and GUI.GetThemeColor() or {r = 0.90, g = 0.55, b = 0.15}
    end

    -- ========== STATE ==========
    local selectedClass = "AUTO"

    -- Reusable frame pools
    local buffItemPool = {}
    local debuffItemPool = {}

    -- ========== BLACKLIST ACCESS ==========
    local function GetBlacklist()
        return DF.db and DF.db.auraBlacklist or { buffs = {}, debuffs = {} }
    end

    -- ========== DETECT PLAYER CLASS ==========
    local function GetPlayerClass()
        local _, classToken = UnitClass("player")
        return classToken
    end

    -- ========== RESOLVE SELECTED CLASS ==========
    local function ResolveClass()
        if selectedClass == "AUTO" then
            return GetPlayerClass()
        end
        return selectedClass
    end

    -- ========== GET ALL BUFFS FOR CLASS ==========
    local function GetAllBuffs()
        local class = ResolveClass()
        local spells = DF.AuraBlacklist and DF.AuraBlacklist.BuffSpells and DF.AuraBlacklist.BuffSpells[class]
        if not spells then return {} end
        return spells
    end

    -- ========== GET ALL DEBUFFS ==========
    local function GetAllDebuffs()
        local spells = DF.AuraBlacklist and DF.AuraBlacklist.DebuffSpells
        if not spells then return {} end
        return spells
    end

    -- ========== NOTIFY AURA SYSTEM ==========
    local function NotifyBlacklistChanged()
        -- Refresh all visible frames to re-filter auras
        if DF.RefreshAllVisibleFrames then
            DF:RefreshAllVisibleFrames()
        end
    end

    -- ========== MINI CHECKBOX HELPER ==========
    local function CreateMiniCheckbox(parentFrame, label, checked, onChange)
        local tc = GetThemeColor()
        local cb = CreateFrame("Button", nil, parentFrame)
        cb:SetSize(12, 12)

        -- Dark inset background
        local bg = cb:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.06, 0.06, 0.06, 1)

        -- Subtle border
        local border = cb:CreateTexture(nil, "BORDER")
        border:SetPoint("TOPLEFT", -1, 1)
        border:SetPoint("BOTTOMRIGHT", 1, -1)
        border:SetColorTexture(0.30, 0.30, 0.30, 1)

        -- Theme-colored fill when checked
        local fill = cb:CreateTexture(nil, "ARTWORK")
        fill:SetPoint("TOPLEFT", 2, -2)
        fill:SetPoint("BOTTOMRIGHT", -2, 2)
        fill:SetColorTexture(tc.r, tc.g, tc.b, 0.9)
        fill:SetShown(checked)

        -- Label text
        local text = cb:CreateFontString(nil, "OVERLAY")
        text:SetFont("Fonts\\FRIZQT__.TTF", 8, "")
        text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        text:SetText(label)
        text:SetTextColor(0.55, 0.55, 0.55)

        cb:SetScript("OnClick", function()
            local newState = not fill:IsShown()
            fill:SetShown(newState)
            onChange(newState)
        end)
        cb:SetScript("OnEnter", function()
            border:SetColorTexture(tc.r * 0.6, tc.g * 0.6, tc.b * 0.6, 1)
            text:SetTextColor(0.80, 0.80, 0.80)
        end)
        cb:SetScript("OnLeave", function()
            border:SetColorTexture(0.30, 0.30, 0.30, 1)
            text:SetTextColor(0.55, 0.55, 0.55)
        end)

        cb._check = fill
        return cb
    end

    -- ========== SPELL ROW (unified list item) ==========
    local function CreateSpellRow(scrollContent, spell, index, rowHeight, blacklistKey, refreshFn, keepOnDisable)
        local tc = GetThemeColor()
        local bl = GetBlacklist()
        local entry = bl[blacklistKey] and bl[blacklistKey][spell.spellId]
        local isBlacklisted = entry ~= nil and (entry == true or entry.combat or entry.ooc)

        local row = CreateFrame("Button", nil, scrollContent, "BackdropTemplate")
        row:SetHeight(rowHeight - 1)
        row:SetPoint("TOPLEFT", 0, -((index - 1) * rowHeight))
        row:SetPoint("TOPRIGHT", 0, -((index - 1) * rowHeight))
        row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
        row:EnableMouse(true)

        -- Background color based on state
        if isBlacklisted then
            row:SetBackdropColor(0.14, 0.14, 0.14, 0.95)
        else
            row:SetBackdropColor(0.08, 0.08, 0.08, 0.6)
        end

        -- Left accent bar (theme-colored, only for blacklisted)
        local accent = row:CreateTexture(nil, "ARTWORK")
        accent:SetSize(3, rowHeight - 5)
        accent:SetPoint("LEFT", 2, 0)
        accent:SetColorTexture(tc.r, tc.g, tc.b, 1)
        accent:SetShown(isBlacklisted)

        -- Spell icon
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18)
        icon:SetPoint("LEFT", 10, 0)
        icon:SetTexture(spell.icon or 134400)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        if not isBlacklisted then
            icon:SetAlpha(0.5)
        end

        -- Spell name
        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("LEFT", icon, "RIGHT", 6, 0)
        nameText:SetPoint("RIGHT", -160, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetText(spell.display)
        if isBlacklisted then
            nameText:SetTextColor(0.90, 0.90, 0.90)
        else
            nameText:SetTextColor(0.55, 0.55, 0.55)
        end

        -- Checkboxes (always visible — checked state reflects blacklist)
        local combatChecked = isBlacklisted and type(entry) == "table" and entry.combat or false
        local oocChecked = isBlacklisted and type(entry) == "table" and entry.ooc or false

        local combatCB = CreateMiniCheckbox(row, "Combat", combatChecked, function(newState)
            local blNow = GetBlacklist()
            local e = blNow[blacklistKey] and blNow[blacklistKey][spell.spellId]
            if newState and not e then
                -- Checking combat on a non-blacklisted spell — add it
                blNow[blacklistKey][spell.spellId] = { combat = true, ooc = false }
                NotifyBlacklistChanged()
                refreshFn()
                return
            end
            if type(e) == "table" then
                e.combat = newState
                if not e.combat and not e.ooc and not keepOnDisable then
                    blNow[blacklistKey][spell.spellId] = nil
                end
            end
            NotifyBlacklistChanged()
            refreshFn()
        end)
        combatCB:SetPoint("RIGHT", row, "RIGHT", keepOnDisable and -128 or -104, 0)

        local oocCB = CreateMiniCheckbox(row, "OOC", oocChecked, function(newState)
            local blNow = GetBlacklist()
            local e = blNow[blacklistKey] and blNow[blacklistKey][spell.spellId]
            if newState and not e then
                -- Checking OOC on a non-blacklisted spell — add it
                blNow[blacklistKey][spell.spellId] = { combat = false, ooc = true }
                NotifyBlacklistChanged()
                refreshFn()
                return
            end
            if type(e) == "table" then
                e.ooc = newState
                if not e.combat and not e.ooc and not keepOnDisable then
                    blNow[blacklistKey][spell.spellId] = nil
                end
            end
            NotifyBlacklistChanged()
            refreshFn()
        end)
        oocCB:SetPoint("RIGHT", row, "RIGHT", keepOnDisable and -68 or -44, 0)

        -- Remove button (custom rows only)
        if keepOnDisable then
            local removeBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
            removeBtn:SetSize(20, 20)
            removeBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
            removeBtn:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8x8",
                edgeFile = "Interface\\Buttons\\WHITE8x8",
                edgeSize = 1,
            })
            removeBtn:SetBackdropColor(0.15, 0.06, 0.06, 0.95)
            removeBtn:SetBackdropBorderColor(0.40, 0.15, 0.15, 1)

            local removeText = removeBtn:CreateFontString(nil, "OVERLAY")
            removeText:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
            removeText:SetPoint("CENTER", removeBtn, "CENTER", 1, 1)
            removeText:SetText("x")
            removeText:SetTextColor(0.8, 0.3, 0.3)

            removeBtn:SetScript("OnEnter", function(self)
                self:SetBackdropBorderColor(0.8, 0.2, 0.2, 1)
                removeText:SetTextColor(1, 0.5, 0.5)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText("Remove from blacklist", 1, 1, 1)
                GameTooltip:Show()
            end)
            removeBtn:SetScript("OnLeave", function(self)
                self:SetBackdropBorderColor(0.40, 0.15, 0.15, 1)
                removeText:SetTextColor(0.8, 0.3, 0.3)
                GameTooltip:Hide()
            end)
            removeBtn:SetScript("OnClick", function()
                local blNow = GetBlacklist()
                blNow[blacklistKey][spell.spellId] = nil
                NotifyBlacklistChanged()
                refreshFn()
            end)
        end

        -- Click row to toggle blacklist (toggle both on/off)
        row:SetScript("OnClick", function()
            local blNow = GetBlacklist()
            local e = blNow[blacklistKey][spell.spellId]
            local activelyBlacklisted = e and (e == true or e.combat or e.ooc)
            if activelyBlacklisted then
                if keepOnDisable then
                    blNow[blacklistKey][spell.spellId] = { combat = false, ooc = false }
                else
                    blNow[blacklistKey][spell.spellId] = nil
                end
            else
                blNow[blacklistKey][spell.spellId] = { combat = true, ooc = true }
            end
            NotifyBlacklistChanged()
            refreshFn()
        end)

        -- Hover effect + tooltip
        row:SetScript("OnEnter", function(self)
            if isBlacklisted then
                self:SetBackdropColor(0.18, 0.18, 0.18, 0.95)
            else
                self:SetBackdropColor(0.12, 0.12, 0.12, 0.8)
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(spell.spellId)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self)
            if isBlacklisted then
                self:SetBackdropColor(0.14, 0.14, 0.14, 0.95)
            else
                self:SetBackdropColor(0.08, 0.08, 0.08, 0.6)
            end
            GameTooltip:Hide()
        end)

        return row
    end

    -- ========== SPELL LIST WIDGET ==========
    local function CreateSpellListWidget(yAnchorFrame, yOffset, headerText, getSpellsFn, blacklistKey, itemPool, keepOnDisable)
        local ROW_HEIGHT = 28
        local LIST_WIDTH = 480
        local LIST_HEIGHT = 220

        local container = CreateFrame("Frame", nil, parent)
        container:SetSize(LIST_WIDTH, LIST_HEIGHT + 30)
        container:SetPoint("TOPLEFT", yAnchorFrame, "BOTTOMLEFT", 0, yOffset)

        -- Header
        local tc = GetThemeColor()
        local header = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetPoint("TOPLEFT", 0, 0)
        header:SetText(headerText)
        header:SetTextColor(tc.r, tc.g, tc.b)

        -- Blacklisted count (right-aligned next to header)
        local countText = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        countText:SetPoint("LEFT", header, "RIGHT", 10, 0)
        countText:SetTextColor(0.5, 0.5, 0.5)

        -- List background
        local listBg = CreateFrame("Frame", nil, container, "BackdropTemplate")
        listBg:SetPoint("TOPLEFT", 0, -18)
        listBg:SetSize(LIST_WIDTH, LIST_HEIGHT)
        listBg:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        listBg:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
        listBg:SetBackdropBorderColor(0.20, 0.20, 0.20, 1)

        -- Scroll frame
        local scrollFrame = CreateFrame("ScrollFrame", nil, listBg, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", 4, -4)
        scrollFrame:SetPoint("BOTTOMRIGHT", -24, 4)

        local scrollContent = CreateFrame("Frame", nil, scrollFrame)
        scrollContent:SetSize(LIST_WIDTH - 28, 1)
        scrollFrame:SetScrollChild(scrollContent)

        -- Empty hint
        local emptyText = listBg:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        emptyText:SetPoint("CENTER", listBg, "CENTER", 0, 0)
        emptyText:SetText("No spells available for this class")

        -- Refresh
        local function Refresh()
            -- Clear old items
            for _, item in ipairs(itemPool) do
                item:ClearAllPoints()
                item:Hide()
            end
            wipe(itemPool)

            local spells = getSpellsFn()
            emptyText:SetShown(#spells == 0)

            -- Count blacklisted
            local bl = GetBlacklist()
            local blCount = 0
            for _, spell in ipairs(spells) do
                if bl[blacklistKey][spell.spellId] then
                    blCount = blCount + 1
                end
            end
            if blCount > 0 then
                countText:SetText(blCount .. " blacklisted")
            else
                countText:SetText("")
            end

            scrollContent:SetHeight(math.max(1, #spells * ROW_HEIGHT))

            for i, spell in ipairs(spells) do
                local row = CreateSpellRow(scrollContent, spell, i, ROW_HEIGHT, blacklistKey, Refresh, keepOnDisable)
                tinsert(itemPool, row)
            end
        end

        container.Refresh = Refresh
        Refresh()

        return container
    end

    -- ========== DESCRIPTION ==========
    local desc = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", 10, -10)
    desc:SetPoint("RIGHT", -10, 0)
    desc:SetJustifyH("LEFT")
    desc:SetText("Hide specific buffs and debuffs from your frames. Click a spell to toggle blacklisting. Blacklisted auras will not appear on buff bars or Aura Designer indicators.")
    desc:SetTextColor(0.6, 0.6, 0.6)

    -- ========== CLASS DROPDOWN ==========
    local dropdownContainer = CreateFrame("Frame", nil, parent)
    dropdownContainer:SetSize(280, 55)
    dropdownContainer:SetPoint("TOPLEFT", 10, -30)

    local classLabel = dropdownContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    classLabel:SetPoint("TOPLEFT", 0, 0)
    classLabel:SetText("Class")
    classLabel:SetTextColor(0.7, 0.7, 0.7)

    -- Build dropdown items
    local classOptions = {}
    tinsert(classOptions, { value = "AUTO", text = "Auto (detect class)" })
    if DF.AuraBlacklist and DF.AuraBlacklist.ClassOrder then
        for _, classToken in ipairs(DF.AuraBlacklist.ClassOrder) do
            local className = DF.AuraBlacklist.ClassNames and DF.AuraBlacklist.ClassNames[classToken] or classToken
            tinsert(classOptions, { value = classToken, text = className })
        end
    end

    local dropdownBtn = CreateFrame("Button", nil, dropdownContainer, "BackdropTemplate")
    dropdownBtn:SetSize(200, 24)
    dropdownBtn:SetPoint("TOPLEFT", 0, -16)
    dropdownBtn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    dropdownBtn:SetBackdropColor(0.12, 0.12, 0.12, 0.95)
    dropdownBtn:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    local dropdownText = dropdownBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    dropdownText:SetPoint("LEFT", 8, 0)
    dropdownText:SetPoint("RIGHT", -20, 0)
    dropdownText:SetJustifyH("LEFT")

    local dropdownArrow = dropdownBtn:CreateTexture(nil, "OVERLAY")
    dropdownArrow:SetSize(10, 10)
    dropdownArrow:SetPoint("RIGHT", -6, 0)
    dropdownArrow:SetTexture("Interface\\Buttons\\UI-SortArrow")
    dropdownArrow:SetTexCoord(0, 1, 1, 0)

    -- Update dropdown display text
    local function UpdateDropdownText()
        for _, opt in ipairs(classOptions) do
            if opt.value == selectedClass then
                local displayText = opt.text
                if selectedClass == "AUTO" then
                    local playerClass = GetPlayerClass()
                    local playerClassName = DF.AuraBlacklist and DF.AuraBlacklist.ClassNames and DF.AuraBlacklist.ClassNames[playerClass] or playerClass
                    displayText = "Auto (" .. (playerClassName or "Unknown") .. ")"
                end
                dropdownText:SetText(displayText)
                return
            end
        end
        dropdownText:SetText("Select Class")
    end

    -- Dropdown menu (parented to UIParent so it renders above everything)
    local dropdownMenu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    dropdownMenu:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    dropdownMenu:SetBackdropColor(0.1, 0.1, 0.1, 0.98)
    dropdownMenu:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    dropdownMenu:SetFrameStrata("FULLSCREEN_DIALOG")
    dropdownMenu:SetPoint("TOPLEFT", dropdownBtn, "BOTTOMLEFT", 0, -2)
    dropdownMenu:SetSize(200, #classOptions * 22 + 4)
    dropdownMenu:Hide()

    -- Click-outside overlay to close dropdown (#441)
    local dropdownOverlay = CreateFrame("Button", nil, UIParent)
    dropdownOverlay:SetAllPoints(UIParent)
    dropdownOverlay:SetFrameStrata("FULLSCREEN")
    dropdownOverlay:Hide()
    dropdownOverlay:SetScript("OnClick", function()
        dropdownMenu:Hide()
        dropdownOverlay:Hide()
    end)

    for i, opt in ipairs(classOptions) do
        local optBtn = CreateFrame("Button", nil, dropdownMenu)
        optBtn:SetSize(196, 20)
        optBtn:SetPoint("TOPLEFT", 2, -2 - (i - 1) * 22)

        local optBg = optBtn:CreateTexture(nil, "BACKGROUND")
        optBg:SetAllPoints()
        optBg:SetColorTexture(0, 0, 0, 0)
        optBtn._bg = optBg

        local optText = optBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        optText:SetPoint("LEFT", 8, 0)
        optText:SetText(opt.text)

        optBtn:SetScript("OnEnter", function()
            optBg:SetColorTexture(0.2, 0.2, 0.2, 0.8)
        end)
        optBtn:SetScript("OnLeave", function()
            optBg:SetColorTexture(0, 0, 0, 0)
        end)
        optBtn:SetScript("OnClick", function()
            selectedClass = opt.value
            UpdateDropdownText()
            dropdownMenu:Hide()
            dropdownOverlay:Hide()
            if page._buffWidget then page._buffWidget:Refresh() end
        end)
    end

    dropdownBtn:SetScript("OnClick", function()
        if dropdownMenu:IsShown() then
            dropdownMenu:Hide()
            dropdownOverlay:Hide()
        else
            dropdownMenu:Show()
            dropdownOverlay:Show()
        end
    end)
    dropdownBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
    end)
    dropdownBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
    end)

    UpdateDropdownText()
    page._updateDropdownText = UpdateDropdownText

    -- ========== BUFF BLACKLIST WIDGET ==========
    local buffWidget = CreateSpellListWidget(
        dropdownContainer, -10, "BUFF BLACKLIST",
        GetAllBuffs, "buffs", buffItemPool
    )
    page._buffWidget = buffWidget

    -- ========== DEBUFF BLACKLIST WIDGET ==========
    local debuffWidget = CreateSpellListWidget(
        buffWidget, -20, "DEBUFF BLACKLIST",
        GetAllDebuffs, "debuffs", debuffItemPool
    )
    page._debuffWidget = debuffWidget

    -- ========== CUSTOM SPELL ID SECTION ==========

    -- Build lookup sets for preset spell IDs so custom entries can be identified
    local presetBuffIDs = {}
    local presetDebuffIDs = {}
    if DF.AuraBlacklist then
        if DF.AuraBlacklist.BuffSpells then
            for _, spells in pairs(DF.AuraBlacklist.BuffSpells) do
                for _, spell in ipairs(spells) do
                    presetBuffIDs[spell.spellId] = true
                end
            end
        end
        if DF.AuraBlacklist.DebuffSpells then
            for _, spell in ipairs(DF.AuraBlacklist.DebuffSpells) do
                presetDebuffIDs[spell.spellId] = true
            end
        end
    end

    local function GetSpellDisplayData(spellId)
        local info = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellId)
        if info and info.name then return info.name, info.iconID end
        return nil, nil
    end

    local function GetCustomEntries(blacklistKey, presetIDs)
        local bl = GetBlacklist()
        local result = {}
        for spellId in pairs(bl[blacklistKey]) do
            if not presetIDs[spellId] then
                local name, icon = GetSpellDisplayData(spellId)
                result[#result + 1] = {
                    spellId = spellId,
                    display = name or "Unknown (" .. tostring(spellId) .. ")",
                    icon = icon or 134400,
                }
            end
        end
        table.sort(result, function(a, b) return a.display < b.display end)
        return result
    end

    local customBuffItemPool = {}
    local customDebuffItemPool = {}
    local customBuffWidget, customDebuffWidget

    local function RefreshCustomLists()
        if customBuffWidget then customBuffWidget:Refresh() end
        if customDebuffWidget then customDebuffWidget:Refresh() end
    end

    -- Input container
    local tc = GetThemeColor()
    local INPUT_WIDTH = 480

    local inputContainer = CreateFrame("Frame", nil, parent)
    inputContainer:SetSize(INPUT_WIDTH, 80)
    inputContainer:SetPoint("TOPLEFT", debuffWidget, "BOTTOMLEFT", 0, -20)

    local inputHeader = inputContainer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    inputHeader:SetPoint("TOPLEFT", 0, 0)
    inputHeader:SetText("CUSTOM SPELL IDs")
    inputHeader:SetTextColor(tc.r, tc.g, tc.b)

    local inputBg = CreateFrame("Frame", nil, inputContainer, "BackdropTemplate")
    inputBg:SetPoint("TOPLEFT", 0, -18)
    inputBg:SetSize(INPUT_WIDTH, 46)
    inputBg:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    inputBg:SetBackdropColor(0.06, 0.06, 0.06, 0.95)
    inputBg:SetBackdropBorderColor(0.20, 0.20, 0.20, 1)

    -- Edit box
    local editBox = CreateFrame("EditBox", nil, inputBg, "BackdropTemplate")
    editBox:SetSize(180, 24)
    editBox:SetPoint("TOPLEFT", 8, -11)
    editBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    editBox:SetBackdropColor(0.10, 0.10, 0.10, 1)
    editBox:SetBackdropBorderColor(0.30, 0.30, 0.30, 1)
    editBox:SetAutoFocus(false)
    editBox:SetNumeric(true)
    editBox:SetMaxLetters(10)
    editBox:SetFontObject("GameFontHighlightSmall")
    editBox:SetTextInsets(6, 6, 0, 0)

    local placeholder = editBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    placeholder:SetPoint("LEFT", editBox, "LEFT", 8, 0)
    placeholder:SetText("Enter Spell ID...")
    editBox:SetScript("OnTextChanged", function(self) placeholder:SetShown(self:GetText() == "") end)
    editBox:SetScript("OnEditFocusGained", function() placeholder:Hide() end)
    editBox:SetScript("OnEditFocusLost", function(self) placeholder:SetShown(self:GetText() == "") end)

    -- Add buttons
    local function CreateAddButton(label, xOffset, blacklistKey)
        local btn = CreateFrame("Button", nil, inputBg, "BackdropTemplate")
        btn:SetSize(120, 24)
        btn:SetPoint("LEFT", editBox, "RIGHT", xOffset, 0)
        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1,
        })
        btn:SetBackdropColor(0.12, 0.12, 0.12, 0.95)
        btn:SetBackdropBorderColor(tc.r * 0.5, tc.g * 0.5, tc.b * 0.5, 1)

        local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btnText:SetAllPoints()
        btnText:SetText(label)
        btnText:SetTextColor(tc.r, tc.g, tc.b)

        btn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(tc.r, tc.g, tc.b, 1) end)
        btn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(tc.r * 0.5, tc.g * 0.5, tc.b * 0.5, 1) end)
        btn:SetScript("OnClick", function()
            local spellId = tonumber(editBox:GetText())
            if not spellId or spellId <= 0 then return end
            local name = GetSpellDisplayData(spellId)
            if not name then
                StaticPopupDialogs["DF_INVALID_SPELL_ID"] = {
                    text = "Spell ID |cFFFFFFFF" .. spellId .. "|r could not be found. Please check the ID and try again.",
                    button1 = "OK",
                    timeout = 0,
                    whileDead = true,
                    hideOnEscape = true,
                    preferredIndex = 3,
                }
                StaticPopup_Show("DF_INVALID_SPELL_ID")
                return
            end
            local bl = GetBlacklist()
            if not bl[blacklistKey][spellId] then
                bl[blacklistKey][spellId] = { combat = true, ooc = true }
                NotifyBlacklistChanged()
                RefreshCustomLists()
            end
            editBox:SetText("")
            placeholder:Show()
        end)

        return btn
    end

    CreateAddButton("Add as Buff", 8, "buffs")
    CreateAddButton("Add as Debuff", 136, "debuffs")

    -- Custom entry lists
    customBuffWidget = CreateSpellListWidget(
        inputContainer, -10, "CUSTOM BUFF BLACKLIST",
        function() return GetCustomEntries("buffs", presetBuffIDs) end,
        "buffs", customBuffItemPool, true
    )
    page._customBuffWidget = customBuffWidget

    customDebuffWidget = CreateSpellListWidget(
        customBuffWidget, -20, "CUSTOM DEBUFF BLACKLIST",
        function() return GetCustomEntries("debuffs", presetDebuffIDs) end,
        "debuffs", customDebuffItemPool, true
    )
    page._customDebuffWidget = customDebuffWidget
end
