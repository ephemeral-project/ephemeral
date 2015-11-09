local floor = math.floor
local invoke = ep.invoke
local iterkeys = ep.iterkeys

ep.colorbrowser = ep.panel('ep.colorbrowser', 'epColorBrowser', {
    initialize = function(self)
        self:super():initialize({
            title = 'Color Browser',
        })
    end,

    display = function(self, callback, anchor)
        if not self.callback then
            self.callback, self.anchor = callback, anchor
            if self.anchor then
                self:position(anchor, {x = 3})
            end
            self:Show()
        end
    end,

    set = function(self, color, source)
        self.color = ep.tint(color, 'all')
        if source ~= 'wheel' then
            self.wheel:SetColorRGB(self.color.color[1], self.color.color[2], self.color.color[3])
        end
        self.colortexture:SetTexture(unpack(self.color.color))

    end,

    update = function(self, slot, value, control)
        ep.debug('update', {slot, value})
    end
})

ep.console = ep.panel('ep.console', 'epConsole', {
    initialize = function(self)
        self.interpreter, self.debuglog = self:children('TabsInterpreter', 'TabsLog')
        self.interpreter:set_font_object(epConsoleFont)
        self.debuglog:set_font_object(epConsoleFont)
        self:super():initialize({
            title = 'Console',
            resizable = true,
            minsize = {300, 300},
            maxsize = {1000, 1000},
            initsize = {400, 400}
        })
    end,

    display = function(self, section)
        section = section or 'interpreter'
        if not self:IsShown() then
            self:Show()
        end
        if section == 'interpreter' then
            self.tabs:select(1)
            self.input:SetFocus()
            self.input:HighlightText()
        elseif section == 'log' then
            self.tabs:select(2)
        end
    end,

    log = function(self, text, color)
        for line in ep.itersplit(text, '\n') do
            self.debuglog:append(line, color)
        end
    end,

    notify = function(self, text, color)
        for line in ep.itersplit(text, '\n') do
            self.interpreter:append(line, color)
        end
    end,

    submit = function(self)
        local text, result = ep.strip(self.input:set_value(''))
        if text then
            self.input:AddHistoryLine(text)
            self.interpreter:append('>> '..text, ep.tint.console)
            result = ep.interpret(text)
            if ep.exceptional(result) then
                self.interpreter:append('!! '..result.exception..': '..result.description)
            elseif result then
                self:notify(ep.repr(result, -1))
            end
        end
        self.tabs:select(1)
    end
})

ep.drawer = ep.panel('ep.drawer', 'epDrawer', {
    initialize = function(self)
        self:super():initialize({
            style = 'handlebar',
            movable = false
        })
    end
})

ep.home = ep.panel('ep.home', 'epHome', {
    initialize = function(self)
        self:super():initialize({
            title = 'Ephemeral',
            resizable = true,
            minsize = {400, 300},
            maxsize = {1000, 1000},
            initsize = {400, 300}
        })
    end,

    display = function(self)
        self:Show()
    end
})

ep.iconbrowserbutton = ep.control('ep.iconbrowserbutton', 'epIconBrowserButton', ep.iconbox)

