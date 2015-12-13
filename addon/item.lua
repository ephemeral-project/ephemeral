local _, capitalize, ceil, exception, exceptional, invoke, floor, split, tcopy
    = ep.localize, ep.capitalize, math.ceil, ep.exception, ep.exceptional,
      ep.invoke, math.floor, ep.split, ep.tcopy

local QUALITY_TOKENS = {
  p = _'Poor',
  c = _'Common',
  u = _'Uncommon',
  r = _'Rare',
  e = _'Epic',
  l = _'Legendary',
  a = _'Artifact'
}

local QUALITY_MENU_ITEMS = {
  {'p', _'Poor'}, {'c', _'Common'}, {'u', _'Uncommon'}, {'r', _'Rare'},
  {'e', _'Epic'}, {'l', _'Legendary'}, {'a', _'Artifact'}
}

local SLOT_TOKENS = {
  nn = _'None',
  ar = _'Arms',
  bk = _'Back',
  bd = _'Body',
  bh = _'Both Hands',
  ch = _'Chest',
  er = _'Ears',
  ey = _'Eyes',
  fc = _'Face',
  ft = _'Feet',
  fi = _'Fingers',
  gr = _'Groin',
  hr = _'Hair',
  hn = _'Hands',
  hd = _'Head',
  lg = _'Legs',
  mt = _'Mouth',
  nk = _'Neck',
  ns = _'Nose',
  pk = _'Pockets',
  sh = _'Shoulders',
  sk = _'Skin',
  wa = _'Waist',
  wr = _'Wrists'
}

local SLOT_MENU_ITEMS = {
  {'nn', _'None'}, {'ar', _'Arms'}, {'bk', _'Back'}, {'bd', _'Body'}, {'bh', _'Both Hands'},
  {'ch', _'Chest'}, {'er', _'Ears'}, {'ey', _'Eyes'}, {'fc', _'Face'}, {'ft', _'Feet'},
  {'fi', _'Fingers'}, {'gr', _'Groin'}, {'hr', _'Hair'}, {'hn', _'Hands'}, {'hd', _'Head'},
  {'lg', _'Legs'}, {'mt', _'Mouth'}, {'nk', _'Neck'}, {'ns', _'Nose'}, {'pk', _'Pockets'},
  {'sh', _'Shoulders'}, {'sk', _'Skin'}, {'wa', _'Waist'}, {'wr', _'Wrists'}
}

--[[

Item Locations:
  stash       "st"
  backpack    "bk:<char-id>[:<pos>]"
  equipment   "eq:<char-id>[:<slot>:<pos>]"
  container   "cn:<item-id>[:<pos>]"
  socket      "sk:<item-id>[:<socket>:<pos>]"
  collection  "cl:<clct-id>[:<pos>]"
  spatial     "sp:<loc-id"

]]

ep.items = {
  name = 'ephemeral:items',
  description = _'Ephemeral Items',

  locationManagers = {},

  classMenuItems = {},
  qualityMenuItems = QUALITY_MENU_ITEMS,
  qualityTokens = QUALITY_TOKENS,
  slotMenuItems = SLOT_MENU_ITEMS,
  slotTokens = SLOT_TOKENS,

  deploy = function(self)
    for i, definition in ipairs(ep.entities:enumerateDefinitions(ep.Item, true)) do
      local entry = {label=capitalize(definition.noun), value=definition.cl}
      if definition.description then
        entry.tooltip = {c=definition.description, delay=1}
      end
      tinsert(self.classMenuItems, entry)
    end

    for name, manager in pairs(ep.deployComponents('ItemLocationManager')) do
      if not exceptional(manager) and not self.locationManagers[name] then
        self.locationManagers[name] = manager
      end
    end

    for name, manager in pairs(self.locationManagers) do
      manager:deploy()
    end
  end,

  displayLocation = function(self, location)
    local manager = self:getLocationManager(location)
    if not manager then
      return exception('InvalidLocation')
    end

    location = manager:validateLocation(location)
    if not exceptional(location) then
      manager:displayLocation(location)
    else
      return location
    end
  end,

  getLocationManager = function(self, location)
    if type(location) == 'string' then
      location = select(1, split(location, ':', 1))
    else
      location = location.type
    end
    return self.locationManagers[location]
  end,

  refreshInterfaces = function(self)

  end
}

