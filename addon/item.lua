local ceil = math.ceil
local floor = math.floor

--[[ item schema

  ct: category            [string|nil] (local)
  cr: creator             [string|nil]
  ds: description         [string|nil]
  di: disabled            [true|nil] (local, inherited)
  fc: facets              [string|nil]
  ic: icon                [string]
  id: identifier          [string] (local, immutable, inherited)
  lc: location            [string|nil] (local)
  nm: name                [string]
  pt: protected           [true|nil] (local)
  qu: quality             [string]
  sf: soundfile           [string]
  sl: slot                [string|nil]
  wt: weight              [number|nil]

]]

ep.items = {
  name = 'ephemeral.items',
  deploy = function(self)
    do
      return
    end
    if not ephemeral.item then
      ephemeral.item = {}
    end
    if not ephemeral.item.locations then
      ephemeral.item.locations = {}
    end

    ep.item.locBackpack = 'b:'..ep.character.id
    if not ephemeral.item.locations[ep.item.locBackpack] then
      ephemeral.item.locations[ep.item.locBackpack] = {n = 0, i = 0}
    end

    ep.item.locEquipment = 'e:'..ep.character.id
    if not ephemeral.item.locations[ep.item.locEquipment] then
      ephemeral.item.locations[ep.item.locEquipment] = {n = 0, i = 0}
    end
  end,

  entities = {
    test = {cl = 'it', nm = 'testing', tg = 'ephemeral.items:test'}
  }
}

ep.item = ep.entities:define('ep.item', ep.entity, {
  cl = 'it',
  title = 'Item',

  classMenu = {{'it', 'Item'}, {'bk', 'Book'}},

  qualities = {
    Poor = 'p', p = 'Poor',
    Common = 'c', c = 'Common',
    Uncommon = 'u', u = 'Uncommon',
    Rare = 'r', r = 'Rare',
    Epic = 'e', e = 'Epic',
    Legendary = 'l', l = 'Legendary',
    Artifact = 'a', a = 'Artifact',
  },

  qualityMenu = {
    {'p', 'Poor'}, {'c', 'Common'}, {'u', 'Uncommon'}, {'r', 'Rare'},
    {'e', 'Epic'}, {'l', 'Legendary'}, {'a', 'Artifact'}
  },

  equivalentTo = function(item)
    return false;
  end,

  move = function(self, location, position, silent)
    local token
    if self:movable(location, position) then
      self:stash()
      if location ~= 's' then

      end
      if not silent then
        self:sound('drop')
      end
      self:moved(location, position)
      event('ep.item:moved', self, location, position)
    end
  end,
})

ep.item.default = ep.item({
  ic = 'ii',
  qu = 'c',
  sf = 'it',
  wt = 0.0,
})


ep.item.collectoricon = ep.control('ep.item.collectoricon', 'epItemIcon', ep.iconbox)

