local clear = ep.clear
local concat = table.concat
local exception = ep.exception
local exceptional = ep.exceptional
local format = string.format
local invoke = ep.invoke
local itersplit = ep.itersplit
local ref = ep.ref
local put = ep.put
local split = ep.split
local surrogate = ep.surrogate
local tinsert = table.insert
local tremove = table.remove

local addons = {}
local components = {}
local events = {}
local invocations = ep.pqueue('delta')
local modules = {}

local _characterGenders = {'unknown', 'male', 'female'}
local _schedulingTicks = 0
local _uniqidEntropy = 0

ep.addons = addons
ep.components = components
ep.events = events
ep.invocations = invocations
ep.modules = modules
ep.selection = nil

function ep.claimSelection(selection, icon)
  ep.selection = selection
  epIconCursor:activate(icon or selection.ic)
end

function ep.clearSelection(selection)
  if not selection or ep.selection == selection then
    ep.selection = nil
    epIconCursor:deactivate()
  end
end

function ep.deployModule(module, onlyIfDeployed)
  local name, addon, result, dependency, version, impl
  if type(module) == 'string' then
    name, module = module, modules[module]
  end

  if not module then
    if name then
      return exception('DeployFailed', format("unknown module '%s'", name))
    else
      return exception('DeployFailed', 'invalid module specification')
    end
  end

  name = module.name
  if module.deployed then
    return module.implementation
  elseif onlyIfDeployed then
    return exception('DeployRequired', 'requested module not yet deployed')
  end

  addon = addons[module.addon]
  if not addon.loaded then
    result = ep._loadAddon(addon)
    if exceptional(result) then
      return result
    elseif module.deployed then
      return module.implementation
    end
  end

  if module.dependencies then
    for dependency, version in pairs(module.dependencies) do
      dependency = modules[dependency]
      if not dependency then
        return exception('DeployFailed', 'invalid dependency')
      elseif dependency.version < version then
        return exception('DeployFailed', 'invalid dependency version')
      elseif not dependency.deployed then
        result = ep.deployModule(dependency)
        if exceptional(result) then
          return result
        end
      end
    end
  end

  impl = ref(module.path)
  if impl and impl.__modular then
    module.implementation = impl
  else
    return exception('DeployFailed', 'invalid module')
  end

  version = ephemeral.versions[name]
  if version then
    if version < module.version and impl.upgrade then
      result = impl:upgrade(version)
      if exceptional(result) then
        return result
      end
    elseif version > module.version then
      return exception('VersionIssue')
    end
  end

  ephemeral.versions[name] = module.version
  if impl.deploy then
    result = impl:deploy()
    if exceptional(result) then
      return result
    end
  end

  module.deployed, module.enabled = true, true
  return impl
end

function ep.event(event, ...)
  local subscriptions, invoke, invocation = events[event], invoke
  if subscriptions then
    for i, invocation in ipairs(subscriptions) do
      invoke(invocation, event, ...)
    end
  end
end

function ep.ingroup(name, connected)
  local name, unit = name:lower()
  if GetNumRaidMembers() > 0 then
    for i = 1, GetNumRaidMembers(), 1 do
      unit = 'raid'..i
      if UnitName(unit):lower() == name and (not connected or UnitIsConnected(unit)) then
        return true
      end
    end
  elseif GetNumPartyMembers() > 0 then
    for i = 1, GetNumPartyMembers(), 1 do
      unit = 'party'..i
      if UnitName(unit):lower() == name and (not connected or UnitIsConnected(unit)) then
        return true
      end
    end
  end
  return false
end

function ep.inguild(name, connected)
  local name, member, online = name:lower()
  if IsInGuild() then
    for i = 1, GetNumGuildMembers(), 1 do
      info = {GetGuildRosterInfo(i)}
      if info[1]:lower() == name and (info[9] or not connected) then
        return true
      end
    end
  end
  return false
end

function ep.interpret(text)
  local tokens, script, err, result, reference
  if text then
    if text == GetBindingKey('RELOADUI') then
      ReloadUI()
    end

    script, err = loadstring('return '..text)
    if not script then
      script, err = loadstring(text)
    end

    if script then
      result = {pcall(script)}
      if tremove(result, 1) then
        if #result == 1 then
          return result[1]
        elseif #result > 1 then
          return result
        end
      else
        return exception('LuaError', result[1])
      end
    elseif not text:find('[^%.%[%]%w]') then
      return ref(text)
    else
      return exception('LuaError', err)
    end
  end