ep.Item = ep.entities:define('ep.Item', ep.Entity, {
  cl = 'it',
  noun = _'item',
  plural = _'items',
  description = _'A basic item.',

  destroy = function(self)
    local failure = self:super():destroy()
    if exceptional(failure) then
      return failure
    end

    if self.lc then
      self:move({type='st'})
    end
    ep.items:refreshInterfaces()
  end,

  determineSlot = function(self, slot)
    
  end,

  move = function(self, location)
    local targetManager = ep.items:getLocationManager(location)
    if not targetManager then
      return exception('InvalidLocationType')
    end

    local targetLocation = targetManager:validateLocation(location)
    if exceptional(targetLocation) then
      return targetLocation
    end

    local sourceLocation, sourceManager, approval
    if self.lc then
      sourceManager = ep.items:getLocationManager(self.lc)
      if sourceManager then
        sourceLocation = sourceManager:parseLocation(self.lc)
        if not exceptional(sourceLocation) then
          approval = sourceManager:approveRemoval(sourceLocation, self)
          if exceptional(approval) then
            return approval
          end
        else
          sourceLocation = nil
        end
      end
    end

    approval = targetManager:approveAddition(targetLocation, self)
    if exceptional(approval) then
      return approval
    end

    if sourceLocation then
      sourceManager:removeItem(sourceLocation, self)
    end

    self.lc = targetManager:addItem(targetLocation, self)
    ep.items:refreshInterfaces()
  end
})

ep.Item.baseEntity = ep.Item({
  ic = 'ii',
  qu = 'c',
})

ep.ItemCollectorIcon = ep.control('ep.ItemCollectorIcon', 'epItemIcon', ep.IconBox)

