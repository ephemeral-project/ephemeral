local clear, concat, exception, exceptional, format, invoke, ref, put,
      split, surrogate, tinsert, tremove
    = ep.clear, table.concat, ep.exception, ep.exceptional, string.format, ep.invoke,
      ep.ref, ep.put, ep.split, ep.surrogate, table.insert, table.remove

local events = {}
local invocations = ep.pqueue('delta')

local _schedulingTicks = 0
local _uniqidEntropy = 0

ep.events = events
ep.invocations = invocations
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

function ep.event(event, ...)
  local subscriptions, invoke, invocation = events[event], invoke
  if subscriptions then
    for i, invocation in ipairs(subscriptions) do
      invoke(invocation, event, ...)
    end
  end
end

function ep.inGroup(name, connected)
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

function ep.inGuild(name, connected)
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

function ep.interpretInput(text)
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
          return resul
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

function ep.isFriend(name, connected)
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

function ep.scheduleInvocation(registration)
  if ep.invocations:push(registration) == 1 then
    epRoot:SetScript('OnUpdate', ep.tick)
  end
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
  return format('%08x%s%04x', time(), ep.character.id:sub(6), _uniqidEntropy)
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

ep.datastore = ep.prototype('ep.datastore', {
  initialize = function(self, specification)
    self.indexes = {}
    self.instances = {}
    self.instantiator = specification.instantiator
    self.specification = specification

    self.container = self:construct()
    self:reindex()
  end,

  construct = function(self)
    if self.specification.container then
      return self.specification.container
    end

    local container = ref(self.specification.location)
    if not container then
      container = {}
      put(self.specification.location, container)
    end
    return container
  end,

  delete = function(self, instance)
    local id = instance.id or instance
    self.container[id], self.instances[id] = nil, nil
  end,

  find = function(self, attrs, singular)
    local primary, secondaries, unindexed = nil, {}, false
    for attr, value in pairs(attrs) do
      local index = self:_getIndex(attr, value)
      if index then
        if primary then
          tinsert(secondaries, index)
        else
          primary = index
        end
        attrs[attr] = nil
      else
        unindexed = true
      end
    end

    local candidates, included
    if #secondaries > 0 then
      candidates = {}
      for id, presence in pairs(primary) do
        included = true
        for i, secndary in ipairs(secondaries) do
          if not secondary[id] then
            included = false
            break
          end
        end
        if included then
          tinsert(candidates, id)
        end
      end
    else
      candidates = ep.keys(primary)
    end

    local instance
    if singular then
      if #candidates == 1 then
        instance = self:get(id)
        if exceptional(instance) then
          return instance
        end
        if unindexed then
          for attr, value in pairs(attrs) do
            if instance[attr] ~= value then
              return nil
            end
          end
        end
        return instance
      elseif #candidates == 0 then
        return nil
      else
        return exception('MultipleInstancesFound')
      end
    end

    local instances = {}
    for i, id in ipairs(candidates) do
      instance = self:get(id)
      if exceptional(instance) then
        return instance
      elseif instance then
        if unindexed then
          included = true
          for attr, value in pairs(attrs) do
            if instance[attr] ~= value then
              included = false
              break
            end
          end
          if included then
            tinsert(instances, instance)
          end
        else
          tinsert(instances, instance)
        end
      end
    end
    return instances
  end,

  get = function(self, id)
    local instance = self.instances[id]
    if not instance then
      instance = self.container[id]
      if instance then
        instance = self.instantiator(instance)
        if not exceptional(instance) then
          self.instances[id] = instance
        end
      end
    end
    return instance
  end,

  getData = function(self, id)
    return self.container[id]
  end,

  put = function(self, instance)
    local data = instance:extract()
    if not (data and data.id) then
      return exception('InvalidInstance')
    end

    self.instances[data.id] = instance
    self.container[data.id] = data

    local indexes = self.specification.indexes
    if indexes then
      for attr, index in pairs(indexes) do
        self:_indexInstance(data.id, data, attr, index)
      end
    end
  end,

  reindex = function(self)
    local indexes, specification = self.indexes, self.specification.indexes
    if not specification then
      return
    end

    for attr, index in pairs(specification) do
      indexes[attr] = {}
    end

    for id, candidate in pairs(self.container) do
      for attr, index in pairs(specification) do
        self:_indexInstance(id, candidate, attr, index)
      end
    end
  end,

  _getIndex = function(self, attr, value)
    local index = self.specification.indexes[attr]
    if index.type == 'boolean' then
      return self.indexes[attr]
    else
      return self.indexes[attr][value]
    end
  end,

  _indexInstance = function(self, id, candidate, attr, index)
    local indexes, value = self.indexes
    if index.attr then
      value = candidate[index.attr]
    else
      value = candidate[attr]
    end

    if value == nil then
      return
    elseif index.type == 'boolean' then
      indexes[attr][id] = true
      return
    end

    if index.type == 'prefix' then
      value, _ = split(value, index.delimiter or ':', 1)
    elseif index.type == 'suffix' then
      _, value = split(value, index.delimiter or ':', 1)
    end

    if indexes[attr][value] then
      indexes[attr][value][id] = true
    else
      indexes[attr][value] = {[id] = true}
    end
  end
})

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