ep.iconbrowser = ep.panel('ep.iconbrowser', 'epIconBrowser', {
    categories = {
        {label = 'All Icons', value = 'ii'},
        {label = 'Armor', submenu = {items = {
            {label = 'All', value = 'ar'},
            {label = 'Belts', value = 'bl'},
            {label = 'Boots', value = 'bt'},
            {label = 'Bracers', value = 'br'},
            {label = 'Chestpieces', value = 'cp'},
            {label = 'Cloaks', value = 'cl'},
            {label = 'Helms', value = 'hm'},
            {label = 'Gauntlets', value = 'gt'},
            {label = 'Jewelry', value = 'jy'},
            {label = 'Miscellaneous', value = 'rm'},
            {label = 'Pants', value = 'pt'},
            {label = 'Shields', value = 'sd'},
            {label = 'Shoulders', value = 'sh'},
        }}},
        {label = 'Items', submenu = {items = {
            {label = 'All', value = 'it'},
            {label = 'Containers', value = 'cn'},
            {label = 'Devices', value = 'dv'},
            {label = 'Drinks', value = 'dr'},
            {label = 'Food', value = 'fd'},
            {label = 'Keys', value = 'ky'},
            {label = 'Miscellaneous', value = 'im'},
            {label = 'Paraphernalia', value = 'pp'},
            {label = 'Potions', value = 'po'},
            {label = 'Regalia', value = 'rg'},
            {label = 'Trophies', value = 'tp'},
            {label = 'Tools', value = 'tl'},
            {label = 'Writings', value = 'wt'},
        }}},
        {label = 'Materials', submenu = {items = {
            {label = 'All', value = 'mt'},
            {label = 'Essences', value = 'ec'},
            {label = 'Fabrics', value = 'fb'},
            {label = 'Herbs', value = 'hb'},
            {label = 'Ingredients', value = 'ig'},
            {label = 'Miscellaneous', value = 'mm'},
            {label = 'Minerals', value = 'mn'},
        }}},
        {label = 'Symbols', submenu = {items = {
            {label = 'All', value = 'sy'},
            {label = 'Abilities', value = 'ab'},
            {label = 'Animals', value = 'an'},
            {label = 'Arcane', value = 'ac'},
            {label = 'Elemental', value = 'el'},
            {label = 'Holy', value = 'hy'},
            {label = 'Miscellaneous', value = 'sm'},
            {label = 'Nature', value = 'nt'},
            {label = 'Shadow', value = 'sa'},
        }}},
        {label = 'Weapons', submenu = {items = {
            {label = 'All', value = 'wp'},
            {label = 'Ammunition', value = 'au'},
            {label = 'Axes', value = 'ax'},
            {label = 'Hammers & Maces', value = 'mc'},
            {label = 'Miscellaneous', value = 'wm'},
            {label = 'Polearms & Spears', value = 'pr'},
            {label = 'Ranged', value = 'ra'},
            {label = 'Staves', value = 'sv'},
            {label = 'Swords & Daggers', value = 'sw'},
            {label = 'Wands', value = 'wn'},
        }}},
    },

    initialize = function(self)
        self:super():initialize({
            title = 'Icon Browser',
            resizable = true,
            onresize = self.resize,
            initsize = {249, 354},
            minsize = {249, 270},
            maxsize = {375, 480},
            stepsize = {42, 42},
        })

        self.buttons = {}
        self.cols = 0
        self.count = 0
        self.icons = 0
        self.rows = 0

        self.category_dropbox.menu = ep.menu('epIconBrowserCategoryMenu', self.category_dropbox, {
            callback = {self.set_category, self},
            items = self.categories,
            location = {anchor = self.category_dropbox, x = 0, y = -18},
            width = self.category_dropbox,
        })
    end,

    close = function(self, anchor)
        if anchor and self.anchor ~= anchor then
            return
        end
        if self.callback then
            invoke(self.callback, false)
        end
        self.callback, self.anchor = nil, nil
        self:Hide()
    end,

    display = function(self, callback, anchor, category, set)
        if ep.icon:deploy_iconsets() then
            for token in iterkeys(ep.icon.sets, true) do
                self.set_dropbox:add(token, ep.icon.sets[token].title)
            end
        end
        if #self.buttons == 0 then
            self:layout()
        end
        if not self.callback then
            self.callback, self.anchor = callback, anchor
            if self.anchor then
                self:position(anchor, {x = 3})
            end
            self:filter(category or 'ii', set or 'all')
            self:Show()
        end
    end,

    filter = function(self, category, set)
        category, set = category or self.category, set or self.set
        if category ~= self.category or set ~= self.set then
            self.category, self.set = category, set
            self.sequence = ep.icon:filter_sequence(category, set)
            if #self.sequence > 0 then
                self.count = self.sequence[#self.sequence][1]
            else
                self.count = 0
            end
            self:_update_dropboxes()
            self:_update_scrollbar()
            self:update(0)
        end
    end,

    layout = function(self)
        self.rows, self.cols = floor((self:GetHeight() - 46) / 42), floor(self:GetWidth() / 42)
        self.icons = self.rows * self.cols

        local buttons, button = #self.buttons
        if self.icons < buttons then
            for i = self.icons + 1, buttons do
                self.buttons[i]:Hide()
            end
        elseif self.icons > buttons then
            for i = buttons + 1, self.icons do
                tinsert(self.buttons, ep.iconbrowserbutton('epIconBrowser'..i, self.container))
            end
        end

        local x, y, i = 0, 0, 1
        for r = 1, self.rows do
            x = 0
            for c = 1, self.cols do
                self.buttons[i]:SetPoint('TOPLEFT', self.container, 'TOPLEFT', x, y)
                if c < self.cols then
                    x = x + 42
                end
                i = i + 1
            end
            if r < self.rows then
                y = y - 42
            end
        end
    end,

    resize = function(self, stage)
        if stage == 'before' then
            self.container:Hide()
            self.backdrop:Show()
        else
            self.backdrop:Hide()
            self:layout()
            self:_update_scrollbar()
            self:update()
            self.container:Show()
        end
    end,

    select = function(self, identifier)
        if self.callback then
            invoke(self.callback, identifier)
            self.callback, self.anchor = nil, nil
            self:Hide()
        end
    end,

    set_category = function(self, category)
        if category ~= self.category then
            self:filter(category)
        end
    end,

    set_set = function(self, set)
        if set ~= self.set then
            self:filter(nil, set)
        end
    end,

    update = function(self, offset)
        offset = floor(offset or self.scrollbar:GetValue())
        if self.scrollbar:GetValue() == offset then
            local iterator, button, icon = ep.icon:iter_sequence(self.sequence, (offset * self.cols) + 1)
            for i = 1, self.icons do
                button, icon = self.buttons[i], iterator()
                if icon then
                    button:set(icon)
                    button:Show()
                else
                    button:clear()
                    button:Hide()
                end
            end
        else
            self.scrollbar:SetValue(offset)
        end
    end,

    _update_dropboxes = function(self)
        self.category_dropbox:SetText(ep.icon.categories[self.category].title)
    end,

    _update_scrollbar = function(self)
        self.scrollbar:SetMinMaxValues(0, max(0, ceil(self.count / self.cols) - self.rows))
    end,

})

ep.iconcursor = ep.control('ep.iconcursor', 'epIconCursor', ep.basecontrol, 'frame', {
    initialize = function(self)
        self.reference = nil
        self.substrate = {'ep'}
        self.texture = nil
    end,

    activate = function(self, texture, reference)
        self.reference, self.texture = reference or true, ep.icon(texture)
        SetCursor(texture)
        self:Show()
    end,

    deactivate = function(self)
        self.reference, self.texture = nil, nil
        SetCursor(nil)
        self:Hide()
    end,

    register = function(self, prefix)
        tinsert(self.substrate, prefix)
    end,

    update = function(self)
        local focus = GetMouseFocus()
        if self.reference and focus then
            focus = focus:GetName()
            for i, prefix in ipairs(self.substrate) do
                if focus:sub(1, #prefix) == prefix then
                    SetCursor(self.texture)
                    return
                end
            end
        end
    end
})

ep.ribbonbutton = ep.control('ep.ribbonbutton', 'epRibbonButton', ep.iconbox, nil, {
    initialize = function(self, ribbon, id)
        self:super():initialize()
        self.id = id
        self.ribbon = ribbon
    end
})

ep.ribbon = ep.panel('ep.ribbon', 'epRibbon', {
    initialize = function(self, params)
        params = params or {}
        self:super():initialize({
            style = 'handlebar',
            closeable = true,
            resizable = true,
            onresize = self.resize,
            initsize = {75, 58},
            minsize = {75, 58},
            maxsize = {999, 352},
            stepsize = {42, 42}
        })

        self.buttons = {}
        self.cols = 0
        self.count = 0
        self.icons = 0
        self.rows = 0
    end,

    display = function(self)
        d(self:GetWidth())
        if #self.buttons == 0 then
            self:layout()
        end
        self:Show()
    end,

    layout = function(self)
        self.rows, self.cols = floor(self:GetHeight() / 42), floor((self:GetWidth() - 18) / 42)
        self.icons = self.rows * self.cols

        local buttons, button = #self.buttons
        if self.icons < buttons then
            for i = self.icons + 1, buttons do
                self.buttons[i]:Hide()
            end
        elseif self.icons > buttons then
            for i = buttons + 1, self.icons do
                tinsert(self.buttons, ep.ribbonbutton(self:GetName()..i, self.container, self, i))
            end
        end

        local x, y, i = 0, 0, 1
        for r = 1, self.rows do
            x = 0
            for c = 1, self.cols do
                self.buttons[i]:SetPoint('TOPLEFT', self.container, 'TOPLEFT', x, y)
                if c < self.cols then
                    x = x + 42
                end
                i = i + 1
            end
            if r < self.rows then
                y = y - 42
            end
        end
    end,

    manipulate = function(self, button, event, click)

    end,

    resize = function(self, stage)
        if stage == 'before' then
            self.container:Hide()
            self.backdrop:Show()
        else
            self.backdrop:Hide()
            self:layout()
            self:update()
            self.container:Show()
        end
    end,

    update = function(self)

    end
})