ep.ItemCollector = ep.panel('ep.ItemCollector', 'epItemCollector', {
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

    self.options.menu = ep.Menu('epItemCollector'..id..'OptionsMenu', self.options, {
      callback = {self.selectOption, self},
      location = {anchor = self.options, x = 0, y = -18},
      width = self.options
    })
  end,

  close = function(self)
    self.context, self.items, self.location = nil, nil, nil
    self:Hide()
  end,

  display = function(cls, location, context)
    local collectors, collector, id = cls.collectors
    for i, frame in ipairs(collectors) do
      if frame:IsShown() and frame.location then
        if frame.location.token == location.token then
          return
        end
      else
        collector = frame
        break
      end
    end

    if not collector then
      id = #collectors + 1
      collector = cls('epItemCollector'..id, UIParent, id)
      collectors[id] = collector
      collector:layout()
    end
    collector:show(location, context)
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
        button = ep.ItemCollectorIcon(self.name..'b'..i, self.container)
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

  dropSelection = function(self, button)
    
  end,

  manipulate = function(self, button, event, movement)
    local shifted, item = IsShiftKeyDown(), button.item
    if event == 'click' then
      if ep.selection then
        if movement == 'LeftButton' then
          if ep.selection.button == button then
            ep.clearSelection()
          elseif ep.selection.item then
            self:dropSelection(button)
          end
        elseif movement == 'RightButton' then
          ep.clearSelection()
        end
      elseif item then
        if movement == 'LeftButton' then
          if shifted then
            self:selectSplit(button)
          else
            ep.claimSelection({button=button,
              item=item}, item.ic)
          end
        elseif movement == 'MiddleButton' then
          if shifted then
            self:editItem(button)
          else
            self:useItem(button)
          end
        elseif movement == 'RightButton' then
          if shifted then

          else
            self:showMenu(button)
          end
        end
      else
        if movement == 'RightButton' then
          self:showCreateMenu(button)
        end
      end
    elseif event == 'dblclick' then
      if item then
        if movement == 'LeftButton' then
          self:useItem(button)
        elseif movement == 'RightButton' then
          self:editItem(button)
        end
      end
    elseif event == 'drag' then
      if item then
        local selection = {button=button, item=item}
        if shifted and item.sk and item.qn and item.qn > 1 then
          selection.split = floor(item.qn / 2)
        end
        ep.claimSelection(selection, item.ic)
      end
    elseif event == 'drop' then
      if ep.selection then
        if ep.selection.button == button then
          ep.clearSelection()
        elseif ep.selection.item then
          self:dropSelection(button)
        end
      end
    elseif event == 'enter' then

    elseif event == 'leave' then

    elseif event == 'wheel' then
      if shifted then
        if item and item.sk then

        end
      elseif self.scrollbar then
        self.scrollbar:move(-movement)
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

  selectOption = function(self, value)
  end,

  setIcon = function(self, value, isUserInput)
    if isUserInput and self.context.iconCallback then
      invoke(self.context.iconCallback, value)
    end
  end,

  show = function(self, location, context)
    self.location, self.context = location, context
    self.items = location.items

    self.icon:setValue(context.icon or self.defaultIcon)
    if context.iconCallback then
      self.icon:enable()
    else
      self.icon:disable()
    end

    self:setTitle(context.title or 'Container')
    self.options:SetText(context.buttonText or 'Options')

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
            button:setValue(item.ic)
            button.item, button.idx = item, idx
          end
        else
          button:setValue(nil)
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

ep.ItemEditor = ep.panel('ep.ItemEditor', 'epItemEditor', {
  defaultSections = {
    {label=_'Description', tooltip={c=_'$item-description-tooltip'}},
    {label=_'Capabilities', tooltip={lh=_'Capabilities',
      rh=_'Optional', c=_'$item-capabilities-tooltip'}},
    {label=_'Materials', tooltip={c=_'$item-materials-tooltip'}},
    {label=_'Sockets', tooltip={c=_'$item-sockets-tooltip'}},
    {label=_'Scripts', tooltip={c=_'$item-scripts-tooltip'}},
    {label=_'Properties', tooltip={c=_'$item-properties-tooltip'}},
    {label=_'Logs', tooltip={c=_'$item-logs-tooltip'}}
  },

  editors = {},

  initialize = function(self)
    self:super():initialize({
      title = _'Item Editor',
      resizable = true,
      minsize = {455, 350},
      maxsize = {710, 630},
    })

    self.lowerDivider:SetVertexColor(1, 1, 1, 0.5)
    self.f_class:setOptions(ep.items.classMenuItems)

    self:linkSizeTo(self.f_facets, 'height')
  end,

  close = function(self, discarding)
    self:Hide()
    if not discarding then
      self:save()
    end
    epIconBrowser:close(self)
  end,

  display = function(item, location)
    local editors, id, editor = ep.ItemEditor.editors
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
      editor = ep.ItemEditor('epItemEditor'..id, UIParent, id)
      editors[id] = editor
    end
    editor:show(item, location)
  end,

  populateFields = function(self)
    local item = self.item
    self.f_icon:setValue(item.ic)
    self.f_name:setValue(item.nm or '')
    self.f_class:setValue(item.cl)
    self.f_inscription:setValue(item.ir or '')
    self.f_quality:setValue(item.qu)
    self.f_disabled:setValue(item.di)
    self.f_protected:setValue(item.pt)
    self.f_debugging:setValue(item.db)

    if item.sl then
      self.f_equippable:setValue(true)
      self.f_slot:setValue(item.sl)
    else
      self.f_equippable:setValue(false)
      self.f_slot:setValue()
    end

    self.sections.f_description:setValue(item.ds or '')
  end,

  selectSection = function(self, row, tree)
    d(row)
  end,

  show = function(self, item, location)
    self.item = item

    local sections = tcopy(self.defaultSections)
    self.selector:populate(sections)
    
    --self:populateFields()
    self:toggleEquippable()
    self:toggleStackable()
    self:toggleWeight()
    self:Show()
  end,

  toggleEquippable = function(self)
    if self.f_equippable:GetChecked() then
      self.f_slot:enable()
    else
      self.f_slot:disable(true)
    end
  end,

  toggleStackable = function(self)
    if self.f_stackable:GetChecked() then
      self.f_quantity:enable()
    else
      self.f_quantity:disable(true)
    end
  end,

  toggleWeight = function(self)
    if self.f_hasweight:GetChecked() then
      self.f_weight:enable()
    else
      self.f_weight:disable(true)
    end
  end
})
