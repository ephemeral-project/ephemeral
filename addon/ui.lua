local _, exceptional, floor, invoke, schedule, tcombine, tempty, tupdate
    = ep.localize, ep.exceptional, math.floor, ep.invoke, ep.schedule,
      ep.tcombine, ep.tempty, ep.tupdate

local _pendingControlArgs = {}
local _referenceFrames = {
  button = 'GameMenuButtonContinue',
  checkbox = 'AudioOptionsSoundPanelEnableSound',
  editbox = 'ChatFrame1EditBox',
  frame = 'ReputationFrame',
  messageframe = 'DEFAULT_CHAT_FRAME',
  scrollframe = 'ReputationListScrollFrame',
  slider = 'ReputationListScrollFrameScrollBar',
}

ep.controltype = ep.tcopy(ep.metatype)

ep.controltype.__call = function(proto, object, ...)
  local referrent, initializer, arguments
  if type(object) == 'string' then
    _pendingControlArgs[object] = {select(2, ...)}
    return CreateFrame(proto.__ftype, object, (...), proto.__fbase)
  end

  setmetatable(object, proto)
  if object.GetName then
    rawset(object, 'name', object:GetName())
    arguments = _pendingControlArgs[object.name]
    if arguments then
      _pendingControlArgs[object.name] = nil
    end
  end

  referrent, initializer = proto, rawget(proto, 'initialize')
  while not initializer do
    referrent = rawget(referrent, '__base')
    if referrent then
      initializer = rawget(referrent, 'initialize')
    else
      break
    end
  end

  if initializer then
    initializer(object, unpack(arguments or {...}))
  end
  return object
end

ep.basecontrol = ep.prototype('ep.basecontrol', {
  child = function(self, name)
    return _G[self.name..name]
  end,

  children = function(self, ...)
    local children, name = {...}, self.name
    for i = 1, #children, 1 do
      children[i] = _G[name..children[i]]
    end
    return unpack(children)
  end,

  event = function(self, event, ...)
    local invoke, events, subscriptions = invoke, self.events
    if events then
      subscriptions = events[event]
      if subscriptions then
        for i, invocation in ipairs(subscriptions) do
          invoke(invocation, event, ...)
        end
      end
    end
  end,

  hideBorders = function(self, ...)
    for i, value in ipairs({...}) do
      local attr = 'ce_'..value
      if self[attr] then
        self[attr]:Hide()
      end
    end
  end,

  parent = function(self, scope)
    local scope, parent = scope or 1, self:GetParent()
    while parent and scope > 1 do
      parent, scope = parent:GetParent(), scope - 1
    end
    return parent
  end,

  position = function(self, location, defaults)
    local defaults, edge, hook, x, y, anchor = defaults or {}
    if type(location) == 'table' and location.anchor then
      edge, hook = location.edge or defaults.edge or 'TOPLEFT', location.hook or defaults.hook or 'TOPRIGHT'
      anchor, x, y = location.anchor, location.x or defaults.x or 0, location.y or defaults.y or 0
    elseif location then
      edge, hook = defaults.edge or 'TOPLEFT', defaults.hook or 'TOPRIGHT'
      anchor, x, y = location, defaults.x or 0, defaults.y or 0
    else
      return
    end

    self:ClearAllPoints()
    self:SetPoint(edge, anchor, hook, x, y)
  end,

  repr = function(self)
    if rawget(self, '__prototypical') then
      return ep.metatype.repr(self)
    end

    if self.__name then
     return format("[%s('%s')]", self.__name, self.name)
    else
      return ep.repr(self, nil, true)
    end
  end,

  subscribe = function(self, event, invocation)
    local events, idx, subscriptions = self.events, 1
    event = event:lower()
    if events then
      subscriptions = events[event]
      if subscriptions then
        idx = #subscriptions + 1
        subscriptions[idx] = invocation
        if #subscriptions > 1 then
          return {event, idx}
        end
      else
        events[event] = {invocation}
      end
    else
      self.events = {[event] = {invocation}}
    end

    if not event:find(':', 1, true) then
      self:SetScript(event, function(self, ...)
        self:event(event, ...)
      end)
    end
    return {event, idx}
  end,

  unsubscribe = function(self, ref)
    local event, idx, subscriptions = unpack(ref)
    if self.events and self.events[event] then
      subscriptions = self.events[event]
      table.remove(subscriptions, idx)
      if #subscriptions == 0 and not event:find(':', 1, true) then
        self:SetScript(event, nil)
      end
    end
  end
}, ep.controltype)