end

function ep.isfriend(name, connected)
  local name, friend = name:lower()
  for i = 1, GetNumFriends(), 1 do
    friend = {GetFriendInfo(i)}
    if friend[1]:lower() == name and (not connected or friend[5]) then
      return true
    end
  end
  return false
end

function ep.getItemText(close)
  local item = {
    name = ItemTextGetItem(),
    creator = ItemTextGetCreator(),
    material = ItemTextGetMaterial(),
    content = {}
  }

  while ItemTextGetPage() > 1 do
    ItemTextPrevPage()
  end

  tinsert(item.content, ItemTextGetText())
  while ItemTextHasNextPage() do
    ItemTextNextPage()
    tinsert(item.content, ItemTextGetText())
  end

  if close then
    CloseItemText()
  end
  return item
end

function ep.loadComponent(class, name)
  local registrations = components[class]
  if not (registrations and registrations[name]) then
    return exception('ComponentNotFound')
  end

  local component = registrations[name]
  if type(component) == 'table' then
    return component
  end

  local result = ep.deployModule(component)
  if exceptional(result) then
    return result
  end

  component = ref(name)
  if not component then
    return exception('ComponentNotFound')
  end

  registrations[name] = component
  return component
end

function ep.getMemoryUsage()
  local stats, report, value, name, title, notes, enabled = {}, {}
  UpdateAddOnMemoryUsage()

  for i = 1, GetNumAddOns() do
    name, title, notes, enabled = GetAddOnInfo(i)
    if enabled then
      tinsert(stats, {name, GetAddOnMemoryUsage(i)})
    end
  end

  sort(stats, function(a, b) return a[1] < b[1] end)
  for i, usage in ipairs(stats) do
    value = ceil(usage[2])
    if value < 1024 then
      tinsert(report, format('%s: %dkb', usage[1], value))
    else
      tinsert(report, format('%s: %0.2fmb', usage[1], value / 1024))
    end
  end
  return concat(report, '\n')
end

function ep.module(ns)
  ns.__modular = true
  return ns
end

function ep.say(message, language)
  SendChatMessage(message, 'SAY', language)
end

function ep.schedule(invocation, interval, limit, immediate)
  local registration, response = {
     invocation = (type(invocation) == 'table') and invocation or {invocation},
     interval = interval or 1,
     limit = limit or nil,
     serial = 1,
  }

  if immediate then
    response = invoke(registration.invocation, 0)
    if type(response) == 'table' then
      registration.invocation = response
    elseif response == false then
      return
    end
  end

  registration.delta = GetTime() + registration.interval
  if invocations:push(registration) == 1 then
    epRoot:SetScript('OnUpdate', ep.tick)
  end
  return registration
end

function ep.subscribe(event, invocation)
  local subscriptions, idx, ref = events[event]
  if subscriptions then
    idx = #subscriptions + 1
    subscriptions[idx] = invocation
    ref = {event, idx}
  else
    events[event] = {invocation}
    ref = {event, 1}
  end

  if not event:find(':', 1, true) and not epRoot:IsEventRegistered(event) then
    epRoot:RegisterEvent(event)
  end
  return ref
end

function ep.tick(frame, delta)
  _schedulingTicks = _schedulingTicks + delta
  if _schedulingTicks >= 1 then
    local time, invocations, invoke, registration, response = GetTime(), invocations, invoke
    while true do
      registration = invocations:pop(time)
      if not registration then
        break
      end

      if registration.invocation then
        if registration.simple then
          registration.invocation()
        else
          response = invoke(registration.invocation, registration.serial)
          if response ~= false and (not registration.limit or registration.limit > 1) then
            registration.serial = registration.serial + 1
            if type(registration.limit) == 'number' then
              registration.limit = registration.limit - 1
            end
            if type(response) == 'table' then
              registration.invocation = response
            end
            registration.delta = time + registration.interval
            invocations:push(registration)
          end
        end
      end
    end

    _schedulingTicks = 0
    if #invocations.items == 0 then
      epRoot:SetScript('OnUpdate', nil)
    end
  end
