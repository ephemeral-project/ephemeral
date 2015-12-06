local exception, tinject
    = ep.exception, ep.tinject

ep.ItemLocationProvider = ep.prototype('ep.ItemLocationProvider', {
  addToOrderedContainer = function(cls, container, id, position)
    container.n = container.n + 1
    if position then
      container[position] = id
    else
      position = tinject(container, id)
    end
    if position > container.i then
      container.i = position
    end
    return position
  end,

  removeFromOrderedContainer = function(cls, container, position)
    container[position] = nil
    if container.i == position then
      while container[position] == nil do
        position = position - 1
      end
      container.i = position
    end
    container.n = container.n - 1
  end
})

ep.BackpackLocationProvider = ep.prototype('ep.BackpackLocationProvider', ep.ItemLocationProvider, {
  approveMove = function(cls, item, location)

  end,

  approveRemoval = function(cls, item, location)

  end,

  parseLocation = function(cls, location)
    local tokens = {split(location, ':')}
    if #tokens < 2 or #tokens > 3 or tokens[1] ~= 'bk' then
      return exception('InvalidLocation')
    end

    local character = ep.characters:get(tokens[2])
    if not character then
      return exception('InvalidLocation')
    end

    location = {type='bk', character=character}
    if #tokens == 2 then
      return location
    end

    location.position = tonumber(tokens[3])
    if location.position and location.position >= 1 then
      return location
    else
      return exception('InvalidLocation')
    end
  end,

  move = function(cls, item, location)
    local backpack = ep.items:getBackpack(location.character)
    location.position = cls:addToOrderedContainer(backpack, item.id, location.position)
    return format('bk:%s:%d', location.character.id, location.position)
  end,

  remove = function(cls, item, location)
    local backpack, candidate = ep.items:getBackpack(location.character)
    candidate = backpack[location.position]
    
    if candidate and candidate == item then
      cls:removeFromOrderedContainer(backpack, location.position)
    end
  end,

  validateLocation = function(cls, item, location)
    if not location.character then
      location.character = ep.characters:get(location.target)
    end
    if not location.character then
      return exception('InvalidLocation')
    end
    return location
  end
})

ep.ContainerLocationProvider = ep.prototype('ep.ContainerLocationProvider', ep.ItemLocationProvider, {
  parseLocation = function(cls, location)
    local tokens = {split(location, ':')}
    if #tokens ~= 3 or tokens[1] ~= 'cn' then
      return exception('InvalidLocation')
    end

    local container = ep.instances:get(tokens[2])
    if not (container and container.cn and type(container.cn) == 'table') then
      return exception('InvalidLocation')
    end

    position = tonumber(tokens[3])
    if position and position >= 1 then
      return {type='cn', container=container, position=position}
    else
      return exception('InvalidLocation')
    end
  end,

  move = function(cls, item, location)
    local position = cls:addToOrderedContainer(location.container.cn, item.id, location.position)
    return format('cn:%s:%d', location.container.id, position)
  end,
  
  remove = function(cls, item, location)
    local candidate = location.container.cn[location.position]
    if candidate and candidate == item then
      cls:removeFromOrderedContainer(location.container.cn, location.position)
    end
  end,

  validateLocation = function(cls, item, location)
    if not location.container then
      location.container = ep.instances:get(location.target)
    end
    if location.container then
      return location
    else
      return exception('InvalidLocation')
    end
  end
})

ep.EquipmentLocationProvider = ep.prototype('ep.EquipmentLocationProvider', ep.ItemLocationProvider, {
  parseLocation = function(cls, location)
    local tokens = {split(location, ':')}
    if #tokens ~= 4 or tokens[1] ~= 'eq' then
      return exception('InvalidLocation')
    end

    local character = ep.characters:get(tokens[2])
    if not character then
      return exception('InvalidLocation')
    end

    if not ep.items.slots[tokens[3]] then
      return exception('InvalidLocation')
    end

    local position = tonumber(tokens[4])
    if position and position >= 1 then
      return {type='eq', character=character, slot=tokens[3], position=position}
    else
      return exception('InvalidLocation')
    end
  end,

  move = function(cls, item, location)
    local equipment = ep.items:getEquipment(location.character)
  end
})

ep.SocketLocationProvider = ep.prototype('ep.SocketLocationProvider', ep.ItemLocationProvider, {
  parseLocation = function(cls, location)
    local tokens = {split(location, ':')}
    if #tokens ~= 3 or tokens[1] ~= 'sk' then
      return exception('InvalidLocation')
    end

    local item = ep.instances:get(tokens[2])
    if not (item and item.has_sockets) then
      return exception('InvalidLocation')
    end

    if slot_is_valid then
      return {type='sk', item=item, slot=tokens[3]}
    else
      return exception('InvalidLocation')
    end
  end
})

ep.SpatialLocationProvider = ep.prototype('ep.SpatialLocationProvider', ep.ItemLocationProvider, {
  
})

ep.StashLocationProvider = ep.prototype('ep.StashLocationProvider', ep.ItemLocationProvider, {
  approveMove = function(cls, item, location)

  end,

  move = function(cls, item, location)
    return nil
  end,

  validateLocation = function(cls, item, location)
    return location
  end
})

ep.items.locationProviders = {
  bk = ep.BackpackLocationProvider,
  cn = ep.ContainerLocationProvider,
  eq = ep.EquipmentLocationProvider,
  sk = ep.SocketLocationProvider,
  sp = ep.SpatialLocationProvider,
  st = ep.StashLocationProvider
}