function ep.control(name, declaration, base, modelname, properties)
  local ctl = ep.prototype(name, base or ep.basecontrol, properties or {}, ep.controltype)
  if _referenceFrames[modelname] then
    modelname = _referenceFrames[modelname]
  end

  if modelname then
    model = _G[modelname]
    if not model then
      d('cannot find reference frame '..modelname)
      return
    end
    for key, value in pairs(rawget(getmetatable(model), '__index')) do
      rawset(ctl, key, value)
    end
    ctl.__ftype = model:GetObjectType()
  end

  ctl.__fbase = declaration
  return ctl
end

ep.baseframe = ep.control('ep.baseframe', 'epFrame', ep.basecontrol, 'frame', {
  initialize = function(self)
    self:initializeBackground()
  end,

  initializeBackground = function(self)
    self.background:SetTexture('Interface\\AddOns\\ephemeral\\textures\\panel-background', true)
    self:scaleBackground()
    self:SetScript('OnSizeChanged', self.scaleBackground)
  end,

  scaleBackground = function(self)
    self.background:SetTexCoord(0, self:GetWidth() / 128, 0, self:GetHeight() / 128)
  end
})

ep.basepanel = ep.control('ep.basepanel', 'epPanel', ep.baseframe, nil, {
  initialize = function(self, features)
    local features, strata = features or {}
    self:SetClampedToScreen(features.clamped ~= false)
    self:SetToplevel(features.toplevel ~= false)

    strata = self:GetFrameStrata()
    self.anchor:SetFrameStrata(strata)
    self.iconifyButton:SetFrameStrata(strata)
    self.closeButton:SetFrameStrata(strata)

    self:SetMovable(features.movable ~= false)
    if features.movable == false then
      self.anchor:Hide()
    end

    features.style = features.style or 'titlebar'
    if features.style == 'titlebar' then
      self.title:SetText(features.title or '')
    else
      self.titletexture:Hide()
      self.title:Hide()
      self.hr:SetPoint('TOPRIGHT', self, 'TOPRIGHT', 0, -7)
      self.closeButton:Hide()
    end

    if features.style == 'handlebar' then
      self.hbg:Show()
      self.hdg:Show()
      if features.movable ~= false then
        self.anchor:ClearAllPoints()
        self.anchor:SetPoint('TOPLEFT', self, 'TOPLEFT', 4, -4)
        self.anchor:SetPoint('BOTTOMLEFT', self, 'BOTTOMLEFT', 4, 4)
        self.anchor:SetSize(20, 20)
      end
      if features.closeable then
        self.closeButton:ClearAllPoints()
        self.closeButton:SetPoint('BOTTOMLEFT', self, 'BOTTOMLEFT', 4, 4)
        self.closeButton:Show()
        self.anchor:SetHitRectInsets(0, 0, 0, 20)
      end
    elseif features.style == 'plain' then
      self.anchor:Hide()
    end

    self:initializeBackground()
    if features.iconifiable then
      self.iconifyButton:Show()
    end

    self:SetResizable(features.resizable == true)
    if self:IsResizable() then
      self:child('HorizontalResize'):Show()
      self:child('VerticalResize'):Show()
      self:child('FullResizeOne'):Show()
      self:child('FullResizeTwo'):Show()

      self.p_minw, self.p_minh = 0, 0
      if features.minsize then
        self.p_minw, self.p_minh = unpack(features.minsize)
      end
      self.p_maxw, self.p_maxh = 0, 0
      if features.maxsize then
        self.p_maxw, self.p_maxh = unpack(features.maxsize)
      end
      if features.initsize then
        self:SetWidth(features.initsize[1])
        self:SetHeight(features.initsize[2])
      end
      if features.stepsize then
        self.p_stepw, self.p_steph = unpack(features.stepsize)
        self.p_stepmw = self.p_minw - floor(self.p_stepw * 0.5)
        self.p_stepmh = self.p_minh - floor(self.p_steph * 0.5)
      end
      if features.onresize then
        self.p_onresize = features.onresize
      end
    end
  end,

  close = function(self)
    self:Hide()
  end,

  setTitle = function(self, title)
    self.title:SetText(title)
  end,

  startResizing = function(self, direction)
    local width, height = self:GetWidth(), self:GetHeight()
    if direction == 'horizontal' then
      self:SetMinResize(self.p_minw, height)
      self:SetMaxResize(self.p_maxw, height)
    elseif direction == 'vertical' then
      self:SetMinResize(width, self.p_minh)
      self:SetMaxResize(width, self.p_maxh)
    else
      self:SetMinResize(self.p_minw, self.p_minh)
      self:SetMaxResize(self.p_maxw, self.p_maxh)
    end

    self.p_resizing = true
    if self.p_onresize then
      invoke(self.p_onresize, self, 'before')
    end
    self:StartSizing()
  end,

  stopResizing = function(self)
    self.p_resizing = nil
    self:StopMovingOrSizing()

    if self.p_stepw then
      local width, height = ceil(self:GetWidth()), ceil(self:GetHeight())
      self:SetWidth(self.p_minw + (floor((width - self.p_stepmw) / self.p_stepw) * self.p_stepw))
      self:SetHeight(self.p_minh + (floor((height - self.p_stepmh) / self.p_steph) * self.p_steph))
    end

    if self.p_onresize then
      invoke(self.p_onresize, self, 'after')
    end
    self:scaleBackground()
  end
})

