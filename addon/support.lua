local concat, floor, fmod, format, tinsert, tremove, random, sort, strrep
    = table.concat, math.floor, math.fmod, string.format, table.insert,
      table.remove, math.random, table.sort, string.rep

local printCounter = 1
local promises = {}
local prototypeRegistries = {}
local _pseudoidChars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

ep = {}
ephemeral = {}

ep.activeLocale = nil
ep.locales = {}
ep.logExceptions = true
ep.promises = promises
ep.prototypeRegistries = prototypeRegistries

function ep.alert(context, message, level)
  if not (context and message) then
    return
  end
  if _G.DEFAULT_CHAT_FRAME then
    local color, r, g, b
    if level == 'error' then
      color, r, g, b = '008a5c5c', 0.64, 0.46, 0.46
    else
      color, r, g, b = '005c8a8a', 0.46, 0.64, 0.64
    end
    DEFAULT_CHAT_FRAME:AddMessage('|c'..color..context..':|r '..message, r, g, b)
  else
    print(context..': '..message)
  end
end

function P(...)
  for i, obj in ipairs({...}) do
    if type(obj) ~= 'string' then
      obj = ep.repr(obj)
    end
    ep.alert(format('debug[%d]', printCounter), obj)
  end
  printCounter = printCounter + 1
end

function ep.debug(message, objects, stacktrace, showConsole)
  local lines, line = {}
  if ep.exceptional(message) then
    line = message.exception
    if message.description then
      line = line..': '..message.description
    end
  elseif type(message) == 'table' then
    line = message[1]:format(select(2, unpack(message)))
  elseif type(message) == 'number' then
    line = debugstack(message)
    if line then
      line, _ = ep.split(line, '\n', 1)
    else
      line = 'unknown location'
    end
  else
    line = message
  end

  local formatObject = function(title, object)
    if type(title) == 'string' then
      title = format('"%s"', title)
    else
      title = format('#%d', title)
    end

    tinsert(lines, format('  object %s:', title))
    for line in ep.itersplit(ep.repr(object, -1), '\n') do
      tinsert(lines, '    '..line)
    end
  end

  lines[1] = format('[%s] %s', date('%H:%M:%S'), line)
  if objects then
    for title, object in pairs(objects) do
      formatObject(title, object)
    end
  end

  if stacktrace and debugstack then
    tinsert(lines, '  stack trace:')
    for line in ep.itersplit(debugstack(2), '\n') do
      tinsert(lines, '    '..line)
    end
  end

  if epConsole and epConsole.log then
    epConsole:log(lines, nil, showConsole)
  else
    ep.alert('debug', concat(lines, '\n'))
  end
end

function D(...)
  ep.debug(3, {...}, nil, true)
end

local function isPublicAttr(attr)
  return attr:sub(1, 1) ~= '_'
end

ep.metatype = {
  __call = function(prototype, ...)
    local instantiator, object, referrent, initializer = rawget(prototype, 'instantiate')
    if instantiator then
      object = instantiator(prototype, ...)
      if object then
        return object
      elseif object == false then
        return nil
      end
    end

    object = {}
    if prototype.__segregation then
      object[prototype.__segregation.attr] = {}
    end
    setmetatable(object, prototype)

    referrent, initializer = prototype, rawget(prototype, 'initialize')
    while not initializer do
      referrent = rawget(referrent, '__base')
      if referrent then
        initializer = rawget(referrent, 'initialize')
      else
        break
      end
    end

    if initializer then
      initializer(object, ...)
    end
    return object
  end,

  __index = function(prototype, field)
    local referrent, value = prototype, rawget(prototype, field)
    while value == nil do
      referrent = rawget(referrent, '__base')
      if referrent then
        value = rawget(referrent, field)
      else
        break
      end
    end

    if value == nil then
      value = rawget(getmetatable(prototype), field)
    end
    return value
  end,

  __repr = function(self)
    if rawget(self, '__prototypical') then
      local name = rawget(self, '__name')
      if name then
        local base, baseclass = rawget(self, '__base'), ''
        if type(base) == 'table' then
          baseclass = base.__name or ''
        end
        return format('[prototype %s(%s)]', name, baseclass)
      end
    elseif self.__name then
      return self.__name..'()'
    end
  end,

  __supercall = {
    __call = function(object, ...)
      local value = rawget(object, '__value')
      if (...) == object then
        return value(rawget(object, '__ref'), select(2, ...))
      else
        return value(...)
      end
    end,

    __index = function(object, field)
      local referrent, value = rawget(getmetatable(rawget(object, '__ref')), '__base')
      if referrent then
        value = rawget(referrent, field)
        while value == nil do
          referrent = rawget(referrent, '__base')
          if referrent then
            value = rawget(referrent, field)
          else
            break
          end
        end
      end

      rawset(object, '__value', value)
      return object
    end
  },

  super = function(object)
    return setmetatable({__ref=object}, ep.metatype.__supercall)
  end
}

