local attrsort, deployModule, exception, exceptional, isderived, split, uniqid
    = ep.attrsort, ep.deployModule, ep.exception, ep.exceptional, ep.isderived,
      ep.split, ep.uniqid

local entityType = ep.copy(ep.metatype)

entityType.__call = function(prototype, entity)
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

local instanceType = {
  __index = function(object, field)
    if field:sub(1, 2) == '__' then
      return rawget(object, field)
    end

    local value = rawget(object, '__instance')[field]
    if value == nil then
      value = rawget(object, '__entity')[field]
    end
    return value
  end,

  __newindex = function(object, field, value)
    rawget(object, '__instance')[field] = value
    if field:sub(1, 1) ~= '_' then
      object.__modified = true
    end
  end
}

ep.entities = {
  name = 'ephemeral:entities',
  version = 1,

  cache = ep.weaktable('v'),
  definitions = {},
  entityType = entityType,
  instanceType = instanceType,

  define = function(self, name, base, proto)
    proto = proto or {}
    proto.__name, proto.__base, proto.__prototypical = name, base, true

    proto.__call = function(entity, instance, origin)
      instance = instance or {}
      if not instance.id then
        instance.id = uniqid()
      end

      instance.cl = entity.cl
      if not instance.et and entity.tg then
        instance.et = entity.tg
      end

      affinity = affinity or entity.at
      if affinity == 'c' then
        instance.af = ep.character.guid
      elseif affinity == 'r' then
        instance.af = ep.character.realmid
      end

      local object = setmetatable({__entity=entity, __instance=instance}, instanceType)
      object:construct(origin)
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

    return setmetatable(proto, entityType)
  end,

  deploy = function(self)
    ep.instances = ep.datastore({
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
      table.sort(candidates, attrsort('title'))
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
    if #module == 0 then
      local definition = self.definitions[name]
      if not definition then
        return exception('InvalidTag')
      end

      entity = definition(definition.default or {})
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

ep.entity = ep.entities:define('ep.entity', nil, {
  title = 'Entity',

  construct = function(self, origin)
  end,

  detected = function(self, phase, location)
  end,

  extract = function(self)
    return self.__instance
  end,

  located = function(self, phase, location)
  end
})
