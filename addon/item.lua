local _, capitalize, ceil, exception, exceptional, invoke, floor, split, tcopy
    = ep.localize, ep.capitalize, math.ceil, ep.exception, ep.exceptional,
      ep.invoke, math.floor, ep.split, ep.tcopy

function itemreset()
  local id, item = next(ep.instances.instances)
  item.lc = 'bk:'..ep.character.id..':1'
  ep.character.backpack = {[1]=id, n=1, i=1}
end

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

local CONTEXT_MENU_ITEMS = {
  use = {label=_'Use', value='use'}
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
  registeredInterfaces = {},

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

  displayLocation = function(self, location, closeIfOpen)
    local manager = location.manager
    if not manager then
      manager = self:getLocationManager(location)
      if not manager then
        return exception('InvalidLocation')
      end
    end

    location = manager:validateLocation(location)
    if not exceptional(location) then
      manager:displayLocation(location, closeIfOpen)
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

  parseLocation = function(self, location)
    local manager = self.locationManagers[select(1, split(location, ':', 1))]
    if manager then
      return manager:parseLocation(location)
    else
      return exception('InvalidLocationType')
    end
  end,

  refreshInterfaces = function(self)
    for interface, method in pairs(self.registeredInterfaces) do
      if interface:IsShown() then
        method(interface)
      end
    end
  end,

  registerInterface = function(self, interface, method)
    self.registeredInterfaces[interface] = method
  end,

  validateLocation = function(self, location)
    if location.valid then
      return location
    end

    local manager = location.manager
    if not manager then
      manager = self.locationManagers[location.type]
      if not manager then
        return exception('InvalidLocationType')
      end
    end
    return manager:validateLocation(location)
  end,
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

  exchange = function(self, targetLocation, counterpart, sourceLocation, noRefresh)
    local approval
    if targetLocation then
      targetLocation = ep.items:validateLocation(targetLocation)
      if exceptional(targetLocation) then
        return targetLocation
      end
    end

    if sourceLocation then
      sourceLocation = ep.items:validateLocation(sourceLocation)
    elseif self.lc then
      sourceLocation = ep.items:parseLocation(self.lc)
    end

    if exceptional(sourceLocation) then
      return sourceLocation
    end

    local sourceManager = sourceLocation.manager
    if sourceLocation then
      approval = sourceManager:approveRemoval(sourceLocation, self, targetLocation)
      if exceptional(approval) then
        return approval
      end

      approval = sourceManager:approveAddition(sourceLocation, counterpart, targetLocation)
      if exceptional(approval) then
        return approval
      end
    end

    local targetManager = targetLocation.manager
    if targetLocation then
      approval = targetManager:approveRemoval(targetLocation, counterpart, sourceLocation)
      if exceptional(approval) then
        return approval
      end

      approval = targetManager:approveAddition(targetLocation, self, sourceLocation)
      if exceptional(approval) then
        return approval
      end
    end

    if sourceLocation then
      sourceManager:removeItem(sourceLocation, self)
      counterpart.lc = sourceManager:addItem(sourceLocation, counterpart)
    else
      counterpart.lc = nil
    end

    if targetLocation then
      targetManager:removeItem(targetLocation, counterpart)
      self.lc = targetManager:addItem(targetLocation, self)
    else
      self.lc = nil
    end

    if not noRefresh then
      ep.items:refreshInterfaces()
    end
  end,

  move = function(self, targetLocation, sourceLocation, noRefresh)
    local approval
    if targetLocation then
      targetLocation = ep.items:validateLocation(targetLocation)
      if exceptional(targetLocation) then
        return targetLocation
      end
    end

    if sourceLocation then
      sourceLocation = ep.items:validateLocation(sourceLocation)
    elseif self.lc then
      sourceLocation = ep.items:parseLocation(self.lc)
    end

    if sourceLocation then
      if not exceptional(sourceLocation) then
        approval = sourceLocation.manager:approveRemoval(sourceLocation, self, targetLocation)
        if exceptional(approval) then
          return approval
        end
      else
        sourceLocation = nil
      end
    end

    if targetLocation then
      approval = targetLocation.manager:approveAddition(targetLocation, self, sourceLocation)
      if exceptional(approval) then
        return approval
      end
    end

    if sourceLocation then
      sourceLocation.manager:removeItem(sourceLocation, self)
    end

    if targetLocation then
      self.lc = targetLocation.manager:addItem(targetLocation, self)
    else
      self.lc = nil
    end

    if not noRefresh then
      ep.items:refreshInterfaces()
    end
  end,
})

ep.Item.baseEntity = ep.Item({
  ic = 'ii',
  qu = 'c',
})

