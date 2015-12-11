local _, OrderedDict, ceil, exception, exceptional, floor, invoke, isinstance, isprototype, schedule,
      split, tcombine, tempty, tupdate
    = ep.localize, ep.OrderedDict, math.ceil, ep.exception, ep.exceptional, math.floor, ep.invoke,
      ep.isinstance, ep.isprototype, ep.schedule, ep.split, ep.tcombine, ep.tempty,
      ep.tupdate

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

ep.ControlType = ep.tcopy(ep.metatype)

ep.ControlType.__call = function(proto, object, ...)
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

ep.BaseControl = ep.prototype('ep.BaseControl', {
  __repr = function(self)
    if isprototype(self) then
      return ep.metatype.__repr(self)
    elseif self.__name then
      return format("[%s('%s')]", self.__name, self.name or '')
    end
  end,

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
      subscriptions = events[event:lower()]
      if subscriptions then
        for i, invocation in ipairs(subscriptions) do
          invoke(invocation, ...)
        end
      end
    end
  end,

  getContainingPanel = function(self)
    local panel = self.containingPanel
    if not panel then
      panel = self
      while panel do
        if isinstance(panel, ep.BasePanel) then
          self.containingPanel = panel
          break
        end
        panel = panel:GetParent()
      end
    end
    return panel
  end,

  hideBorders = function(self, ...)
    for i, value in ipairs({...}) do
      local attr = 'ce_'..value
      if self[attr] then
        self[attr]:Hide()
      end
    end
  end,

  linkSizeTo = function(self, frame, axis, size)
    axis = axis or 'both'
    if not size then
      size = {ceil(frame:GetWidth()), ceil(frame:GetHeight())}
    end

    local links = self._sizeLinks
    if links then
      links[frame] = size
    else
      links = {[frame] = size}
      self._sizeLinks = links
    end

    frame:subscribe('OnSizeChanged', function(_, _, width, height)
      local size, width, height = links[frame], ceil(width), ceil(height)
      if size then
        if size[1] ~= width and (axis == 'width' or axis == 'both') then
          self:SetWidth(self:GetWidth() + (width - size[1]))
        end
        if size[2] ~= height and (axis == 'height' or axis == 'both') then
          self:SetHeight(self:GetHeight() + (height - size[2]))
        end
      end
      links[frame] = {width, height}
    end)
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

  setBorderColors = function(self, r, g, b, a)
    self.ce_tl:SetVertexColor(r, g, b, a)
    self.ce_t:SetVertexColor(r, g, b, a)
    self.ce_tr:SetVertexColor(r, g, b, a)
    self.ce_l:SetVertexColor(r, g, b, a)
    self.ce_r:SetVertexColor(r, g, b, a)
    self.ce_bl:SetVertexColor(r, g, b, a)
    self.ce_b:SetVertexColor(r, g, b, a)
    self.ce_br:SetVertexColor(r, g, b, a)
  end,

  subscribe = function(self, event, invocation)
    local events, event, idx, subscriptions = self.events, event:lower(), 1
    if events then
      subscriptions = events[event]
      if subscriptions then
        idx = #subscriptions + 1
        subscriptions[idx] = invocation
        if #subscriptions > 1 then
          return {event, idx}
        end
      else
        subscriptions = {invocation}
        events[event] = subscriptions
      end
    else
      subscriptions = {invocation}
      self.events = {[event] = subscriptions}
    end

    if event:find(':', 1, true) then
      return {event, idx}
    end

    local script = self:GetScript(event)
    self:SetScript(event, function(self, ...)
      if script then
        script(self, ...)
      end
      for i, invocation in ipairs(subscriptions) do
        invoke(invocation, self, event, ...)
      end
    end)
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
}, ep.ControlType)

function ep.control(name, declaration, base, modelname, properties)
  local ctl = ep.prototype(name, base or ep.BaseControl, properties or {}, ep.ControlType)
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

