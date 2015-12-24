local _, ScriptExecutor, attrsort, deepcopy, deployModule, exception, exceptional, isderived,
      split, uniqid
    = ep.localize, ep.ScriptExecutor, ep.attrsort, ep.deepcopy, ep.deployModule, ep.exception,
      ep.exceptional, ep.isderived, ep.split, ep.uniqid

ep.EntityType = ep.tcopy(ep.metatype)

ep.EntityType.__call = function(prototype, entity)
  local object = setmetatable({__entity = entity or {}}, prototype)
  local referrent, initializer = prototype, rawget(prototype, 'initialize')

  while not initializer do
    referrent = rawget(referrent, '__base')
    if referrent then
      initializer = rawget(referrent, 'initialize')
    else
      break
    end
  end

  if initializer then
    initializer(object, entity)
  end
  return object
end

ep.InstanceType = {
  __index = function(object, field)
    local value
    if field:sub(1, 1) == '_' then
      value = rawget(object, field)
      if value == nil then
        value = rawget(object, '__entity')[field]
      end
    else
      value = rawget(object, '__instance')[field]
      if value == nil then
        value = rawget(object, '__entity')[field]
      end
    end
    return value
  end,

  __newindex = function(object, field, value)
    if field:sub(1, 1) == '_' then
      rawset(object, field, value)
    elseif value == nil or value ~= rawget(object, '__entity')[field] then
      rawget(object, '__instance')[field] = value
    end
  end
}

ep.entities = {
  name = 'ephemeral:entities',
  version = 1,

  cache = ep.weaktable('v'),
  definitions = {},

  define = function(self, name, base, proto)
    proto = proto or {}
    proto.__name, proto.__base, proto.__prototypical = name, base, true

    proto.__call = function(entity, instance, origin, transient)
      instance = instance or {}
      if not instance.id then
        instance.id = uniqid()
      end
      if not instance.cl then
        instance.cl = entity.cl
      end
      if not instance.et and entity.tg then
        instance.et = entity.tg
      end

      if instance.af and instance.af:sub(1, 1) == '$' then
        instance.af = ep.character:getAffinity(instance.af)
      elseif not instance.af and entity.ay then
        instance.af = ep.character:getAffinity(entity.ay)
      end

      local object = setmetatable({__entity=entity, __instance=instance}, ep.InstanceType)
      object:construct(origin)

      if not transient then
        ep.instances:put(object)
      end
      return object
    end

    proto.__index = function(object, field)
      local entity, value, referrent = rawget(object, '__entity')
      if field == '__entity' then
        return entity
      else
        value = entity[field]
      end

      if value == nil then
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

    if proto.cl then
      self.definitions[proto.cl] = proto
    end

    return setmetatable(proto, ep.EntityType)
  end,

  deploy = function(self)
    ep.instances = ep.DataStore({
      location = 'ephemeral.instances',
      indexes = {
        af = {type = 'affinity'},
        al = {type = 'boolean'},
        cl = {type = 'value'},
        et = {type = 'value'},
        module = {type ='prefix', attr = 'et'},
      },
      instantiator = function(instance)
        return self:instantiate(instance, 'storage')
      end
    })
  end,

  enumerateDefinitions = function(self, base, sorted)
    local candidates = {}
    for cl, proto in pairs(self.definitions) do
      if isderived(proto, base) then
        tinsert(candidates, proto)
      end
    end

    if sorted then
      table.sort(candidates, attrsort('noun'))
    end
    return candidates
  end,

  instantiate = function(self, instance, origin)
    local entity = self:load(instance.et or instance.cl)
    if not exceptional(entity) then
      return entity(instance, origin)
    else
      return entity
    end
  end,

  load = function(self, tag, onlyIfDeployed)
    local entity = self.cache[tag]
    if entity then
      return entity
    end

    local module, name = split(tag, ':', 1)
    if not name then
      local definition = self.definitions[module]
      if not definition then
        return exception('InvalidTag')
      end

      entity = definition.baseEntity or definition({})
      self.cache[tag] = entity
      return entity
    end

    module = deployModule(module, onlyIfDeployed)
    if exceptional(module) then
      return model
    elseif not module.entities then
      return exception('InvalidModule')
    end

    entity = module.entities[name]
    if not entity then
      return exception('InvalidTag')
    end

    local definition = self.definitions[entity.cl]
    if not definition then
      return exception('InvalidEntity')
    end

    entity = definition(entity)
    self.cache[tag] = entity
    return entity
  end
}