ep.ItemIconBox = ep.control('ep.ItemIconBox', 'epItemIconBox', ep.IconBox, nil, {
  wantsSelectionDrops = true,

  initialize = function(self, container, id)
    ep.IconBox.initialize(self)
    self.container = container
    self.id = id

    self:RegisterForClicks('LeftButtonUp', 'MiddleButtonUp', 'RightButtonUp')
    self:RegisterForDrag('LeftButton')
  end,

  click = function(self, mouseButton)
    local shifted, item, selection = IsShiftKeyDown(), self.item, ep.currentSelection
    if selection then
      if mouseButton == 'LeftButton' then
        if selection.button == self then
          ep.clearSelection(selection)
        elseif selection.item then
          self:dropSelection(selection)
        end
      elseif mouseButton == 'RightButton' then
        ep.clearSelection()
      end
    elseif item then
      if mouseButton == 'LeftButton' then
        if shifted then
          self:selectSplit()
        else
          ep.claimSelection({button=self, item=item}, item.ic)
        end
      elseif mouseButton == 'MiddleButton' then
        if shifted then
          self:editItem()
        else
          self:useItem()
        end
      elseif mouseButton == 'RightButton' then
        if shifted then

        else
          self:showItemMenu()
        end
      end
    else
      if mouseButton == 'RightButton' then
        self:showCreateMenu()
      end
    end
  end,

  doubleClick = function(self, mouseButton)
    local item = self.item
    if item then
      if mouseButton == 'LeftButton' then
        self:useItem()
      elseif movenent == 'RightButton' then
        self:editItem()
      end
    end
  end,

  drag = function(self)
    local shifted, item = IsShiftKeyDown(), self.item
    if item then
      selection = {button=self, item=item}
      if shifted and item.sk and item.qn and item.qn > 1 then
        selection.split = floor(item.qn / 2)
      end
      ep.claimSelection(selection, item.ic)
    end
  end,

  drop = function(self)
    local selection = ep.currentSelection
    if selection then
      if selection.button == self then
        ep.clearSelection(selection)
      elseif selection.item then
        self:dropSelection(selection)
      end
    else
      local candidate = {GetCursorInfo()}
      if #candidate > 0 then
        -- todo handle this drop
      end
    end
  end,

  dropSelection = function(self, selection)
    local sourceLocation
    if selection.button then
      sourceLocation = selection.button.location
    end

    local item, result = self.item
    if item then
      result = selection.item:exchange(self.location, item, sourceLocation, true)
      if not exceptional(result) then
        self:setItem(selection.item)
        selection.button:setItem(item)
        ep.clearSelection(selection)
      else
        D(result)
        -- TODO
      end
    else
      result = selection.item:move(self.location, sourceLocation, true)
      if not exceptional(result) then
        self:setItem(selection.item)
        if selection.button then
          selection.button:setItem(nil)
        end
        ep.clearSelection(selection)
      else
        D(result)
        -- TODO
      end
    end
  end,

  enter = function(self)
  end,

  leave = function(self)
  end,

  setItem = function(self, item)
    self.item = item
    if item then
      self:setValue(item.ic)
    else
      self:setValue(nil)
    end
  end,

  setLocation = function(self, location)
    self.location = location
  end,

  showItemMenu = function(self)

  end,

  spin = function(self, delta)
    if IsShiftKeyDown() then
      local item = self.item
      if item and item.sk then

      end
    elseif self.container.scrollbar then
      self.container.scrollbar:move(-delta)
    end
  end
})

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

    ep.items:registerInterface(self, self.update)
  end,

  close = function(self)
    self.context, self.items, self.location = nil, nil, nil
    self:Hide()
  end,

  display = function(cls, location, context, closeIfOpen)
    local collectors, collector, id = cls.collectors
    for i, frame in ipairs(collectors) do
      if frame:IsShown() and frame.location then
        if frame.location.token == location.token then
          if closeIfOpen then
            frame:close()
          end
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
        button = ep.ItemIconBox(self.name..'b'..i, self.container, self, i)
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

  dropSelection = function(self, selection, button)
    local result
    if button.item then
      
    else
      result = selection.item:move(button.location)
      if exceptional(result) then
        D(result)
      else
        ep.clearSelection(selection)
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
    if self.scrollbar:GetValue() ~= offset then
      self.scrollbar:SetValue(offset)
      return
    end

    local buttons, items, button, construct, idx, location, item = self.buttons, self.items
    construct = self.location.manager:createConstructor(self.location)

    idx = (offset * self.cols) + 1
    for i = 1, self.icons, 1 do
      button, item = buttons[i], items[idx]
      button:setLocation(construct(idx))
      if item then
        item = ep.instances:get(item)
        if item then
          button:setItem(item)
        else
          -- todo handle this condition
        end
      else
        button:setItem(nil)
      end
      idx = idx + 1
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