end

function ep.uniqid()
  _uniqidEntropy = _uniqidEntropy - 1
  if _uniqidEntropy <= 0 then
    _uniqidEntropy = 65535
  end
  return format('%08x%s%04x', time(), ep.character.guid:sub(6), _uniqidEntropy)
end

function ep.unsubscribe(ref)
  local event, idx, subscriptions = unpack(ref)
  subscriptions = events[event]
  if subscriptions then
    table.remove(subscriptions, idx)
    if not event:find(':', 1, true) and #subscriptions == 0 then
      epRoot:UnregisterEvent(event)
    end
  end
end

function ep._bootstrapEphemeral()
  ep.character = ep._describeCharacter()
  if ephemeral.characters then
    ephemeral.characters[ep.character.token] = ep.character
  else
    ephemeral.characters = {[ep.character.token] = ep.character}
  end

  ep.designations = {}
  for token, character in pairs(ephemeral.characters) do
    ep.designations[character.designation] = token
  end

  if not ephemeral.modules then
    ephemeral.modules = {}
  end
  if not ephemeral.versions then
    ephemeral.versions = {}
  end

  ep._enumerateAddons()
  for name, addon in pairs(ep.addons) do
    if addon.loaded then
      ep._loadAddon(addon)
    end
  end
end

function ep._describeCharacter()
  local guid, guild, realm, character = UnitGUID('player'):sub(8), GetGuildInfo('player'), GetRealmName()
  character = {
    class = select(2, UnitClass('player')):lower(),
    faction = UnitFactionGroup('player'):lower(),
    designation = format('%s (%s)', UnitName('player'), realm),
    gender = _characterGenders[UnitSex('player')],
    guid = guid,
    guild = guild,
    name = UnitName('player'),
    race = select(2, UnitRace('player')):lower(),
    realm = realm,
    realmid = guid:sub(1, 4),
    realmtoken = realm:gsub('%s*', ''):lower(),
  }

  character.factiontoken = format('%s:%s', character.realmtoken, character.faction)
  character.token = format('%s:%s', character.realmtoken, character.name:lower())
  if guild then
    character.guildtoken = format('%s:%s', character.realmtoken, guild:gsub('%s*', ''):lower())
  end

  return character
end

function ep._enumerateAddons()
  local compatibility
  for i = 1, GetNumAddOns() do
    compatibility = tonumber(GetAddOnMetadata(i, 'X-Ephemeral-Compatibility'))
    if compatibility then
      ep._parseAddon(i, compatibility)
    end
  end
end

function ep._loadAddon(addon)
  local loaded, reason, name, module, result
  if type(addon) == 'string' then
    addon = addons[addon]
  end

  if not addon.compatible then
    return exception('LoadFailed', format("addon '%s' is not compatible", addon))
  end

  if not addon.loaded then
    if not addon.loadable then
      return exception('LoadFailed', format("addon '%s' is not loadable", addon))
    end

    loaded, reason = LoadAddOn(addon.name)
    if loaded then
      addon.loaded = true
    else
      return exception('LoadFailed', reason)
    end
  end

  if not addon.deployed then
    for name, module in pairs(addon.modules) do
      if not module.deployed then
        result = ep.deployModule(module)
        if exceptional(result) then
          return result
        end
      end
    end
    addon.deployed = true
  end
end

function ep._parseAddon(id, compatibility)
  local name, title, description, enabled, loadable, addon = GetAddOnInfo(id)
  addon = {
    compatible = (ep.version >= compatibility),
    compatibility = compatibility,
    description = description,
    enabled = enabled,
    loadable = loadable,
    loaded = IsAddOnLoaded(id) and true or false,
    modules = {},
    name = name,
    title = title,
  }

  local idx, entry, aspects, module, key, value, dependencies, components = 1
  while true do
    entry = 'X-Ephemeral-Module['..idx..']'
    aspects = GetAddOnMetadata(id, entry)
    if not aspects then
      break
    end

    module = {
      addon = addon.name,
      description = GetAddOnMetadata(id, entry..'-Description'),
    }

    for pair in itersplit(aspects:gsub('%s*', ''), ',') do
      key, value = split(pair, '=', 1)
      if key == 'version' then
        value = tonumber(value)
      end
      module[key] = value
    end

    dependencies = GetAddOnMetadata(id, entry..'-Dependencies')
    if dependencies then
      module.dependencies = {}
      for pair in itersplit(dependencies:gsub('%s*', ''), ',') do
        key, value = split(pair, '=', 1)
        module.dependencies[key] = tonumber(value)
      end
    end

    components = GetAddOnMetadata(id, entry..'-Components')
    if components then
      module.components = {}
      for pair in itersplit(components:gsub('%s*', ''), ',') do
        key, value = split(pair, '=', 1)
        tinsert(module.components, {key, value})
      end
    end

    if module.name and module.path then
      addon.modules[module.name] = module
      modules[module.name] = module
      if module.components then
        for i, component in ipairs(module.components) do
          key, value = unpack(component)
          if ep.components[key] then
            ep.components[key][value] = module.name
          else
            ep.components[key] = {[value] = module.name}
          end
        end
      end
    end
    idx = idx + 1
  end
  addons[addon.name] = addon