function ep.prototype(...)
  local idx, args, name, base, proto, metabase, id = 1, {...}
  if args[idx] and type(args[idx]) == 'string' then
    name, idx = args[idx], idx + 1
  end
  if args[idx] and args[idx].__prototypical then
    base, idx = args[idx], idx + 1
  end
  if args[idx] then
    proto, metabase = args[idx], args[idx + 1]
  end

  proto = proto or {}
  proto.__name = name
  proto.__base = base
  proto.__prototypical = true

  local segregation = proto.__segregation
  if segregation then
    local segAttr, segFunc = segregation.attr, segregation.func or isPublicAttr

    proto.__index = function(object, field)
      local value, referrent
      if segFunc(field) then
        value = rawget(object, segAttr)[field]
      else
        value = rawget(object, field)
      end

      if value == nil then
        referrent, value = proto, rawget(proto, field)
        while value == nil do
          referrent = rawget(referrent, '__base')
          if referrent then
            value = rawget(referrent, field)
          else
            break
          end
        end
      end

      if value == nil then
        value = rawget(getmetatable(proto), field)
      end
      return value
    end

    proto.__newindex = function(object, field, value)
      if segFunc(field) then
        rawget(object, segAttr)[field] = value
      else
        rawset(object, field, value)
      end
    end

  else

    proto.__index = function(object, field)
      local value, referrent = rawget(object, field)
      if value == nil then
        referrent, value = proto, rawget(proto, field)
        while value == nil do
          referrent = rawget(referrent, '__base')
          if referrent then
            value = rawget(referrent, field)
          else
            break
          end
        end
      end

      if value == nil then
        value = rawget(getmetatable(proto), field)
      end
      return value
    end

  end

  for attr, container in pairs(prototypeRegistries) do
    id = rawget(proto, attr)
    if id then
      container[id] = proto
    end
  end
  return setmetatable(proto, metabase or ep.metatype)
end

function ep.attempt(func, ...)
  local status, result = pcall(func, ...)
  if status then
    return result
  else
    return ep.exception('AttemptedFailed', result)
  end
end

function ep.attrsort(attr)
  return function(first, second)
    return first[attr] < second[attr]
  end
end

function ep.capitalize(value)
  return value:sub(1, 1):upper()..value:sub(2)
end

function ep.deepcopy(tbl, memo)
  local result, memo = {}, memo or {}
  for key, value in pairs(tbl) do
    if type(value) == 'table' then
      if not memo[value] then
        memo[value] = ep.deepcopy(value, memo)
      end
      result[key] = memo[value]
    else
      result[key] = value
    end
  end
  return result
end

function ep.exception(exception, description, aspects, noLogging)
  exc = aspects or {}
  exc.__exceptional, exc.exception, exc.description = true, exception, description

  if ep.logExceptions and not noLogging then
    ep.debug(exc, nil, true, true)
  end
  return exc
end

function ep.exceptional(value, exception)
  return (type(value) == 'table' and value.__exceptional
    and (not exception or value.exception == exception))
end