ep.item.collector = ep.panel('ep.item.collector', 'epItemCollector', {
  collectors = {},
  defaultIcon = 'cnwow38',

  initialize = function(self, id)
    self.id = id
    self:super():initialize({
      title = 'Container',
      resizable = true,
      onresize = self.resize,
      minsize = {207, 270},
      maxsize = {417, 522},
      initsize = {207, 354},
      stepsize = {42, 42},
    })

    self.buttons = {}
    self.cols = 0
    self.context = nil
    self.count = 0
    self.icons = 0
    self.items = nil
    self.location = nil
    self.rows = 0

    self.options.menu = ep.menu('epItemCollectorOptionsMenu', self.options, {
      callback = {self.selectOption, self},
      location = {anchor = self.options, x = 0, y = -18},
      width = self.options
    })
  end,

  close = function(self)
    self.context, self.items, self.location = nil, nil, nil
    self:Hide()
  end,

  display = function(location, context)
    local collectors, id, collector = ep.item.collector.collectors
    if ephemeral.item.locations[location] then
      for i, frame in ipairs(collectors) do
        if frame:IsShown() and frame.location then
          if frame.location == location then
            return
          end
        else
          collector = frame
          break
        end
      end
      if not collector then
        id = #collectors + 1
        collector = ep.item.collector('epItemCollector'..id, UIParent, id)
        collectors[id] = collector
        collector:layout()
      end
      collector:show(context, location)
    end
  end,

  filter = function(self)
    self.count = self.items.i + 1
    self:_updateScrollbar()
    self:update(0)
    self:updateText()
  end,

  layout = function(self)
    self.rows, self.cols = floor((self:GetHeight() - 88) / 42), floor(self:GetWidth() / 42)
    self.icons = self.rows * self.cols

    local buttons, button = #self.buttons
    if self.icons < buttons then
      for i = self.icons + 1, buttons do
        self.buttons[i]:Hide()
      end
    elseif self.icons > buttons then
      for i = buttons + 1, self.icons do
        button = ep.item.collectoricon(self.name..'b'..i, self.container)
        button.container = self
        tinsert(self.buttons, button)
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

  manipulate = function(self, button, event, movement)
    local shifted = IsShiftKeyDown()
    if event == 'click' then
      if ep.selection then
        if movement == 'LeftButton' then
          if shifted then

          elseif ep.selection.button == button then
            ep.clearSelection()
          else
            self:dropItem(ep.selection, button)
          end
        elseif movement == 'RightButton' then
          ep.items.clearSelection()
        end
      elseif button.item then
        if movement == 'LeftButton' then
          if shifted then
            self:selectSplit(button)
          else
            ep.claimSelection(button.item.ic, {
              button = button,
              item = button.item
            })
          end
        elseif movement == 'RightButton' then

        end
      end
    elseif event == 'dblclick' then

    elseif event == 'drag' then

    elseif event == 'drop' then

    elseif event == 'enter' then

    elseif event == 'leave' then

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

  selectOption = function(self, value)

  end,

  show = function(self, context, location)
    self.context, self.location = context, location
    self.items = ephemeral.item.locations[location]

    self.icon:set(context.icon or self.defaultIcon)
    if context.iconCallback then
      self.iconCallback = context.iconCallback
      self.icon:enable()
    else
      self.iconCallback = nil
      self.icon:disable()
    end
    self.iconTooltip = context.iconTooltip

    self:setTitle(context.title or 'Container')
    self.options:SetText(context.button or 'Options')

    self:filter()
    self:Show()
  end,

  update = function(self, offset)
    offset = floor(offset or self.scrollbar:GetValue())
    if self.scrollbar:GetValue() == offset then
      local idx, button, item = (offset * self.cols) + 1
      for i = 1, self.icons, 1 do
        button = self.buttons[i]
        if self.items[idx] then
          item = ep.instances:get(self.items[idx])
          if item then
            button:set(item.ic)
            button.item, button.idx = item, idx
          end
        else
          button:clear()
          button.item, button.idx = nil, nil
        end
        idx = idx + 1
      end
    else
      self.scrollbar:SetValue(offset)
    end
  end,

  updateText = function(self, count)
    local count, noun = count or self.items.n, 'items'
    if count == 1 then
      noun = 'item'
    end
    self.text:SetText(format("%s's Backpack\n|c003f3f3f%d %s|r", ep.character.name, count, noun))
  end,

  _updateScrollbar = function(self)
    self.scrollbar:SetMinMaxValues(0, max(0, ceil(self.count / self.cols) - self.rows))
  end
})

ep.item.editor = ep.panel('ep.item.editor', 'epItemEditor', {
  editors = {},

  initialize = function(self)
    self:super():initialize({
      title = 'Prop Editor',
      resizable = true,
      minsize = {410, 330},
      maxsize = {710, 630},
    })
  end,

  close = function(self, discarding)
    self:Hide()
    if not discarding then
      self:save()
    end
    epIconBrowser:close(self)
  end,

  display = function(item, location)
    local editors, id, editor = ep.item.editor.editors
    for i, frame in ipairs(editors) do
      if frame:IsShown() and frame.item then
        if frame.item == items then
          return
        end
      else
        editor = frame
        break
      end
    end
    if not editor then
      id = #editors + 1
      editor = ep.item.editor('epItemEditor'..id, UIParent, id)
      editors[id] = editor
    end
    editor:show(item, location)
  end,

  show = function(self, item, location)
    item = item or {}
    self.f_icon:set(item.ic)
    self.f_name:setValue(item.nm or '')
    self.f_quality:select(item.qu)
    self.f_creator:setValue(item.cr or '')
    self.tabs.f_description:setValue(item.ds or '')
    self.tabs.f_appearance:setValue(item.ap or '')
    self.f_stackable:check(item.st or false)
    self.f_disabled:check(item.di or false)
    self.f_protected:check(item.pt or false)

    if item.sl then
      self.f_equippable:check(true)
      self.f_slot:select(item.sl)
    else
      self.f_equippable:check(false)
      self.f_slot:select()
    end

    self:Show()
  end,
})