ep.BaseFrame = ep.control('ep.Baseframe', 'epFrame', ep.BaseControl, 'frame', {
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

ep.BasePanel = ep.control('ep.BasePanel', 'epPanel', ep.BaseFrame, nil, {
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
  return ep.control(name, structure, ep.BasePanel, nil, properties)
end

ep.Color = ep.prototype('ep.Color', {
  default = {0.0, 0.0, 0.0, 1.0},
  groups = {},

  instantiate = function(cls, color, format)
    if isinstance(color, ep.Color) then
      return true, color
    end

    color = cls:parseColor(color, format)
    if exceptional(color) then
      return true, color
    else
      return false, {color}
    end
  end,

  initialize = function(self, color)
    self.color = color
  end,

  __eq = function(self, other)
    local first, second = self.color, other.color
    return (first[1] == second[1] and first[2] == second[2]
      and first[3] == second[3] and first[4] == second[4])
  end,

  __repr = function(self)
    if isprototype(self) then
      return ep.metatype.__repr(self)
    end

    local color = self.color
    return format('ep.Color(r=%0.2f, g=%0.2f, b=%0.2f, a=%0.2f)', color[1],
      color[2], color[3], color[4])
  end,

  applyToken = function(self, content)
    return self:toToken()..content..'|r'
  end,

  byName = function(cls, color)
    local candidate = cls[color]
    if candidate then
      return candidate
    end

    local group, name = split(color, '.', 1)
    if name then
      group = cls.groups[group]
      if group then
        return group[name]
      end
    else
      name = group
      for _, group in pairs(cls.groups) do
        candidate = group[name]
        if candidate then
          return candidate
        end
      end
    end
  end,

  getField = function(self, field, asRgb)
    local field, value = field:sub(1, 1)
    if field == 'r' then
      value = self.color[1]
    elseif field == 'g' then
      value = self.color[2]
    elseif field == 'b' then
      value = self.color[3]
    elseif field == 'a' then
      value = self.color[4]
    else
      return nil
    end

    if asRgb then
      value = ceil(value * 255)
    end
    return value
  end,

  hexToNative = function(color)
    if color:sub(1, 1) == '#' then
      color = color:sub(2)
    end

    local alpha = 1.0
    if #color == 8 then
      alpha = tonumber(color:sub(7, 8), 16) / 255
    end
    
    return {tonumber(color:sub(1, 2), 16) / 255,
      tonumber(color:sub(3, 4), 16) / 255,
      tonumber(color:sub(5, 6), 16) / 255, alpha}
  end,

  rgbToNative = function(color)
    local alpha = 1.0
    if #color == 4 then
      alpha = value[4] / 255
    end
    return {value[1] / 255, value[2] / 255, value[3] / 255, alpha}
  end,

  setField = function(self, field, value, isRgb)
    if isRgb or value > 1 then
      value = value / 255
    end

    field = field:sub(1, 1)
    if field == 'r' then
      self.color[1] = value
    elseif field == 'g' then
      self.color[2] = value
    elseif field == 'b' then
      self.color[3] = value
    elseif field == 'a' then
      self.color[4] = value
    end
    return self
  end,

  parseColor = function(cls, color, format)
    if type(color) == 'string' then
      if format == 'hex' or color:sub(1, 1) == '#' then
        color = cls.hexToNative(color)
      else
        color = cls:byName(color)
      end
    elseif type(color) == 'table' then
      if format == 'rgb'or color[1] > 1 or color[2] > 1 or color[3] > 1 then
        color = cls.rgbToNative(color)
      end
    else
      color = cls.default
    end

    if not color then
      return exception('InvalidValue')
    end

    if #color == 3 then
      color[4] = 1.0
    end
    return color
  end,

  setTextColor = function(self, target, alpha)
    local r, g, b, a = unpack(self:toNative(false))
    target:SetTextColor(r, g, b, alpha or a)
  end,

  setTexture = function(self, frame, alpha)
    local r, g, b, a = unpack(self:toNative(false))
    frame:SetTexture(r, g, b, alpha or a)
  end,

  toHex = function(self, excludeAlpha)
    local color, alpha = self.color, ''
    if excludeAlpha == false or (excludeAlpha ~= true and color[4] ~= 1.0) then
      alpha = format('%02x', color[4] * 255)
    end

    return format('#%02x%02x%02x%s', self.color[1] * 255, self.color[2] * 255,
      self.color[3] * 255, alpha)
  end,

  toNative = function(self, withNamedFields)
    local color = self.color
    if withNamedFields then
      return {r=color[1], g=color[2], b=color[3], a=color[4]}
    else
      return color
    end
  end,

  toRgb = function(self, excludeAlpha)
    local value = {ceil(self.color[1] * 255), ceil(self.color[2] * 255),
      ceil(self.color[3] * 255)}

    if excludeAlpha == false or (excludeAlpha ~= true and self.color[4] ~= 1.0) then
      value[4] = ceil(self.color[4] * 255)
    end
    return value
  end,

  toToken = function(self)
    local color = self.color
    return format('|cFF%02x%02x%02x', color[1] * 255, color[2] * 255, color[3] * 255)
  end,

  groups = {
    primary_colors = OrderedDict({
      'black', {0.0, 0.0, 0.0, 1.0},
      'white', {1.0, 1.0, 1.0, 1.0},
      'red', {0.957, 0.263, 0.212, 1.0},
      'pink', {0.914, 0.118, 0.388, 1.0},
      'purple', {0.612, 0.153, 0.690, 1.0},
      'violet', {0.404, 0.227, 0.718, 1.0},
      'indigo', {0.247, 0.318, 0.710, 1.0},
      'blue', {0.129, 0.588, 0.953, 1.0},
      'lightblue',  {0.012, 0.663, 0.957, 1.0},
      'cyan', {0.000, 0.737, 0.831, 1.0},
      'teal', {0.000, 0.588, 0.533, 1.0},
      'darkgreen', {0.106, 0.369, 0.125, 1.0},
      'green', {0.298, 0.686, 0.314, 1.0},
      'lightgreen', {0.545, 0.765, 0.290, 1.0},
      'lime', {0.804, 0.863, 0.224, 1.0},
      'yellow', {1.000, 0.922, 0.231, 1.0},
      'amber', {1.000, 0.757, 0.027, 1.0},
      'orange', {1.000, 0.596, 0.000, 1.0},
      'deeporange', {1.000, 0.341, 0.133, 1.0},
      'brown', {0.475, 0.333, 0.282, 1.0},
      'bluegrey', {0.376, 0.490, 0.545, 1.0},
      'grey', {0.620, 0.620, 0.620, 1.0}
    }),
    item_quality = OrderedDict({
      'poor', {0.62, 0.62, 0.62, 1.0},
      'common', {1.0, 1.0, 1.0, 1.0},
      'uncommon', {0.12, 1.0, 0.0, 1.0},
      'rare', {0.0, 0.44, 0.87, 1.0},
      'epic', {0.64, 0.21, 0.93, 1.0},
      'legendary', {1.0, 0.5, 0.0, 1.0},
      'artifact', {0.9, 0.8, 0.5, 1.0},
    })
  },

  blank = {0.0, 0.0, 0.0, 0.0},
  black = {0.0, 0.0, 0.0, 1.0},
  white = {1.0, 1.0, 1.0, 1.0},

  error = {0.55, 0.21, 0.19, 1.0},
  innerLabel = {0.25, 0.25, 0.25, 0.75},
  label = {0.2, 0.2, 0.2, 1.0},
  normal = {0.1, 0.1, 0.1, 1.0},
  title = {0.0, 0.0, 0.0, 1.0},
})

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

ep.Tooltip = ep.control('ep.Tooltip', 'epTooltip', ep.BaseFrame, nil, {
  defaultLocation = {edge='TOPLEFT', hook='CENTER'},

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

function ep.attachScalingBackground(frame, attr, texture)
  if not texture then
    texture = 'Interface\\AddOns\\ephemeral\\textures\\panel-background'
  end

  local scaleBackground = function()
    frame[attr]:SetTexCoord(0, frame:GetWidth() / 128, 0, frame:GetHeight() / 128)
  end

  frame[attr]:SetTexture(texture, true)
  frame:SetScript('OnSizeChanged', scaleBackground)
  scaleBackground()
end

function ep.detachTooltip(control)
  if control.hasTooltipAttached then
    control:SetScript('onenter', nil)
    control:SetScript('onleave', nil)
    control.hasTooltipAttached = nil
  end
end

function ep.mover(frame, point, parent)
  if not parent then
    parent = frame:GetParent()
  end

  return function(x, y)
    if not x then
      local x, y = select(4, frame:GetPoint(1))
      return x, y
    else
      frame:ClearAllPoints()
      frame:SetPoint(point, parent, point, x, y)
    end
  end
end