function ep.fieldsort(items, ...)
  local fields, sort, field, descending, cmp = {...}, table.sort
  for i = #fields, 1, -1 do
    field, descending = fields[i], false
    if type(field) == 'table' then
      field, descending = unpack(field)
    end

    cmp = function(first, second)
      local first, second, result = first[field], second[field]
      if type(first) == 'number' and type(second) == 'number' then
        result = (first <= second)
      elseif type(first) ~= 'nil' and type(second) ~= 'nil' then
        result = (tostring(first) <= tostring(second))
      else
        result = (first ~= nil)
      end
      if descending then
        return not result
      else
        return result
      end
    end
    sort(items, cmp)
  end
  return items
end

function ep.freeze(object, naive)
  local prototype, implementation, idx, chunks, stype, svalue, representation
  if type(object) == 'table' then
    chunks, implementation = {}, '-'
    if not naive and object.freeze then
      object, implementation = object:freeze()
    end

    idx = 1
    for field, value in pairs(object) do
      if type(value) == 'table' then
        stype, svalue = 't', ep.freeze(value, naive)
      else
        stype, svalue = ep._freezeScalar(value)
      end
      chunks[idx] = format('%s:%s%d:%s', field, stype, #svalue, svalue)
      idx = idx + 1
    end
    representation = format('$%s$%s', implementation, concat(chunks, ';'))
  elseif type(object) ~= 'nil' then
    stype, svalue = ep._freezeScalar(object)
    representation = format('$+$%s:%s', stype, svalue)
  else
    return ''
  end

  representation = representation:gsub('~', '~~'):gsub('\n', '~n')
  return representation
end

function ep.hash(object)
  local objtype = type(object)
  if objtype == 'table' then
    return tostring(object):sub(8)
  elseif objtype == 'function' then
    return tostring(object):sub(11)
  else
    return ep.strhash(tostring(object))
  end
end

function ep.invoke(invocation, ...)
  if type(invocation) == 'function' then
    return invocation(...)
  end

  local callable, arguments = invocation[1], {...}
  for i = #invocation, 2, -1 do
    tinsert(arguments, 1, invocation[i])
  end
  return callable(unpack(arguments))
end

function ep.isderived(candidate, prototype, strict)
  if not strict and candidate == prototype then
    return true
  end

  base = candidate.__base
  while base do
    if base == prototype then
      return true
    end
    base = base.__base
  end
  return false
end

function ep.isinstance(candidate, prototype)
  if type(candidate) ~= 'table' or rawget(candidate, '__prototypical') then
    return false
  end

  base = getmetatable(candidate)
  while base do
    if base == prototype then
      return true
    end
    base = base.__base
  end
  return false
end

function ep.isprototype(candidate)
  return rawget(candidate, '__prototypical')
end

function ep.iterkeys(tbl, sorted)
  tbl = ep.tkeys(tbl, sorted)
  return function()
    return tremove(tbl, 1)
  end
end

function ep.itersplit(str, sep, limit)
  local position, length, width, count = 1, #str, #sep, 0
  return function()
    local delta, span = str:find(sep, position, true), nil
    if delta and (not limit or count < limit) then
      span = str:sub(position, delta - 1)
      position, count = delta + width, count + 1
      return span
    elseif position <= length then
      span = str:sub(position)
      position = length + 1
      return span
    end
  end
end

function ep.itervalues(tbl, sorted)
  tbl = ep.tvalues(tbl, sorted)
  return function()
    return tremove(tbl, 1)
  end
end

function ep.lstrip(str, chars)
  local pattern = '^[%s]*(.-)$'
  if chars then
    pattern = format(pattern, chars)
  end
  return str:gsub(pattern, '%1', 1)
end

function ep.naivesort(first, second)
  if type(first) == 'number' and type(second) == 'number' then
    return (first < second)
  else
    return (tostring(first) < tostring(second))
  end
end

function ep.partition(str, ...)
  local chunks = {}
  for i, length in ipairs({...}) do
    if #str >= length then
      chunks[i] = str:sub(1, length)
      str = str:sub(length + 1)
    else
      return ep.exception('CannotPartition',
        'specified string too short to partition')
    end
  end

  if #str >= 1 then
    chunks[#chunks + 1] = str
  end
  return unpack(chunks)
end

function ep.promise(source, topic, invocation)
  local invocations
  if type(source) == 'table' then
    source = tostring(source):sub(8)
  end

  topic = source..topic
  invocations = promises[topic]

  if invocations then
    invocations[#invocations + 1] = invocation
  else
    promises[topic] = {invocation}
  end
end

function ep.pseudoid()
  local d, e, f, r = date('!*t'), _pseudoidChars, random(62), random(62)
  return (e:sub(f, f)..e:sub(d.year - 2000, d.year - 2000)..e:sub(d.month, d.month)..
    e:sub(d.day, d.day)..e:sub(d.hour + 1, d.hour + 1)..e:sub(d.min + 1, d.min + 1)..
    e:sub(d.sec + 1, d.sec + 1)..e:sub(r, r))
end

function ep.pseudotype(ns)
  local instantiator = rawget(ns, 'instantiate')
  if type(instantiator) == 'function' then
    setmetatable(ns, {__call = instantiator})
  end
  return ns
end

function ep.put(path, object, overwrite)
  local sections, name, namespace = ep.split(path, '.', nil, true)
  if #sections > 1 then
    name = tremove(sections)
    namespace = ep.ref(concat(sections, '.'))
    if namespace and (not namespace[name] or overwrite) then
      namespace[name] = object
      return true
    end
  else
    name = sections[1]
    if not _G[name] or overwrite then
      _G[name] = object
      return true
    end
  end
  return false
end

function ep.ref(path, namespace)
  local tokens, parent, child = {ep.split(path:gsub('[%[%]]', '.'):gsub('%.%.', '.'), '.')}
  if #tokens >= 1 then
    parent = namespace or _G[tremove(tokens, 1)]
    if parent then
      child = tremove(tokens, 1)
      while child do
        if parent[child] then
          parent = parent[child]
          child = tremove(tokens, 1)
        else
          return
        end
      end
      return parent
    end
  end
end

function ep.repr(object, strLimit, naive)
  local objtype, strLimit, representation, length = type(object), limit or 100
  if objtype == 'table' then
    if not naive and object.__repr then
      representation = object:__repr()
      if representation then
        return representation
      end
    end

    tag = format('table(0x%s)', tostring(object):sub(8))
    if ep.tempty(object) then
      return tag..' {}'
    else
     return format('%s {\n%s}\n', tag, ep.reprtable(object, nil, nil, nil, strLimit, naive))
    end
  elseif objtype == 'function' then
    return format('function(0x%s)', tostring(object):sub(11))
  elseif objtype == 'userdata' then
    return format('userdata(0x%s)', tostring(object):sub(11))
  elseif objtype == 'string' then
    length = #object
    if strLimit >= 1 and length >= strLimit then
      return format("'%s' (%d)", object:sub(1, strLimit - 10), length)
    else
      return format("'%s'", object)
    end
  else
    return tostring(object)
  end
end

function ep.reprtable(object, indent, spacing, roots, strLimit, naive)
  local text, prefix, value, tag, subtable, length, representation = ''
  indent, spacing, roots = indent or 1, spacing or '  ', roots or {[object] = '(root)'}

  prefix = strrep(spacing, indent)
  for key in ep.iterkeys(object, true) do
    value = object[key]
    if type(value) == 'table' then
      key, representation = tostring(key), nil
      if value.repr and not naive then
        representation = value:repr()
        if representation then
          representation = format('%s[%s] = %s\n', prefix, key, representation)
        end
      end
      if not representation then
        tag = format('table(0x%s)', tostring(value):sub(8))
        if roots[value] then
          representation = format('%s[%s] = %s -> %s\n', prefix, key, tag, roots[value])
        else
          roots[value] = key
          if ep.tempty(value) then
            representation = format('%s[%s] = %s {}\n', prefix, key, tag)
          else
            subtable = ep.reprtable(value, indent + 1, spacing, roots, strLimit, naive)
            representation = format('%s[%s] = %s {\n%s%s}\n', prefix, key, tag, subtable, prefix)
          end
        end
      end
      text = text..representation
    else
      text = text..format('%s[%s] = %s\n', prefix, tostring(key), ep.repr(value, strLimit, naive))
    end
  end
  return text
end

function ep.rstrip(str, chars)
  local pattern = '^(.-)[%s]*$'
  if chars then
    pattern = format(pattern, chars)
  end
  return str:gsub(pattern, '%1', 1)
end

function ep.satisfy(source, topic, ...)
  local invoke, invocations
  if type(source) == 'table' then
    source = tostring(source):sub(8)
  end

  topic = source..topic
  invocations = promises[topic]

  if invocations then
    invoke = ep.invoke
    for i, invocation in ipairs(invocations) do
      invoke(invocation, ...)
    end
    promises[topic] = nil
  end
end

function ep.split(str, sep, limit, packed)
  local chunks, position, idx, delta, width, count = {}, 1, 1, nil, #sep, 0
  if #str == 0 then
    return ''
  end

  while true do
    delta = str:find(sep, position, true)
    if delta and (not limit or count < limit) then
      chunks[idx] = str:sub(position, delta - 1)
      position, count, idx = delta + width, count + 1, idx + 1
    else
      chunks[idx] = str:sub(position)
      break
    end
  end

  if packed then
    return chunks
  else
    return unpack(chunks)
  end
end

function ep.strcount(str, pattern)
  local count = 0
  for match in str:gmatch(pattern) do
    count = count + 1
  end
  return count
end

function ep.strhash(str)
  local result, length, fmod, chars = 1, #str, fmod, ''
  for i = 1, length, 3 do
    result = fmod(result * 8161, 4294967279) + (str:byte(i) * 16776193) +
      ((str:byte(i + 1) or (length - i + 256)) * 8372226) +
      ((str:byte(i + 2) or (length - i + 256)) * 3932164)
  end

  result = fmod(result, 4294967291)
  while result > 0 do
    chars = format('%x', fmod(result, 16))..chars
    result = floor(result / 16)
  end
  return chars
end

function ep.strip(str, chars)
  local pattern = '^[%s]*(.-)[%s]*$'
  if chars then
    pattern = format(pattern, chars, chars)
  end
  return str:gsub(pattern, '%1', 1)
end

function ep.surrogate(tbl)
  if type(tbl) ~= 'table' then
      return tbl
  end

  local s = {}
  return setmetatable(s, {
    __index = function(object, field)
      local value = rawget(s, field)
      if not value then
        value = tbl[field]
        if type(value) == 'table' then
          value = ep.surrogate(value)
          rawset(s, field, value)
        end
      end
      return value
    end,
    __newindex = function()
    end
  })
end

function ep.tclear(tbl)
  if tbl[1] then
    for i = 1, #tbl do
      tbl[i] = nil
    end
  else
    for k, v in pairs(tbl) do
      tbl[k] = nil
    end
  end
  return tbl
end

function ep.tcombine(keys, values)
  local result = {}
  if type(values) == 'table' then
    for i, key in ipairs(keys) do
      result[key] = values[i]
    end
  else
    for i, key in ipairs(keys) do
      result[key] = values
    end
  end
  return result
end

function ep.tcompare(first, second)
  for k, v in pairs(first) do
    if second[k] ~= v then
      return false
    end
  end
  return true
end

function ep.tcontains(tbl, value)
  for i, v in ipairs(tbl) do
    if v == value then
      return true
    end
  end
  return false
end

function ep.tcopy(tbl)
  local result = {}
  for key, value in pairs(tbl) do
    result[key] = value
  end
  return result
end

function ep.tcount(tbl, value, threshold)
  local count, threshold = 0, threshold or #tbl
  for i, v in ipairs(tbl) do
    if v == value then
      count = count + 1
    end
    if count >= threshold then
      break
    end
  end
  return count
end

function ep.tempty(tbl)
  for key, value in pairs(tbl) do
    return false
  end
  return true
end

function ep.textend(tbl, ...)
  local idx = #tbl + 1
  for i, extension in ipairs({...}) do
    for j, value in ipairs(extension) do
      tbl[idx], idx = value, idx + 1
    end
  end
  return tbl
end

function ep.textract(tbl, value)
  local index = 0
  for i, v in ipairs(tbl) do
    if v == value then
      index = i
      break
    end
  end

  if index >= 1 then
    tremove(tbl, index)
  end
  return tbl
end

function ep.tfilter(tbl, callback)
  local result, idx = {}, 1
  for i, value in ipairs(tbl) do
    if callback(value) then
      result[idx], idx = value, idx + 1
    end
  end
  return result
end

function ep.thaw(obj, naive)
  local position, implementation, object, length, delta, field, ftype, vlength, value, prototype
  if type(obj) == 'string' and #obj >= 1 then
    obj = obj:gsub('~n', '\n'):gsub('~~', '~')
  else
    return ep.exception('TypeError', 'obj must be a string')
  end

  position = obj:find('$', 2, true)
  if position then
    implementation, obj = obj:sub(2, position - 1), obj:sub(position + 1)
    if implementation == '+' then
      return ep._thawScalar(ep.split(obj, ':', 1))
    end
  else
    return ep.exception('InvalidValue', 'obj is not a serialized value')
  end

  object, position, length = {}, 1, #obj
  while position < length do
    delta = obj:find(':', position, true)
    field = obj:sub(position, delta - 1)
    field, position = tonumber(field) or field, delta + 1

    delta = obj:find(':', position, true)
    ftype, vlength = obj:sub(position, position), tonumber(obj:sub(position + 1, delta - 1))
    position = delta + 1

    value = obj:sub(position, position + vlength - 1)
    if ftype == 't' then
      object[field] = ep.thaw(value)
    else
      object[field] = ep._thawScalar(ftype, value)
    end
    position = position + vlength + 1
  end

  if not naive and implementation ~= '-' then
    prototype = ep.ref(implementation)
    if prototype and prototype.thaw then
      object = prototype.thaw(object)
    end
  end
  return object
end

function ep.tindex(tbl, value, offset)
  for i = offset or 1, #tbl, 1 do
    if tbl[i] == value then
      return i
    end
  end
end

function ep.tinject(tbl, value)
  local index = 1
  while tbl[index] do
    index = index + 1
  end

  tbl[index] = value
  return index
end

function ep.titlecase(value)
  local segments = {}
  for segment in ep.itersplit(value, ' ') do
    if #segment > 0 then
      segment = segment:sub(1, 1):upper()..segment:sub(2)
    end
    tinsert(segments, segment)
  end
  return concat(segments, ' ')
end

function ep.tkeys(tbl, sorted)
  local keys, idx = {}, 1
  for key, value in pairs(tbl) do
    keys[idx], idx = key, idx + 1
  end

  if sorted then
    table.sort(keys, ep.naivesort)
  end
  return keys
end

function ep.tmap(tbl, callback)
  local result = {}
  for i, value in ipairs(tbl) do
    result[i] = callback(value)
  end
  return result
end

function ep.treverse(tbl)
  local result, length = {}, #tbl
  for i = length, 1, -1 do
    result[length - i + 1] = tbl[i]
  end
  return result
end

function ep.tsplice(tbl, idx, count, ...)
  for i = 1, count do
    tremove(tbl, idx)
  end

  for i, value in ipairs({...}) do
    tinsert(tbl, idx, value)
    idx = idx + 1
  end
  return tbl
end

function ep.tunique(tbl)
  local result, values, idx = {}, {}, 1
  for i, value in ipairs(tbl) do
    if not values[value] then
      result[idx], idx = value, idx + 1
      values[value] = true
    end
  end
  return result
end

function ep.tupdate(tbl, ...)
  for i, update in ipairs({...}) do
    for key, value in pairs(update) do
      tbl[key] = value
    end
  end
  return tbl
end

function ep.tvalues(tbl, sorted)
  local result, idx = {}, 1
  for key, value in pairs(tbl) do
    result[idx], idx = value, idx + 1
  end

  if sorted then
    sort(result, ep.naivesort)
  end
  return result
end

function ep.weaktable(mode)
  return setmetatable({}, {__mode = mode})
end

function ep._declarePrototypeRegistry(attr, container)
  prototypeRegistries[attr] = container
end

function ep._freezeScalar(scalar)
  local ftype, stype, svalue = type(scalar)
  if ftype == 'boolean' then
    stype, svalue = 'b', scalar and 't' or 'f'
  elseif ftype == 'number' then
    stype, svalue = 'n', tostring(scalar)
  elseif ftype == 'string' then
    stype, svalue = 's', scalar
  else
    stype, svalue = 'v', 'v'
  end
  return stype, svalue
end

function ep._thawScalar(token, value)
  if token == 'b' then
    return (value == 't')
  elseif token == 'n' then
    return tonumber(value)
  elseif token == 's' then
    return value
  else
    return nil
  end
end

ep.Locale = ep.prototype('ep.Locale', {
  strings = nil,

  bootstrap = function(cls, locale)
    locale = locale or GetLocale()
    if ep.locales[locale] then
      ep.locales[locale]:deploy()
    end
  end,

  deploy = function(cls)
    ep.activeLocale = cls

    local strings = cls.strings
    if strings then
      ep.localize = function(string)
        return strings[string] or string
      end
    else
      ep.localize = function(string)
        return string
      end
    end
    _G['ep_'] = ep.localize
  end
})

ep.OrderedDict = ep.prototype('ep.OrderedDict', {
  initialize = function(self, values)
    rawset(self, '__ordering', {})
    self:update(values)
  end,

  __newindex = function(self, key, value)
    if type(value) ~= nil then
      if not self[key] then
        tinsert(self.__ordering, key)
      end
      rawset(self, key, value)
    else
      if self[key] then
        ep.textract(self.__ordering, key)
        rawset(self, key, nil)
      end
    end
  end,

  iteritems = function(self)
    local ordering, idx = self.__ordering, 1
    return function()
      local key = ordering[idx]
      idx = idx + 1
      return key, self[key]
    end
  end,

  update = function(self, values)
    if not values then
      return
    end

    local ordering, key, value = self.__ordering
    for i = 1, #values, 2 do
      key, value = values[i], values[i + 1]
      if not self[key] then
        tinsert(ordering, key)
      end
      rawset(self, key, value)
    end
  end
})

ep.PriorityQueue = ep.prototype('ep.PriorityQueue', {
  initialize = function(self, field)
    self.field, self.items = field, {}
  end,

  __repr = function(self)
    if ep.isprototype(self) then
      return ep.metatype.__repr(self)
    else
      return format("ep.PriorityQueue(field='%s', items={%s})",
        self.field, ep.reprtable(self.items))
    end
  end,

  peek = function(self, threshold)
    if self.items[1] and (not threshold or self.items[1][self.field] <= threshold) then
      return self.items[1]
    end
  end,

  push = function(self, item)
    local field, low, mid, high, floor, key = self.field, 1, nil, #self.items + 1, math.floor
    key = item[field]

    while low < high do
      mid = floor((low + high) * 0.5)
      if key < self.items[mid][field] then
        high = mid
      else
        low = mid + 1
      end
    end

    tinsert(self.items, low, item)
    return #self.items
  end,

  pop = function(self, threshold)
    if self.items[1] and (not threshold or self.items[1][self.field] <= threshold) then
      return tremove(self.items, 1)
    end
  end
})

ep.Ring = ep.prototype('ep.Ring', {
  add = function(self, object)
    local head = self.head
    if head then
      object._prev, head._prev._next = head._prev, object
      object._next, head._prev = head, object
    else
      object._next, object._prev = object, object
      self.head = object
    end
  end,

  next = function(self)
    if self.head then
      self.head = self.head._next
      return self.head._prev
    end
  end,

  remove = function(self, object)
    object._next._prev, object._prev._next = object._prev, object._next
    if self.head == object then
      self.head = object._next
      if self.head == object then
        self.head = nil
      end
    end
    object._next, object._prev = nil, nil
  end
})

ep.Timer = ep.prototype('ep.Timer', {
  timers = {},

  initialize = function(self, name)
    self.accrued, self.moment, self.name = 0, 0, name
    if name then
      self.timers[name] = self
    end
  end,

  instantiate = function(self, name)
    return self.timers[name]
  end,

  check = function(self)
    if self.moment > 0 then
      return self.accrued + floor(GetTime() - self.moment)
    end
    return self.accrued
  end,

  reset = function(self, start)
    self.accrued, self.moment = 0, 0
    if start then
      self.moment = GetTime()
    end
  end,

  start = function(self)
    if self.moment == 0 then
      self.moment = GetTime()
    end
  end,

  stop = function(self)
    if self.moment > 0 then
      self.accrued = self.accrued + floor(GetTime() - self.moment)
      self.moment = 0
    end
    return self.accrued
  end
})

ep.Timestamp = ep.prototype('ep.Timestamp', {
  parts = {'year', 'month', 'day', 'hour', 'min', 'sec'},

  initialize = function(self, value, portable)
    local vtype, defaults = type(value)
    if vtype == 'number' or vtype == 'string' then
      self.value = tonumber(value)
    elseif vtype == 'table' then
      defaults = self:now()
      for i, part in ipairs(self.parts) do
        if not value[part] then
          value[part] = defaults[part]
        end
      end
      self.value = time(value)
    else
      self.time = time(self:now())
    end
  end,

  __repr = function(self)
    if ep.isprototype(self) then
      return ep.metatype.__repr(self)
    else
      return format("ep.Timestamp('%s')", self:format())
    end
  end,

  format = function(self, specification)
    specification = specification or '%Y-%m-%d %H:%M:%S'
    return date(specification, self.value)
  end,

  increment = function(self, delta)
    local vtype, value = type(delta)
    if vtype == 'number' or vtype == 'string' then
      self.value = self.value + ceil(tonumber(delta))
    elseif vtype == 'table' then
      value = date('*t', self.value)
      for part, val in pairs(delta) do
        value[part] = value[part] + val
      end
      self.value = time(value)
    end
  end,

  now = function(self)
    local date, time = {CalendarGetDate()}, {GetGameTime()}
    return {year=date[4], month=date[2], day=date[3], hour=time[1], min=time[2], sec=0}
  end,

  replace = function(self, delta)
    local value = date('*t', self.value)
    for part, val in pairs(delta) do
      value[part] = val
    end
    self.value = time(value)
  end,

  values = function(self)
    return date('*t', self.value)
  end
})

local function r(id, name, description, value)
  return {id=id, name=name, description=description, value=value}
end

ep.testdata = {
  r(1, 'alpha', 'something wicked this way comes', 'third'),
  r(2, 'bravo', 'a stitch in time saves nine', 'first'),
  r(3, 'charlie', 'take the road less travelled', 'second'),
  r(4, 'delta', 'the very model of a modern man', 'fourth'),
  r(5, 'echo', 'to be or not to be, that is the question', 'first'),
  r(6, 'foxtrot', 'ever is the time of his concern', 'second'),
  r(7, 'golf', 'stands he, a man apart', 'third'),
  r(8, 'hotel', 'long, long time ago in a galaxy far away', 'fifth'),
  r(9, 'india', 'luke, I am your father', 'fifth'),
  r(10, 'juliet', 'nevermore, said the raven', 'first'),
  r(11, 'kilo', 'quote him thusly, said my father', 'second'),
  r(12, 'lima', 'elementary, my dear watson', 'third'),
  r(13, 'mike', 'give all and take none', 'sixth'),
  r(14, 'november', 'virtue is its own punishment', 'first'),
  r(15, 'oscar', 'better them than us, said he', 'second'),
  r(16, 'papa', 'much ado about something', 'third'),
  r(17, 'quebec', 'dinner out, was the name of the op', 'fourth'),
  r(18, 'romeo', 'very tricky, is the way of the world', 'sixth'),
  r(19, 'sierra', 'join us or die', 'first'),
  r(20, 'tango', 'wait for it (wait for it)', 'second'),
  r(21, 'uniform', 'only here might that happen', 'second'),
  r(22, 'victor', 'dropping the ball is sometimes the best option', 'third'),
  r(23, 'whiskey', 'a life without the drink would not be my life', 'first'),
  r(24, 'x-ray', 'and on and on the story goes', 'sixth'),
}