function ep.panel(name, structure, properties)
  return ep.control(name, structure, ep.basepanel, nil, properties)
end

ep.icon = ep.pseudotype{
  categories = {
    ii = {title=_'All Icons', default='interface\\icons\\inv_misc_questionmark'},
    ar = {title=_'Armor', default='interface\\icons\\inv_chest_chain'},
    bl = {title=_'Belts', default='interface\\icons\\inv_belt_04'},
    bt = {title=_'Boots', default='interface\\icons\\inv_boots_04'},
    br = {title=_'Bracers', default='interface\\icons\\inv_bracer_01'},
    cp = {title=_'Chestpieces', default='interface\\icons\\inv_chest_chain'},
    cl = {title=_'Cloaks', default='interface\\icons\\inv_misc_cape_02'},
    hm = {title=_'Helms', default='interface\\icons\\inv_helmet_51'},
    gt = {title=_'Gauntlets', default='interface\\icons\\inv_gauntlets_24'},
    jy = {title=_'Jewelry', default='interface\\icons\\inv_jewelry_ring_03'},
    rm = {title=_'Misc. Armor', default='interface\\icons\\inv_chest_chain'},
    pt = {title=_'Pants', default='interface\\icons\\inv_pants_01'},
    sd = {title=_'Shields', default='interface\\icons\\inv_shield_04'},
    sh = {title=_'Shoulders', default='interface\\icons\\inv_shoulder_09'},
    it = {title=_'Items', default='interface\\icons\\inv_misc_throwingball_01'},
    cn = {title=_'Containers', default='interface\\icons\\inv_misc_bag_01'},
    dv = {title=_'Devices', default='interface\\icons\\inv_battery_01'},
    dr = {title=_'Drinks', default='interface\\icons\\inv_drink_04'},
    fd = {title=_'Food', default='interface\\icons\\inv_misc_food_11'},
    ky = {title=_'Keys', default='interface\\icons\\inv_misc_key_01'},
    im = {title=_'Misc. Items', default='interface\\icons\\inv_misc_throwingball_01'},
    pp = {title=_'Paraphernalia', default='interface\\icons\\inv_misc_elvencoins'},
    po = {title=_'Potions', default='interface\\icons\\inv_potion_13'},
    rg = {title=_'Regalia', default='interface\\icons\\inv_shirt_guildtabard_01'},
    tp = {title=_'Trophies', default='interface\\icons\\inv_misc_bone_01'},
    tl = {title=_'Tools', default='interface\\icons\\inv_misc_wrench_01'},
    wt = {title=_'Writings', default='interface\\icons\\inv_misc_note_01'},
    mt = {title=_'Materials', default='interface\\icons\\inv_misc_dust_01'},
    ec = {title=_'Essences', default='interface\\icons\\inv_enchant_dustarcane'},
    fb = {title=_'Fabrics', default='interface\\icons\\inv_fabric_linen_01'},
    hb = {title=_'Herbs', default='interface\\icons\\inv_misc_flower_03'},
    ig = {title=_'Ingredients', default='interface\\icons\\inv_misc_dust_01'},
    mm = {title=_'Misc. Materials', default='interface\\icons\\inv_misc_dust_01'},
    mn = {title=_'Minerals', default='interface\\icons\\inv_ore_copper_01'},
    sy = {title=_'Symbols', default='interface\\icons\\trade_engineering'},
    ab = {title=_'Abilities', default='interface\\icons\\ability_meleedamage'},
    an = {title=_'Animals', default='interface\\icons\\ability_mount_ridinghorse'},
    ac = {title=_'Arcane', default='interface\\icons\\spell_arcane_arcane04'},
    el = {title=_'Elemental', default='interface\\icons\\spell_frost_stun'},
    hy = {title=_'Holy', default='interface\\icons\\spell_holy_lesserheal'},
    sm = {title=_'Misc. Symbols', default='interface\\icons\\trade_engineering'},
    nt = {title=_'Nature', default='interface\\icons\\spell_nature_earthquake'},
    sa = {title=_'Shadow', default='interface\\icons\\spell_shadow_chilltouch'},
    wp = {title=_'Weapons', default='interface\\icons\\inv_sword_04'},
    au = {title=_'Ammunition', default='interface\\icons\\inv_ammo_bullet_01'},
    ax = {title=_'Axes', default='interface\\icons\\inv_axe_01'},
    mc = {title=_'Hammers & Maces', default='interface\\icons\\inv_mace_01'},
    wm = {title=_'Misc. Weapons', default='interface\\icons\\inv_weapon_hand_01'},
    pr = {title=_'Polearms', default='interface\\icons\\inv_weapon_halbard_06'},
    ra = {title=_'Ranged', default='interface\\icons\\inv_weapon_bow_02'},
    sv = {title=_'Staves', defaults = 'interface\\icons\\inv_staff_08'},
    sw = {title=_'Swords', default='interface\\icons\\inv_sword_04'},
    wn = {title=_'Wands', default='interface\\icons\\inv_wand_01'},
  },

  precedence = {
    'bl', 'bt', 'br', 'cp', 'cl', 'hm', 'gt', 'jy', 'rm', 'pt', 'sd', 'sh',
    'cn', 'dv', 'dr', 'fd', 'ky', 'im', 'pp', 'po', 'rg', 'tp', 'tl', 'wr',
    'ec', 'fb', 'hb', 'ig', 'mm', 'mn',
    'ab', 'an', 'ac', 'el', 'hy', 'sm', 'nt', 'sa',
    'au', 'ax', 'mc', 'wm', 'pr', 'ra', 'sv', 'sw', 'wn',
  },

  levels = {
    ar = tcombine({'bl', 'bt', 'br', 'cp', 'cl', 'hm', 'gt', 'jy', 'rm', 'pt', 'sh'}, true),
    it = tcombine({'cn', 'dv', 'dr', 'fd', 'ky', 'im', 'pp', 'po', 'rg', 'tp', 'tl', 'wr'}, true),
    mt = tcombine({'ec', 'fb', 'hb', 'ig', 'mm', 'mn'}, true),
    sy = tcombine({'ab', 'an', 'ac', 'el', 'hy', 'sm', 'nt', 'sa'}, true),
    wp = tcombine({'au', 'ax', 'mc', 'wm', 'pr', 'ra', 'sv', 'sw', 'wn'}, true),
  },

  icons = {},
  sequence = {},
  sets = {},

  instantiate = function(self, id)
    local set, container, path, prefix = id:sub(3, 5)
    container = self.icons[set]
    if container and container[id] then
      path = container[id]
      prefix = container[path:sub(1, 2)] or ''
      return prefix..path:sub(3)
    elseif self.categories[id] then
      return self.categories[id].default
    else
      local category = id:sub(1, 2)
      if self.categories[category] then
        return self.categories[category].default
      else
        return self.categories['ii'].default
      end
    end
  end,

  deployIconsets = function(self)
    if tempty(self.icons) then
      for name, component in pairs(ep.deployComponents('iconset')) do
        if not exceptional(component) then
          self:_deployIconset(name, component)
        else
          -- log these
        end
      end
      return true
    end
  end,

  filterSequence = function(self, category, set)
    local categories = self.levels[category]
    if category and category ~= 'ii' and not categories then
      categories = {[category] = true}
    end
    if set == 'all' then
      set = nil
    end

    local sequence, idx, offset = {}, 1, 0
    for i, span in ipairs(self.sequence) do
      if (not categories or categories[span[1]]) and (not set or span[2] == set) then
        offset = offset + (span[4] - span[3]) + 1
        sequence[idx] = {offset, span[1]..span[2], span[3], span[4]}
        idx = idx + 1
      end
    end
    return sequence
  end,

  iterSequence = function(self, sequence, offset)
    local idx, span, id = 1
    while sequence[idx] do
      if offset <= sequence[idx][1] then
        span = sequence[idx]
        break
      else
        idx = idx + 1
      end
    end

    if not span then
      return function() return end
    end

    id = span[4] - (span[1] - offset)
    if id < 1 then
      id = 1
    end

    return function()
      if span then
        local value = span[2]..id
        if id == span[4] then
          idx = idx + 1
          span = sequence[idx]
          if span then
            id = span[3]
          end
        else
          id = id + 1
        end
        return value
      end
    end
  end,

  select = function(callback, anchor, set, category)
    epIconBrowser:display(callback, anchor, set, category)
  end,

  _deployIconset = function(self, name, iconset)
    local token = iconset.token
    self.sets[token] = iconset

    tupdate(iconset.icons, iconset.prefixes)
    self.icons[token] = iconset.icons

    if #self.sequence > 0 then
      self:_mergeSequence(iconset.sequence, iconset.official)
    else
      self.sequence = iconset.sequence
    end
  end,

  _mergeSequence = function(self, additions, prepend)
    local precedence, tindex, cmp = self.precedence, ep.tindex
    before = function(left, right)
      return tindex(precedence, left) > tindex(precedence, right)
    end

    local sequence, idx, span, prefix = self.sequence, 1, tremove(additions, 1)
    while span do
      prefix = span[1]
      while span and sequence[idx] and before(sequence[idx][1], prefix) do
        tinsert(sequence, idx, span)
        idx = idx + 1
        span = tremove(additions, 1)
        prefix = span[1]
      end
      if not span then
        break
      end
      while sequence[idx] and sequence[idx][1] ~= prefix do
        idx = idx + 1
      end
      while not prepend and sequence[idx] and sequence[idx][1] == prefix do
        idx = idx + 1
      end
      while span and span[1] == prefix do
        tinsert(sequence, idx, span)
        idx = idx + 1
        span = tremove(additions, 1)
      end
    end
  end,
}

