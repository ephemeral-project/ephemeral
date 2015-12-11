local _, Color, ColorSpot, exception, exceptional, floor, invoke, isinstance, iterkeys,
      itersplit, max, maxn, repr, strip, tcompare, titlecase
    = ep.localize, ep.Color, ep.ColorSpot, ep.exception, ep.exceptional, math.floor,
      ep.invoke, ep.isinstance, ep.iterkeys, ep.itersplit, math.max, table.maxn, ep.repr, ep.strip,
      ep.tcompare, ep.titlecase

ep.Confirmation = ep.control('ep.Confirmation', 'epConfirmation', ep.BaseFrame, nil, {
  defaultColor = Color('normal'),
  defaultButtons = {{'OK', true}, {'Cancel', false}},
  defaultLocation = {edge='CENTER', anchor=UIParent, hook='CENTER'},

  styles = {
    compact = {minimumButtonWidth=60, minimumTextWidth=200, outerPadding=11, verticalPadding=6},
    standard = {minimumButtonWidth=100, minimumTextWidth=200, outerPadding=11, verticalPadding=12},
  },

  initialize = function(self)
    self.buttons = {}
    self:initializeBackground()
  end,

  close = function(self, value)
    self:Hide()
    if type(value) ~= nil then
      invoke(self.callback, value)
    end
    self.callback = nil
  end,

  display = function(self, params)
    local buttonWidth, style, textWidth, verticalOffset
    if not params then
      return
    end

    self.callback = params.callback

    style = self.styles[params.style or 'standard']
    buttonWidth = self:updateButtons(style, params.buttons or self.defaultButtons)

    verticalOffset = style.outerPadding
    textWidth = max(style.minimumTextWidth, buttonWidth)

    if params.title then
      self.title:SetWidth(textWidth)
      self.title:SetText(params.title)
      self.title:SetPoint('TOP', self, 'TOP', 0, -verticalOffset)

      if params.titleColor then
        Color(params.titleColor):setTextColor(self.title)
      else
        self.defaultColor:setTextColor(self.title)
      end

      self.title:Show()
      verticalOffset = verticalOffset + self.title:GetTextHeight() + 6
    else
      self.title:Hide()
    end

    self.content:SetWidth(textWidth)
    self.content:SetText(params.content)
    self.content:SetPoint('TOP', self, 'TOP', 0, -verticalOffset)

    if params.contentColor then
      Color(params.contentColor):setTextColor(self.content)
    else
      self.defaultColor:setTextColor(self.content)
    end

    verticalOffset = verticalOffset + self.content:GetTextHeight() + style.verticalPadding
    self.buttonsContainer:SetPoint('TOP', self, 'TOP', 0, -verticalOffset)

    self:SetWidth(max(buttonWidth, textWidth) + style.outerPadding)
    self:SetHeight(verticalOffset + style.outerPadding)

    self:position(aspects.location, self.defaultLocation)
    self:Show()
  end,

  updateButtons = function(self, style, candidates)
    local buttons, maxWidth = self.buttons, 0
    for i, candidate in ipairs(candidates) do
      button = buttons[i]
      if not buttons then
        button = ep.Button('epConfirmationButtons'..i, self.buttonsContainer)
        if i == 1 then
          button:SetPoint('TOPLEFT', self.buttonsContainer, 'TOPLEFT')
        else
          button:SetPoint('TOPLEFT', buttons[i - 1], 'TOPRIGHT', 4, 0)
        end

        button:SetScript('OnClick', function(this)
          self:close(this.value)
        end)
        buttons[i] = button
      end

      button.value = candidate[2]
      button:SetText(candidate[1])

      maxWidth = max(maxWidth, button:GetTextWidth())
      button:Show()
    end

    local buttonWidth = maxWidth + 10
    if buttonWidth < style.minimumButtonWidth then
      buttonWidth = style.minimumButtonWidth
    end

    for i = #candidates + 1, #buttons do
      buttons[i]:Hide()
    end

    local width = 0
    for i = 1, #candidates do
      button = self.buttons[i]
      button:SetWidth(buttonWidth)
      width = width + buttonWidth + 4
    end
    width = width - 4

    self.buttonsContainer:SetWidth(width)
    return width
  end
})

