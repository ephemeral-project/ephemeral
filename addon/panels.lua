local _, exceptional, floor, invoke, iterkeys, itersplit, repr, strip
    = ep.localize, ep.exceptional, math.floor, ep.invoke, ep.iterkeys,
      ep.itersplit, ep.repr, ep.strip

ep.colorbrowser = ep.panel('ep.colorbrowser', 'epColorBrowser', {
  initialize = function(self)
    self:super():initialize({
      title = _'Color Browser',
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
    self.interpreter:setFontObject(epConsoleFont)
    self.debuglog:setFontObject(epConsoleFont)
    self:super():initialize({
      title = 'Ephemeral '.._'Console',
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
    for line in itersplit(text, '\n') do
      self.debuglog:append(line, color)
    end
  end,

  notify = function(self, text, color)
    for line in itersplit(text, '\n') do
      self.interpreter:append(line, color)
    end
  end,

  submit = function(self)
    local text, result = strip(self.input:setValue(''))
    if text then
      self.input:AddHistoryLine(text)
      self.interpreter:append('>> '..text, ep.tint.console)
      result = ep.interpretInput(text)
      if exceptional(result) then
        self.interpreter:append('!! '..result.exception..': '..result.description)
      elseif result then
        self:notify(repr(result, -1))
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
    {label=_'All Icons', value='ii'},
    {label=_'Armor', submenu={items={
      {label=_'All', value='ar'},
      {label=_'Belts', value='bl'},
      {label=_'Boots', value='bt'},
      {label=_'Bracers', value='br'},
      {label=_'Chestpieces', value='cp'},
      {label=_'Cloaks', value='cl'},
      {label=_'Helms', value='hm'},
      {label=_'Gauntlets', value='gt'},
      {label=_'Jewelry', value='jy'},
      {label=_'Miscellaneous', value='rm'},
      {label=_'Pants', value='pt'},
      {label=_'Shields', value='sd'},
      {label=_'Shoulders', value='sh'},
    }}},
    {label=_'Items', submenu={items={
      {label=_'All', value='it'},
      {label=_'Containers', value='cn'},
      {label=_'Devices', value='dv'},
      {label=_'Drinks', value='dr'},
      {label=_'Food', value='fd'},
      {label=_'Keys', value='ky'},
      {label=_'Miscellaneous', value='im'},
      {label=_'Paraphernalia', value='pp'},
      {label=_'Potions', value='po'},
      {label=_'Regalia', value='rg'},
      {label=_'Trophies', value='tp'},
      {label=_'Tools', value='tl'},
      {label=_'Writings', value='wt'},
    }}},
    {label=_'Materials', submenu={items={
      {label=_'All', value='mt'},
      {label=_'Essences', value='ec'},
      {label=_'Fabrics', value='fb'},
      {label=_'Herbs', value='hb'},
      {label=_'Ingredients', value='ig'},
      {label=_'Miscellaneous', value='mm'},
      {label=_'Minerals', value='mn'},
    }}},
    {label=_'Symbols', submenu={items={
      {label=_'All', value='sy'},
      {label=_'Abilities', value='ab'},
      {label=_'Animals', value='an'},
      {label=_'Arcane', value='ac'},
      {label=_'Elemental', value='el'},
      {label=_'Holy', value='hy'},
      {label=_'Miscellaneous', value='sm'},
      {label=_'Nature', value='nt'},
      {label=_'Shadow', value='sa'},
    }}},
    {label=_'Weapons', submenu={items={
      {label=_'All', value='wp'},
      {label=_'Ammunition', value='au'},
      {label=_'Axes', value='ax'},
      {label=_'Hammers & Maces', value='mc'},
      {label=_'Miscellaneous', value='wm'},
      {label=_'Polearms & Spears', value='pr'},
      {label=_'Ranged', value='ra'},
      {label=_'Staves', value='sv'},
      {label=_'Swords & Daggers', value='sw'},
      {label=_'Wands', value='wn'},
    }}},
  },

  initialize = function(self)
    self:super():initialize({
      title = _'Icon Browser',
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

    self.categoryDropbox.menu = ep.menu('epIconBrowserCategoryMenu', self.categoryDropbox, {
      callback = {self.setCategory, self},
      items = self.categories,
      location = {anchor = self.categoryDropbox, x = 0, y = -18},
      width = self.categoryDropbox,
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
    if ep.icon:deployIconsets() then
      for token in iterkeys(ep.icon.sets, true) do
        self.setDropbox:add(token, ep.icon.sets[token].title)
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
    if category == self.category and set == self.set then
      return
    end

    self.category, self.set = category, set
    self.sequence = ep.icon:filterSequence(category, set)

    if #self.sequence > 0 then
      self.count = self.sequence[#self.sequence][1]
    else
      self.count = 0
    end

    self:_updateDropboxes()
    self:_updateScrollbar()
    self:update(0)
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
      self:_updateScrollbar()
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

  setCategory = function(self, category)
    if category ~= self.category then
      self:filter(category)
    end
  end,

  setSet = function(self, set)
    if set ~= self.set then
      self:filter(nil, set)
    end
  end,

  update = function(self, offset)
    offset = floor(offset or self.scrollbar:GetValue())
    if self.scrollbar:GetValue() == offset then
      local iterator, button, icon = ep.icon:iterSequence(self.sequence, (offset * self.cols) + 1)
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

  _updateDropboxes = function(self)
    self.categoryDropbox:SetText(ep.icon.categories[self.category].title)
  end,

  _updateScrollbar = function(self)
    self.scrollbar:SetMinMaxValues(0, max(0, ceil(self.count / self.cols) - self.rows))
  end
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