ep.iconsets = {}

ep.sound = ep.pseudotype{
  instantiate = function(self, id)
    if self[id] then
      return self[id].default
    elseif self.files[id] then
      return self.files[id]
    else
      local category = id:sub(1, 2)
      if self[category] then
        return self[category].default
      else
        return self['ii'].default
      end
    end
  end,

  play = function(self, id, fallback)
    local soundfile = self.files[id] or self.files[fallback]
    if soundfile then
      PlaySoundFile(soundfile)
    end
  end,

  ii = {title=_'All Sounds', default=''},
  ab = {title=_'Abstract', default=''},
  bg = {title=_'Background', default=''},
  cr = {title=_'Creature', default=''},
  ev = {title=_'Environment', default=''},
  it = {title=_'Item', default=''},
  mg = {title=_'Magical', default=''},
  mi = {title=_'Miscellaneous', default=''},
}

ep.tint = ep.pseudotype{
  instantiate = function(self, color, style)
    if type(color) ~= 'table' then
      if self[color] then
        color = self[color]
      else
        color = self.default
      end
    end
    if #color == 3 then
      color[4] = 1.0
    end
    if style == 'all' then
      return {color=color, r=floor(color[1] * 255), g=floor(color[2] * 255),
        b=floor(color[3] * 255), a=floor(color[4] * 255), hex=self:toHex(color)}
    elseif style == 'token' then
      return format('|c%02x%02x%02x%02x', color[4] * 255, color[1] * 255,
        color[2] * 255, color[3] * 255)
    else
      return color
    end
  end,

  format = function(color, content)
    return ep.tint(color, 'token')..content..'|r'
  end,

  fromHex = function(value, style)
    local alpha = 1.0
    if #value == 8 then
      alpha = tonumber(value:sub(1, 2), 16) / 255
      value = value:sub(3)
    end

    return ep.tint({tonumber(value:sub(1, 2), 16) / 255,
      tonumber(value:sub(3, 4), 16) / 255,
      tonumber(value:sub(5, 6), 16) / 255, alpha}, style)
  end,

  fromRGB = function(value, style)
    local alpha = 1.0
    if #value == 4 then
      alpha = value[4] / 255
    end

    return ep.tint({value[1] / 255, value[2] / 255, value[3] / 255,
      alpha}, style)
  end,

  toHex = function(self, color)
    local alpha = color[4] or 1.0
    return format('%02x%02x%02x%02x', alpha * 255, color[1] * 255, color[2] * 255,
      color[3] * 255)
  end,

  black = {0.0, 0.0, 0.0, 1.0},
  blue = {0.0, 0.0, 1.0, 1.0},
  cyan = {0.0, 1.0, 1.0, 1.0},
  green = {0.0, 1.0, 0.0, 1.0},
  magenta = {1.0, 0.0, 1.0, 1.0},
  red = {1.0, 0.0, 0.0, 1.0},
  white = {1.0, 1.0, 1.0, 1.0},
  yellow = {1.0, 1.0, 0.0, 1.0},

  gray1 = {0.1, 0.1, 0.1, 1.0},
  gray3 = {0.3, 0.3, 0.3, 1.0},
  gray5 = {0.5, 0.5, 0.5, 1.0},
  gray7 = {0.7, 0.7, 0.7, 1.0},
  gray9 = {0.9, 0.9, 0.9, 1.0},

  bluegray = {0.37, 0.62, 0.62, 1.0},
  darkforest = {0.36, 0.54, 0.36, 1.0},
  darkgreen = {0.0, 0.5, 0.0, 1.0},
  darkmarron = {0.36, 0.54, 0.54, 1.0},
  darkteal = {0.36, 0.54, 0.54, 1.0},
  forest = {0.46, 0.64, 0.46, 1.0},
  khaki = {0.94, 0.9, 0.55, 1.0},
  lightblue = {0.69, 0.77, 0.87, 1.0},
  marron = {0.64, 0.46, 0.46, 1.0},
  orange = {1.0, 0.65, 0, 1.0},
  teal = {0.46, 0.64, 0.64, 1.0},

  console = {0.32, 0.28, 0.24, 1.0},
  label = {0.2, 0.2, 0.2, 1.0},
  principal = {0.05, 0.05, 0.05, 1.0},
  standard = {0.15, 0.15, 0.15, 1.0},

  poor = {0.62, 0.62, 0.62, 1.0},
  common = {1.0, 1.0, 1.0, 1.0},
  uncommon = {0.12, 1.0, 0.0, 1.0},
  rare = {0.0, 0.44, 0.87, 1.0},
  epic = {0.64, 0.21, 0.93, 1.0},
  legendary = {1.0, 0.5, 0.0, 1.0},
  artifact = {0.9, 0.8, 0.5, 1.0},
}