ep.ColorBrowser = ep.panel('ep.ColorBrowser', 'epColorBrowser', {
  initialize = function(self)
    self:super():initialize({
      title = _'Color Selector',
    })

    self.lowerDivider:SetVertexColor(1, 1, 1, 0.5)
  end,

  addRecentColor = function(self, color)
    local recentColors, color = self:getRecentColors(), color:toNative(false)
    for i, recentColor in ipairs(recentColors) do
      if tcompare(color, recentColor) then
        tremove(recentColors, i)
        tinsert(recentColors, 1, color)
        return
      end
    end

    tinsert(recentColors, 1, color)
    while #recentColors > 6 do
      tremove(recentColors)
    end
  end,

  cancel = function(self)
    if self.onCancel then
      invoke(self.onCancel)
    end
    self:close()
  end,

  close = function(self)
    self.onCancel, self.onSelect = nil, nil
    self:Hide()
  end,

  constructButtons = function(self)
    self.groupButtons = {}
    self.recentButtons = {}

    local x, y, id = 11, -218, 1
    for r = 1, 2 do
      for c = 1, 18 do
        self.groupButtons[id] = self:_createButton('GroupButton', id, 'TOPLEFT', x, y)
        id, x = id + 1, x + 20
      end
      x, y = 11, y - 20
    end

    x, y = -11, -198
    for id = 6, 1, -1 do
      self.recentButtons[id] = self:_createButton('RecentButton', id, 'TOPRIGHT', x, y)
      x = x - 20
    end

    local groups = {}
    for name, group in pairs(ep.Color.groups) do
      tinsert(groups, {value=name, label=titlecase(name:gsub('_', ' '))})
    end
    self.groupSelector:setOptions(groups, 'primary_colors')
  end,

  display = function(self, params)
    if not self.groupButtons then
      self:constructButtons()
    end

    params = params or {}
    self.onCancel = params.onCancel
    self.onSelect = params.onSelect

    if params.anchor then
      self:position(anchor, {x=3})
    end

    self.original = params.color or Color('default')
    if not isinstance(self.original, Color) then
      self.original = Color(self.original)
    end
    self.colors.original.texture:SetTexture(unpack(self.original:toNative()))

    self:setColor(self.original)
    self.groupSelector:setValue('primary_colors', false, true)

    self:_updateRecentColors()
    self:Show()
  end,

  getRecentColors = function(cls)
    local recentColors = ephemeral.recentColors
    if not recentColors then
      recentColors = {}
      ephemeral.recentColors = recentColors
    end
    return recentColors
  end,

  revertToOriginal = function(self)
    self:setColor(self.original)
  end,

  select = function(self)
    self:addRecentColor(self.color)
    if self.onSelect then
      invoke(self.onSelect, self.color)
    end
    self:close()
  end,

  setColor = function(self, color)
    if not isinstance(color, Color) then
      color = Color(color)
    end
    if color == self.color then
      return
    end

    self.color = color
    self:updatePresentation(source)
  end,

  setGroup = function(self, group)
    if group ~= self.group then
      self.group = group
      self:_updateGroupColors()
    end
  end,

  updatePresentation = function(self)
    local color = self.color
    self.colors.current:SetTexture(unpack(color:toNative()))

    self.wheel.suppressEvent = true
    self.wheel:SetColorRGB(unpack(color:toNative()))

    self.hexValue:setValue(color:toHex(), true)

    local rgba = color:toRgb(false)
    self.rValue:setValue(rgba[1], true)
    self.gValue:setValue(rgba[2], true)
    self.bValue:setValue(rgba[3], true)
    self.aValue:setValue(rgba[4], true)
  end,

  updateColor = function(self, slot, value)
    self.color:setField(slot, value, true)
    self:updatePresentation()
  end,

  _createButton = function(self, prefix, id, point, x, y)
    local button = ColorSpot('epColorBrowser'..prefix..id, self)
    button.id = id

    button:SetPoint(point, self, point, x, y)
    button:SetScript('OnClick', function(this)
      if this.color then
        self:setColor(this.color)
      end
    end)
    return button
  end,

  _updateGroupColors = function(self)
    local groupColors, name, color = ep.Color.groups[self.group]:iteritems()
    for i, button in ipairs(self.groupButtons) do
      name, color = groupColors()
      if name and color then
        button:enable(Color(color))
      else
        button:disable(true)
      end
    end
  end,

  _updateRecentColors = function(self)
    local recentColors, color, button = self:getRecentColors()
    for i = 1, 6 do 
      button, color = self.recentButtons[i], recentColors[i]
      if color then
        button:enable(color)
      else
        button:setValue('blank', true)
        button:disable()
      end
    end
  end
})

