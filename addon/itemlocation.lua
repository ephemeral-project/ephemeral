local exception, tinject
    = ep.exception, ep.tinject

ep.ItemLocationManager = ep.prototype('ep.ItemLocationManager', {
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

  approveAddition = function(self, location, item)
  end,

  approveRemoval = function(self, location, item)
  end,

  deploy = function(self)
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

ep.BackpackManager = ep.prototype('ep.BackpackManager', ep.ItemLocationManager, {
  addItem = function(cls, location, item)
    local backpack = cls:getLocation(location)
    location.position = cls:addToOrderedContainer(backpack, item.id, location.position)
    return format('bk:%s:%d', location.id, location.position)
  end,

  deploy = function(cls)
    if not ep.character.backpack then
      ep.character.backpack = {n=0, i=0}
    end
  end,

  displayLocation = function(cls, location)
    location.items = cls:getLocation(location)
    ep.ItemCollector:display(location, {
      icon = location.items.ic,
      iconCallback = function(icon)
        location.items.ic = icon
      end,
      title = format("%s's Backpack", location.character.name)
    })
  end,

  getLocation = function(cls, location)
    local character = location.character
    if not character.backpack then
      character.backpack = {n=0, i=0}
    end
    return character.backpack
  end,

  parseLocation = function(cls, location)
    local tokens = split(location, ':', nil, true)
    if #tokens ~= 3 or tokens[1] ~= 'bk' then
      return exception('InvalidLocation')
    end

    local character = ep.characters:get(tokens[2])
    if not character then
      return exception('InvalidLocation')
    end

    local position = tonumber(tokens[3])
    if position and position >= 1 then
      return {type='bk', token=location, id=tokens[2], character=character, position=position}
    else
      return exception('InvalidLocation')
    end
  end,

  removeItem = function(cls, location, item)
    local backpack, candidate = cls:getLocation(location)
    candidate = backpack[location.position]

    if candidate and candidate == item then
      cls:removeFromOrderedContainer(backpack, location.position)
    end
  end,

  validateLocation = function(cls, location)
    if location.type ~= 'bk' then
      return exception('InvalidLocation')
    end

    if location.id then
      if location.character then
        if location.character.id ~= location.id then
          return exception('InvalidLocation')
        end
      else
        location.character = ep.characters:get(location.id)
        if not location.character then
          return exception('InvalidLocation')
        end
      end
    elseif location.character then
      location.id = location.character.id
    else
      return exception('InvalidLocation')
    end

    local token = 'bk:'..location.id
    if location.position then
      if not (type(location.position) == 'number' and location.position >= 1) then
        return exception('InvalidLocation')
      end
      token = token..':'..location.position
    end

    location.token = token
    return location
  end
})

ep.ContainerManager = ep.prototype('ep.ContainerManager', ep.ItemLocationManager, {
  addItem = function(cls, location, item)
    local position = cls:addToOrderedContainer(location.container.cn, item.id, location.position)
    return format('cn:%s:%d', location.id, location.position)
  end,

  displayLocation = function(cls, location)
    location.items = cls:getLocation(location)
    ep.ItemCollector:display(location, {
      icon = location.container.ic,
      title = location.container.name
    })
  end,

  getLocation = function(cls, location)
    return location.container.cn
  end,

  parseLocation = function(cls, location)
    local tokens = split(location, ':', nil, true)
    if #tokens ~= 3 or tokens[1] ~= 'cn' then
      return exception('InvalidLocation')
    end

    local container = ep.instances:get(tokens[2])
    if not (container and container.cn and type(container.cn) == 'table') then
      return exception('InvalidLocation')
    end

    position = tonumber(tokens[3])
    if position and position >= 1 then
      return {type='cn', token=location, id=tokens[2], container=container, position=position}
    else
      return exception('InvalidLocation')
    end
  end,

  removeItem = function(cls, location, item)
    local candidate = location.container.cn[location.postition]
    if candidate and candidate == item then
      cls:removeFromOrderedContainer(location.container.cn, location.position)
    end
  end,

  validateLocation = function(cls, location)
    if location.type ~= 'cn' then
      return exception('InvalidLocation')
    end

    if location.id then
      if location.container then
        if location.container.id ~= location.id then
          return exception('InvalidLocation')
        end
      else
        location.container = ep.instances:get(location.id)
        if not location.container then
          return exception('InvalidLocation')
        end
      end
    elseif location.container then
      location.id = location.container.id
    else
      return exception('InvalidLocation')
    end

    if not location.container.cn or type(location.container.cn) ~= 'table' then
      return exception('InvalidLocation')
    end

    local token = 'cn:'..location.id
    if location.position then
      if type(location.position) == 'number' and location.position >= 1 then
        token = token..':'..location.position
      else
        return exception('InvalidLocation')
      end
    end

    location.token = token
    return location
  end
})

ep.EquipmentManager = ep.prototype('ep.EquipmentManager', ep.ItemLocationManager, {
  addItem = function(cls, location, item)
    local equipment = cls:getLocation(location)
    -- todo add item
    return format('eq:%s:%s:%d', location.id, location.slot, location.position)
  end,

  deploy = function(self)
    if not ep.character.equipment then
      ep.character.equipment = {}
    end
  end,

  displayLocation = function(cls, location)
  end,

  getLocation = function(cls, location)
    local character = location.character
    if not character.equipment then
      character.equipment = {}
    end
    return character.equipment
  end,

  parseLocation = function(cls, location)
    local tokens = split(location, ':', nil, true)
    if #tokens ~= 4 or tokens[1] ~= 'eq' then
      return exception('InvalidLocation')
    end

    local character = ep.characters:get(tokens[2])
    if not character then
      return exception('InvalidLocation')
    end

    local slot = tokens[3]
    if not ep.items.slotTokens[slot] then
      return exception('InvalidLocation')
    end

    local position = tonumber(tokens[4])
    if position and position >= 1 then
      return {type='eq', token=location, id=tokens[2], character=character, position=position}
    else
      return exception('InvalidLocation')
    end
  end,

  removeItem = function(cls, location, item)
    local equipment = cls:getLocation(location)
    -- todo remove item
  end,

  validateLocation = function(cls, location)
    if location.type ~= 'eq' then
      return exception('InvalidLocation')
    end

    if location.id then
      if location.character then
        if location.character.id ~= location.id then
          return exception('InvalidLocation')
        end
      else
        location.character = ep.characters:get(location.id)
        if not location.character then
          return exception('InvalidLocation')
        end
      end
    elseif location.character then
      location.id = location.character.id
    else
      return exception('InvalidLocation')
    end

    local token = 'eq:'..location.id
    if location.slot then
      if not ep.items.slotTokens[location.slot] then
        return exception('InvalidLocation')
      end
      if type(location.position) == 'number' and location.position >= 1 then
        token = token..':'..location.slot..':'..location.position
      else
        return exception('InvalidLocation')
      end
    end

    location.token = token
    return location
  end
})

ep.SocketManager = ep.prototype('ep.SocketManager', ep.ItemLocationManager, {
  addItem = function(cls, location, item)

  end,

  getLocation = function(cls, location)
    return location.item.ss
  end,
  
  parseLocation = function(cls, location)
    local tokens = split(location, ':', nil, true)
    if #tokens ~= 4 or tokens[1] ~= 'sk' then
      return exception('InvalidLocation')
    end

    local item = ep.instances:get(tokens[2])
    if not (item and item.ss) then
      return exception('InvalidLocation')
    end
  end
})

ep.SpatialManager = ep.prototype('ep.SpatialManager', ep.ItemLocationManager, {
  
})

ep.StashManager = ep.prototype('ep.StashManager', ep.ItemLocationManager, {
  addItem = function(cls, location, item)
    return nil
  end,

  parseLocation = function(cls, location)
    if location == 's' then
      return {type='st', token='st'}
    else
      return exception('InvalidLocation')
    end
  end,

  removeItem = function(cls, location, item)
  end,

  validateLocation = function(cls, location)
    if location.type == 'st' then
      location.token = 'st'
      return location
    else
      return exception('InvalidLocation')
    end
  end
})

ep.items.locationManagers = {
  bk = ep.BackpackManager,
  cn = ep.ContainerManager,
  eq = ep.EquipmentManager,
  sk = ep.SocketManager,
  sp = ep.SpatialManager,
  st = ep.StashManager
}
