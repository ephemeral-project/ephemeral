local exception = ep.exception
local exceptional = ep.exceptional
local split = ep.split

local entityCache = ep.weaktable('v')
local entityDefinitions = {}

ep.entityCache = entityCache
ep.entityDefinitions = entityDefinitions

ep.entitytype = ep.copy(ep.metatype)

ep.entitytype.__call = function(prototype, entity)
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

ep.instancetype = {
  __index = function(object, field)
    local value
    if field:sub(1, 2) == '__' then
      return rawget(object, field)
    end

    value = rawget(object, '__instance')[field]
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

function ep.define(name, base, proto)
  proto = proto or {}
  proto.__name, proto.__base, proto.__prototypical = name, base, true

  proto.__call = function(entity, instance, origin, affinity)
    instance = instance or {}
    if not instance.id then
      instance.id = ep.uniqid()
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

    local object = setmetatable({__entity=entity, __instance=instance}, ep.instancetype)
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
    entityDefinitions[proto.cl] = proto
  end
  return setmetatable(proto, ep.entitytype)
end

function ep.enumerateDefinitions(base, sorted)
  local candidates = {}
  for cl, proto in pairs(entityDefinitions) do
    if ep.isderived(proto, base) then
      tinsert(candidates, proto)
    end
  end

  if sorted then
    table.sort(candidates, ep.attrsort('title'))
  end
  return candidates
end

function ep.loadEntity(tag, onlyIfDeployed)
  local entity = entityCache[tag]
  if entity then
    return entity
  end

  local module, name = split(tag, ':', 1)
  if #module == 0 then
    local definition = entityDefinitions[name]
    if not definition then
      return exception('InvalidTag')
    end

    entity = definition(definition.default or {})
    entityCache[tag] = entity
    return entity
  end

  module = ep.deployModule(module, onlyIfDeployed)
  if exceptional(module) then
    return module
  elseif not module.entities then
    return exception('InvalidModule')
  end

  entity = module.entities[name]
  if not entity then
    return exception('InvalidTag')
  end

  local definition = entityDefinitions[entity.cl]
  if definition then
    entity = definition(entity)
  else
    return exception('InvalidEntity')
  end

  entityCache[tag] = entity
  return entity
end

function ep.instantiateEntity(instance, origin)
  local entity = ep.loadEntity(instance.et or instance.cl)
  if not exceptional(entity) then
    return entity(instance, origin)
  else
    return entity
  end
end

ep.entity = ep.define('ep.entity', nil, {
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

ep.instancestore = ep.prototype('ep.instancestore', {
  initialize = function(self, specification)
    self.indexes = {}
    self.instances = {}
    self.specification = specification

    self.container = self:construct()
    self:reindex()
  end,

  construct = function(self)
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
    local primary, secondaries = nil, {}
    for attr, value in pairs(attrs) do
      local index = self:_getIndex(attr, value)
      if index then
        if primary then
          tinsert(secondaries, index)
        else
          primary = index
        end
        attrs[attr] = nil
      elseif index == false then
        return {}
      else
        return exception('UnindexedAttribute')
      end
    end

    local candidates, included
    if #secondaries > 0 then
      candidates = {}
      for id, presence in pairs(primary) do
        included = true
        for i, secondary in ipairs(secondaries) do
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

    if singular then
      if #candidates == 1 then
        return self:get(candidates[1])
      elseif #candidates == 0 then
        return nil
      else
        return exception('MultipleInstancesFounds')
      end
    end

    local instances, instance = {}
    for i, id in ipairs(candidates) do
      instance = self:get(id)
      if exceptional(instance) then
        return instance
      elseif instance then
        tinsert(instances, instance)
      end
    end
    return instances
  end,

  get = function(self, id)
    local instance = self.instances[id]
    if not instance then
      instance = self.container[id]
      if instance then
        instance = ep.instantiateEntity(instance, 'storage')
        if not exceptional(instance) then
          self.instances[id] = instance
        end
      end
    end
    return instance
  end,

  put = function(self, instance)
    local data = instance:extract()
    if not (data and data.id) then
      return exception('InvalidInstance')
    end

    self.instances[id] = instance
    self.container[id] = data

    for attr, index in pairs(self.specification.indexes) do
      self._indexInstance(data.id, data, attr, index)
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
    if index == 'boolean' then
      return self.indexes[attr]
    elseif index == 'value' or index == 'prefix' then
      return self.indexes[attr][value]
    end
  end,

  _indexInstance = function(self, id, candidate, attr, index)
    local value, indexes = candidate[attr], self.indexes
    if value ~= nil then
      if index == 'boolean' then
        indexes[attr][id] = true
      elseif index == 'value' then
        if indexes[attr][value] then
          indexes[attr][value][id] = true
        else
          indexes[attr][value] = {[id] = true}
        end
      elseif index == 'prefix' then
        value = split(value, ':', 1)[1]
        if indexes[attr][value] then
          indexes[attr][value][id] = true
        else
          indexes[attr][value] = {[id] = true}
        end
      elseif index == 'affinity' then
        
      end
    end
  end
})