ep.tooltip = ep.control('ep.tooltip', 'epTooltip', ep.baseframe, nil, {
  defaultLocation = {edge = 'TOPLEFT', hook = 'CENTER'},

  cancel = function(self, focus)
    if self._delayFocus == focus then
      self._delayInvocation.invocation = nil
      self._delayFocus, self._delayInvocation = nil, nil
    end
  end,

  delay = function(self, delay, aspects)
    local focus, location, invocation = aspects.focus
    if not focus then
      location = aspects.location
      if type(location) == 'table' then
        focus = location.anchor or location
      else
        return
      end
    end

    if GetMouseFocus() == focus then
      self._delayFocus = focus
      invocation = function()
        self._delayFocus, self._delayInvocation = nil, nil
        if GetMouseFocus() == focus then
          self:display(aspects, true)
        end
      end
      self._delayInvocation = schedule(invocation, delay, 1)
    end
  end,

  display = function(self, aspects, alreadyDelayed)
    local offset, width = 10, 0
    if type(aspects) == 'string' then
      aspects = {c = aspects}
    elseif aspects.delay and not alreadyDelayed then
      return self:delay(aspects.delay, aspects)
    elseif aspects.generator then
      invoke(aspects.generator, aspects)
    end

    if aspects.t and #aspects.t >= 1 then
      self.t:SetText(aspects.t)
      self.t:Show()
      width = self.t:GetStringWidth()
      offset = offset + self.t:GetStringHeight() + 1
    else
      self.t:Hide()
    end

    local hwidth, hoffset = 0, 0
    if aspects.lh and #aspects.lh >= 1 then
      self.lh:SetText(aspects.lh)
      self.lh:SetPoint('TOPLEFT', self, 'TOPLEFT', 10, -offset)
      self.lh:Show()
      hwidth = self.lh:GetStringWidth()
      hoffset = offset + self.lh:GetStringHeight() + 1
    else
      self.lh:Hide()
    end

    if aspects.rh and #aspects.rh >= 1 then
      self.rh:SetText(aspects.rh)
      self.rh:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -10, -offset)
      self.rh:Show()
      hwidth = self.rh:GetStringWidth() + ((hwidth > 0) and (hwidth + 10) or 0)
      hoffset = max(hoffset, offset + self.rh:GetStringHeight() + 1)
    else
      self.rh:Hide()
    end
    width = max(width, hwidth)
    offset = max(offset, hoffset)

    local fwidth = 0
    if aspects.lf and #aspects.lf >= 1 then
      self.lf:SetText(aspects.lf)
      self.lf:Show()
      fwidth = self.lf:GetStringWidth()
    else
      self.lf:Hide()
    end

    if aspects.rf and #aspects.rf >= 1 then
      self.rf:SetText(aspects.rf)
      self.rf:Show()
      fwidth = self.rf:GetStringWidth() + ((fwidth > 0) and (fwidth + 10) or 0)
    else
      self.rf:Hide()
    end
    width = max(width, fwidth)

    if aspects.b and #aspects.b >= 1 then
      self.b:SetText(aspects.b)
      self.b:Show()
      width = max(width, self.b:GetStringWidth())
    else
      self.b:Hide()
    end

    if aspects.c and #aspects.c >= 1 then
      if width == 0 then
        self.c:SetText(aspects.c)
        width = min(300, self.c:GetStringWidth())
      else
        width = max(width, 200)
      end
      self.c:SetWidth(width)
      self.c:SetText(aspects.c)
      self.c:SetPoint('TOPLEFT', self, 'TOPLEFT', 10, -offset)
      self.c:Show()
      offset = offset + self.c:GetStringHeight() + 1
    else
      self.c:Hide()
    end

    local foffset = 0
    if self.lf:IsShown() then
      self.lf:SetPoint('TOPLEFT', self, 'TOPLEFT', 10, -offset)
      foffset = offset + self.lf:GetStringHeight() + 1
    end
    if self.rf:IsShown() then
      self.rf:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -10, -offset)
      foffset = max(foffset, offset + self.rf:GetStringHeight() + 1)
    end
    offset = max(offset, foffset)

    if self.b:IsShown() then
      self.b:SetPoint('TOPLEFT', self, 'TOPLEFT', 10, -offset)
      offset = offset + self.b:GetStringHeight() + 1
    end

    self:SetWidth(width + 20)
    self:SetHeight(offset + 10)
    self:position(aspects.location, self.defaultLocation)
    self:Show()
  end,

  hide = function(self, focus)
    self:Hide()
    if focus then
      self:cancel(focus)
    end
  end
})

function ep.attachTooltip(control, aspects, defaults)
  if control:GetScript('onenter') or control:GetScript('onleave') then
    return
  end

  if type(aspects) == 'string' then
    aspects = {c=aspects}
  end

  if not aspects.location then
    if defaults and defaults.location then
      aspects.location = defaults.location
    else
      aspects.location = control
    end
  elseif not aspects.location.anchor then
    aspects.location.anchor = control
  end

  if not aspects.delay and defaults and defaults.delay then
    aspects.delay = defaults.delay
  end

  control:SetScript('onenter', function(self)
    epTooltip:display(aspects)
  end)

  control:SetScript('onleave', function(self)
    epTooltip:hide(self)
  end)

  control.hasTooltipAttached = true
end

function ep.detachTooltip(control)
  if control.hasTooltipAttached then
    control:SetScript('onenter', nil)
    control:SetScript('onleave', nil)
    control.hasTooltipAttached = nil
  end
end