ep.Console = ep.panel('ep.Console', 'epConsole', {
  commands = {},

  initialize = function(self)
    self:super():initialize({
      title = 'Ephemeral '.._'Console',
      resizable = true,
      minsize = {300, 300},
      maxsize = {1000, 1000},
      initsize = {500, 600}
    })

    self.interpreter, self.debuglog = self:children('TabsInterpreter', 'TabsLog')
    self.interpreter:setFontObject(epConsoleFont)
    self.debuglog:setFontObject(epConsoleFont)
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

  log = function(self, text, color, showConsole)
    if type(text) == 'table' then
      for i, line in ipairs(text) do
        self.debuglog:append(line, color)
      end
    else
      for line in itersplit(text, '\n') do
        self.debuglog:append(line, color)
      end
    end
    if showConsole then
      self:display('log')
    end
  end,

  notify = function(self, text, color)
    for line in itersplit(text, '\n') do
      self.interpreter:append(line, color)
    end
  end,

  registerCommand = function(self, command, implementation)
  end,

  submit = function(self)
    local text = strip(self.input:getValue())
    self.input:setValue('')

    self.tabs:select(1)
    if #text == 0 then
      return
    end

    self.interpreter:append('>> '..text, ep.Color.console)
    if text ~= '.' and text ~= '\\' then
      self.input:addToHistory(text)
    end

    local results, showNil = ep.interpretInput(text), false
    if #results > 1 then
      showNil = true
    end

    local result
    for i = 1, maxn(results) do
      result = results[i]
      if exceptional(result) then
        self.interpreter:append(result.exception..': '..result.description, ep.Color.error)
      elseif type(result) == 'nil' then
        if showNil then
          self.interpreter:append('nil')
        end
      else
        self.interpreter:append(repr(result, -1))
      end
    end
  end
})

ep.Drawer = ep.panel('ep.Drawer', 'epDrawer', {
  initialize = function(self)
    self:super():initialize({
      style = 'handlebar',
      movable = false
    })
  end
})

ep.Home = ep.panel('ep.Home', 'epHome', {
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

ep.IconBrowserButton = ep.control('ep.IconBrowserButton', 'epIconBrowserButton', ep.IconBox)

ep.IconBrowser = ep.panel('ep.IconBrowser', 'epIconBrowser', {
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

    self.categoryDropbox.menu = ep.Menu('epIconBrowserCategoryMenu', self.categoryDropbox, {
      callback = {self.setCategory, self},
      items = self.categories,
      location = {anchor=self.categoryDropbox, x=0, y=-18},
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
        self.setDropbox:addOption(token, ep.icon.sets[token].title)
      end
    end

    if #self.buttons == 0 then
      self:layout()
    end

    if not self.callback then
      self.callback, self.anchor = callback, anchor
      if self.anchor then
        self:position(anchor, {edge='TOPLEFT', hook='TOPRIGHT'})
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
        tinsert(self.buttons, ep.IconBrowserButton('epIconBrowser'..i, self.container))
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
          button:setValue(icon)
          button:Show()
        else
          button:setValue()
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

ep.IconCursor = ep.control('ep.IconCursor', 'epIconCursor', ep.basecontrol, 'frame', {
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

ep.RibbonButton = ep.control('ep.RibbonButton', 'epRibbonButton', ep.iconbox, nil, {
  initialize = function(self, ribbon, id)
    self:super():initialize()
    self.id = id
    self.ribbon = ribbon
  end
})

ep.Ribbon = ep.panel('ep.Ribbon', 'epRibbon', {
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
        tinsert(self.buttons, ep.RibbonButton(self:GetName()..i, self.container, self, i))
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