ep.Entity = ep.entities:define('ep.Entity', nil, {
  noun = _'entity',
  plural = _'entities',

  construct = function(self, origin)
  end,

  constructSurrogateIndexer = function(self, tbl)
    local instance, entity = rawget(self, '__instance'), rawget(self, '__entity')   
    return function(obj, field)
      local value = rawget(tbl, field)
      if value == nil then
        value = instance[field]
        if value == nil then
          value = entity[field]
        end
        if type(value) == 'table' then
          value = ep.surrogate(value)
          rawset(tbl, field, value)
        end
      end
      return value
    end
  end,

  destroy = function(self)
    if self.pt then
      return exception('CannotDestroy', _'Entity is protected.')
    end

    local approval = self:approveDestruction()
    if exceptional(approval) then
      return approval
    end

    ep.instances:delete(self.id)
  end,

  extract = function(self)
    return self.__instance
  end,

  persist = function(self)
    ep.instances:put(self)
    return self
  end,

  approveDestruction = function(self)
  end,

  detected = function(self, phase, location)
  end,

  located = function(self, phase, location)
  end,
})

ep.Script = ep.entities:define('ep.Script', ep.Entity, {
  -- sc: script source
  -- ev: script environment (optional)

  noun = _'script',
  plural = _'scripts',
})

ep.ScriptExecutor = ep.prototype('ep.ScriptExecutor', {
  baseEnvironment = {
    abs=math.abs, acos=acos, asin=asin, atan=atan, atan2=atan2, ceil=ceil, concat=concat,
    cos=cos, date=date, deg=deg, exp=exp, floor=floor, foreach=foreach, foreachi=foreachi,
    format=format, frexp=frexp, ipairs=ipairs, ldexp=ldexp, log=log, log10=log10,
    max=max, min=min, mod=mod, next=next, pairs=pairs, rad=rad, random=random,
    select=select, sin=sin, sort=sort, sqrt=sqrt, tan=tan, tinsert=tinsert, time=time,
    tonumber=tonumber, tostring=tostring, tremove=tremove, type=type, unpack=unpack,

    deepcopy=ep.deepcopy, freeze=ep.freeze, hash=ep.hash, iterkeys=ep.iterkeys,
    itersplit=ep.itersplit, itervalues=ep.itervalues, lstrip=ep.lstrip,
    partition=ep.partition, rstrip=ep.rstrip, split=ep.split, strcount=ep.strcount,
    strip=ep.strip, tcombine=ep.tcombine, tcontains=ep.tcontains, tcopy=ep.tcopy,
    tcount=ep.tcount, tempty=ep.empty, textend=ep.textend, textract=ep.textract,
    tfilter=ep.tfilter, thaw=ep.thaw, tindex=ep.tindex, tinject=ep.tinject,
    tkeys=ep.tkeys, tmap=ep.tmap, treverse=ep.treverse, tunique=ep.tunique,
    tupdate=ep.tupdate, tvalues=ep.tvalues,

    print = print
  },

  staticEnvironment = {},

  construct = function(cls, script, name)
    if type(script) == 'string' then
      script = ep.entities:load(script)
      if exceptional(script) then
        return script
      end
    end
    return cls(script.sc, script.ev, script.nm or name)
  end,

  initialize = function(self, source, environment, name)
    self.environment = {}
    self.name = name or '<script>'
    self.source = source

    if environment then
      self:update(environment)
    end
  end,

  compile = function(self)
    local code, err = loadstring(self.source, self.name)
    if not code then
      return exception('CompilationError', err)
    end

    local bn, sn, en = self.baseEnvironment, self.staticEnvironment, self.environment
    self.code = setfenv(code, setmetatable({}, {
      __index = function(obj, field)
        local value = en[field]
        if value == nil then
          value = sn[field]
          if value == nil then
            value = bn[field]
          end
        end
        return value
      end
    }))
  end,

  derive = function(cls, name, ...)
    local environment = {}
    for i, candidate in ipairs({...}) do
      for attr, value in pairs(candidate) do
        if type(value) == 'table' then
          environment[attr] = surrogate(value)
        elseif type(value) ~= 'userdata' and type(value) ~= 'thread' then
          environment[attr] = value
        end
      end
    end
    return ep.prototype(name, cls, {staticEnvironment=environment})
  end,

  execute = function(self, immutable, mutable, clearEnvironment)
    if not self.code then
      local failure = self:compile()
      if exceptional(failure) then
        return failure
      end
    end

    if immutable or mutable then
      self:update(immutable, mutable, clearEnvironment)
    end

    local status, result = pcall(self.code)
    if status then
      return result
    else
      return exception('ScriptError', result)
    end
  end,

  update = function(self, immutable, mutable, clearEnvironment)
    local environment = self.environment
    if clearEnvironment then
      tclear(environment)
    end

    if immutable then
      for attr, value in pairs(immutable) do
        environment[attr] = surrogate(value)
      end
    end

    if mutable then
      for attr, value in pairs(mutable) do
        environment[attr] = value
      end
    end
    return self
  end
})
