local ceil, exception, exceptional, floor, inject, split
    = math.ceil, math.floor, ep.exception, ep.exceptional, ep.inject, ep.split

local QUALITIES = {
  Poor = 'p', p = 'Poor', Common = 'c', c = 'Common', Uncommon = 'u', u = 'Uncommon',
  Rare = 'r', r = 'Rare', Epic = 'e', e = 'Epic', Legendary = 'l', l = 'Legendary',
  Artifact = 'a', a = 'Artifact'
}

local QUALITY_MENU_ITEMS = {
  {'p', 'Poor'}, {'c', 'Common'}, {'u', 'Uncommon'}, {'r', 'Rare'},
  {'e', 'Epic'}, {'l', 'Legendary'}, {'a', 'Artifact'}
}

local SLOTS = {
  None = 'nn', nn = 'None',
  Arms = 'ar', ar = 'Arms',
  Back = 'bk', bk = 'Back',
  Body = 'bd', bd = 'Body',
  ['Both Hands'] = 'bh', bh = 'Both Hands',
  Chest = 'ch', ch = 'Chest',
  Ears = 'er', er = 'Ears',
  Eyes = 'ey', ey = 'Eyes',
  Face = 'fc', fc = 'Face',
  Feet = 'ft', ft = 'Feet',
  Fingers = 'fi', fi = 'Fingers',
  Groin = 'gr', gr = 'Groin',
  Hair = 'hr', hr = 'Hair',
  Hands = 'hn', hn = 'Hands',
  Head = 'hd', hd = 'Head',
  Legs = 'lg', lg = 'Legs',
  Mouth = 'mt', mt = 'Mouth',
  Neck = 'nk', nk = 'Neck',
  Nose = 'ns', ns = 'Nose',
  Pockets = 'pk', pk = 'Pockets',
  Shoulders = 'sh', sh = 'Shoulders',
  Skin = 'sk', sk = 'Skin',
  Waist = 'wa', wa = 'Waist',
  Wrists = 'wr', wr = 'Wrists'
}

local SLOTS_MENU_ITEMS = {
  {'nn', 'None'}, {'ar', 'Arms'}, {'bk', 'Back'}, {'bd', 'Body'}, {'bh', 'Both Hands'},
  {'ch', 'Chest'}, {'er', 'Ears'}, {'ey', 'Eyes'}, {'fc', 'Face'}, {'ft', 'Feet'},
  {'fi', 'Fingers'}, {'gr', 'Groin'}, {'hr', 'Hair'}, {'hn', 'Hands'}, {'hd', 'Head'},
  {'lg', 'Legs'}, {'mt', 'Mouth'}, {'nk', 'Neck'}, {'ns', 'Nose'}, {'pk', 'Pockets'},
  {'sh', 'Shoulders'}, {'sk', 'Skin'}, {'wa', 'Waist'}, {'wr', 'Wrists'}
}


--[[

Item Locations;
  "s"         stash
  "b:<id>"    character backpack
  "e:<id>"    character equipment
  "c:<id>"    container
  "n:<id>"    named collection
  "w"         in the world

]]

ep.items = {
  name = 'ephemeral:items',
  description = 'Ephemeral Items',

  slots = SLOTS,

  deploy = function(self)
    local character = ep.character
    if not character.backpack then
      character.backpack = {n = 0, i = 0}
    end
    if not character.equipment then
      character.equipment = {}
    end

    for name, provider in pairs(ep.deployComponents('locationProvider')) do
      if not exceptional(provider) and not self.locationProviders[name] then
        self.locationProviders[name] = provider
      end
    end
  end,

  getBackpack = function(self, character)
    if not character.backpack then
      character.backpack = {n = 0, i = 0}
    end
    return character.backpack
  end,

  getEquipment = function(self, character)
    if not character.equipment then
      character.equipment = {}
    end
    return character.equipment
  end,

  getLocationProvider = function(self, token)
    token = select(1, split(token, ':', 1))
    return self.locationProviders[token]
  end,

  refreshInterfaces = function(self)

  end
}

ep.item = ep.entities:define('ep.item', ep.entity, {
  cl = 'it',
  noun = 'item',
  plural = 'items',

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

  finishDestruction = function(self)
    self:remove()
    ep.items:refreshInterfaces()
  end,

  move = function(self, location)
    local targetProvider = ep.items:getLocationProvider(location.type)
    if not targetProvider then
      return exception('InvalidLocation')
    end

    local targetLocation = targetProvider:validateLocation(self, location)
    if exceptional(targetLocation) then
      return targetLocation
    end

    local sourceLocation, sourceProvider, approval
    if self.lc then
      sourceProvider = ep.items:getLocationProvider(self.lc)
      if sourceProvider then
        sourceLocation = sourceProvider:parseLocation(self.lc)
        if not exceptional(sourceLocation) then
          approval = sourceProvider:approveRemoval(self, sourceLocation)
          if exceptional(approval) then
            return approval
          end

          approval = self:approveRemoval(sourceLocation)
          if exceptional(approval) then
            return approval
          end
        else
          sourceLocation = nil
        end
      end
    end

    approval = targetProvider:approveMove(self, targetLocation)
    if exceptional(approval) then
      return approval
    end

    if sourceLocation then
      sourceProvider:remove(self, sourceLocation)
    end

    self.lc = targetProvider:move(self, targetLocation)
    ep.items:refreshInterfaces()
  end
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

    self.options.menu = ep.menu('epItemCollector'..id..'OptionsMenu', self.options, {
      callback = {self.selectOption, self},
      location = {anchor = self.options, x = 0, y = -18},
      width = self.options
    })
  end,

  close = function(self)
    self.context, self.items, self.location = nil, nil, nil
    self:Hide()
  end,

  display = function(cls, location, items, context)
    local collectors, id, collector = cls.collectors
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
      collector = cls('epItemCollector'..id, UIParent, id)
      collectors[id] = collector
      collector:layout()
    end
    collector:show(location, items, context)
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

  show = function(self, location, items, context)
    self.context = context
    self.items = items
    self.location = location

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