end

function ep._scheduleInvocation(registration)
  if ep.invocations:push(registration) == 1 then
    epRoot:SetScript('OnUpdate', ep.tick)
  end
end

ep.script = ep.prototype('ep.script', {
  environment = {
    abs = math.abs, acos = acos, asin = asin, atan = atan, atan2 = atan2, ceil = ceil, concat = concat,
    cos = cos, date = date, deg = deg, exp = exp, floor = floor, foreach = foreach, foreachi = foreachi,
    format = format, frexp = frexp, ipairs = ipairs, ldexp = ldexp, log = log, log10 = log10,
    max = max, min = min, mod = mod, next = next, pairs = pairs, rad = rad, random = random,
    select = select, sin = sin, sort = sort, sqrt = sqrt, tan = tan, tinsert = tinsert, time = time,
    tonumber = tonumber, tostring = tostring, tremove = tremove, type = type, unpack = unpack,

    combine = ep.combine, contains = ep.contains, copy = ep.copy, count = ep.count,
    deepcopy = ep.deepcopy, empty = ep.empty, extend = ep.extend, filter = ep.filter,
    freeze = ep.freeze, hash = ep.hash, index = ep.index, inject = ep.inject,
    iterkeys = ep.iterkeys, itersplit = ep.itersplit, itervalues = ep.itervalues,
    keys = ep.keys, lstrip = ep.lstrip, map = ep.map, partition = ep.partition,
    populate = ep.populate, remove = ep.remove, reverse = ep.reverse, rstrip = ep.rstrip,
    split = ep.split, strcount = ep.strcount, strip = ep.strip, thaw = ep.thaw,
    unique = ep.unique, values = ep.values,

    print = print
  },

  initialize = function(self, source, namespace, name)
    self.name = name or '<script>'
    self.source = source
    self._executionNamespace = {}
    self._staticNamespace = {}
    if namespace then
      for attr, value in pairs(namespace) do
        self._staticNamespace[attr] = surrogate(value)
      end
    end
  end,

  compile = function(self)
    local code, err = loadstring(self.source, self.name)
    if code then
      local env, sn, en = self.environment, self._staticNamespace, self._executionNamespace
      return setfenv(code, setmetatable({}, {
        __index = function(object, field)
          local value = en[field]
          if value == nil then
            value = sn[field]
            if value == nil then
              value = env[field]
            end
          end
          return value
        end
      }))
    else
      return code, err
    end
  end,

  execute = function(self, immutable, mutable)
    local namespace = self._executionNamespace
    if not self.code then
      self.code, err = self:compile()
      if not self.code then
        return exception('CompilationError', err)
      end
    end
    clear(namespace)
    if immutable then
      for attr, value in pairs(immutable) do
        namespace[attr] = surrogate(value)
      end
    end
    if mutable then
      for attr, value in pairs(mutable) do
        namespace[attr] = value
      end
    end
    local status, result = pcall(self.code)
    if status then
      return result
    else
      return exception('ScriptError', result)
    end
  end
})

if __emulating__ then
  epRoot = EventBridge
  epRoot:SetScript('OnEvent', ep.event)
  epRoot:SetScript('OnLoad', function()
    ep.subscribe('PLAYER_LOGIN', function() ep.schedule(ep._bootstrapEphemeral, 1, 1) end)
  end)
end
