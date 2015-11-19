local floor = math.floor
local tinsert = table.insert

local function dist(a, b)
  return math.sqrt(math.pow((b[1] - a[1]), 2) + (math.pow((b[2] - a[2]), 2)))
end

local function loc()
  local x, y = GetPlayerMapPosition('player')
  return {floor(x * 10000), floor(y * 10000)}
end

ep.scl = function()
  local a = loc()
  return function()
    return dist(a, loc())
  end
end

ep.location = ep.define('ep.location', ep.entity, {
  detect = function(self, px, py)
    local box = self._detectionBox
    if px >= box[1] and py >= box[2] and px <= box[3] and py <= box[4] then
      if self.dd and not IsIndoors() then
        return false
      elseif self.df and IsFlying() then
        return false
      elseif self.ds and not IsSwimming() then
        return false
      elseif self.dz and GetSubZoneText() ~= self.dz then
        return false
      elseif self.od then

      end
      return true
    end
    return false
  end,

  locate = function(self, px, py)
    local box = self._locationBox
    if px >= box[1] and py >= box[2] and px <= box[3] and py <= box[4] then
      if self.ld and not IsIndoors() then
        return false
      elseif self.lg and IsFlying() then
        return false
      elseif self.ls and not IsSwimming() then
        return false
      elseif self.lz and GetSubZoneText() ~= self.lz then
        return false
      elseif self.ol then

      end
      return true
    end
    return false
  end,

  _prepareLocation = function(self)
    if not self._locationBox then
      local lw, lh = floor(self.lw / 2), floor(self.lh / 2)
      self._locationBox = {self.cx - lw, self.cy - lh, self.cx + lw, self.cy + lh};
    end

    if self.dt  and not self._detectionBox then
      local dw, dh = floor(self.dw / 2), floor(self.dh / 2)
      self._detectionBox = {self.cx - dw, self.cy - dh, self.cx + dw, self.cy + dh};
    end
  end
})

ep.ex1 = ep.location({nm='ex1', rg=126, cx=122, cy=106, lw=2, lh=2, dw=4, dh=4, dt=true})
ep.ix1 = ep.entity({nm='ix1'})

function ept()
  ep.spatial:register(ep.ex1(), ep.ix1())
end

ep.spatial = ep.module{
  name = 'ephemeral:spatial',
  description = '',
  version = 1,

  regions = {},
  specialZones = {},
  zones = {},

  registeredLocations = {},
  locatedInstances = {},
  detectedInstances = {},

  deploy = function(self)
    self._tickFrame = CreateFrame('Frame')
    self._tickProcessor = self:_constructProcessor()
    --self._tickFrame:SetScript('OnUpdate', self._tick_processor)
  end,

  getPlayerLocation = function(self)
    local mid, rgid, candidates = GetCurrentMapAreaID()

    candidates = self.specialZones[mid]
    if candidates then
      rgid = candidates[GetSubZoneText()]
      if not rgid then
        rgid = candidates['*']
      end
    else
      candidates = self.zones[mid]
      if candidates then
        rgid = candidates[GetCurrentMapDungeonLevel()]
      end
    end

    if not rgid or not self.regions[rgid] then
      return nil, nil, nil
    end

    local sc = self.regions[rgid].sc
    if not sc then
      return nil, nil, nil
    end

    local x, y = GetPlayerMapPosition('player')
    return rgid, floor((x / sc) * 1000), floor((y / sc) * 1000)
  end,

  register = function(self, location, instance)
    local locations = self.registeredLocations[location.rg]
    if not locations then
      locations = {}
      self.registeredLocations[location.rg] = locations
    end

    location:_prepareLocation()

    local id = location.tg or location.id
    if locations[id] then
      locations[id][2][instance.id] = instance
    else
      locations[id] = {location, {[instance.id] = instance}}
    end
  end,

  _constructProcessor = function(self)
    local floor = math.floor

    local getMapID, getSubzone, getLevelID, getPosition, setZone =
          GetCurrentMapAreaID, GetSubZoneText, GetCurrentMapDungeonLevel,
          GetPlayerMapPosition, SetMapToCurrentZone

    local regions, zones, specialZones, locations =
          self.regions, self.zones, self.specialZones,
          self.registeredLocations

    local ticks, interval = 0, 0.5

    return function(frame, delta)
      ticks = ticks + delta
      if ticks >= interval then
        ticks = 0
      else
        return
      end

      if WorldMapFrame:IsShown() then
        return
      end
      setZone()

      local mapid = getMapID()
      local candidates, rg, sc, lcid, id = specialZones[mapid]

      if candidates then
        rg = candidates[getSubzone()]
        if not rg then
          rg = candidates['*']
        end
      else
        candidates = zones[mapid]
        if candidates then
          rg = candidates[getLevelID()]
        end
      end

      if rg then
        candidates = locations[rg]
        sc = regions[rg].sc
      end

      local located, detected, newlyLocated, newlyDetected =
            self.locatedInstances, self.detectedInstances, {}, {}

      if candidates and sc then
        local px, py = getPosition('player')
        px, py = floor((px / sc) * 1000), floor((py / sc) * 1000)

        for lcid, candidate in pairs(candidates) do
          local location, instances = candidate[1], candidate[2]
          if location:locate(px, py) then
            for id, instance in pairs(instances) do
              if located[id] then
                located[id], newlyLocated[id] = nil, {instance, location}
                instance:located('tick', location)
              else
                newlyLocated[id] = {instance, location}
                instance:located('start', location)
              end
            end
          elseif location.dt and location:detect(px, py) then
            for id, instance in pairs(instances) do
              if detected[id] then
                detected[id], newlyDetected[id] = nil, {instance, location}
                instance:detected('tick', location)
              else
                newlyDetected[id] = {instance, location}
                instance:detected('start', location)
              end
            end
          end
        end
      end

      self.locatedInstances = newlyLocated
      for id, entry in pairs(located) do
        entry[1]:located('end', entry[2])
      end

      self.detectedInstances = newlyDetected
      for id, entry in pairs(detected) do
        entry[1]:detected('end', entry[2])
      end
    end
  end
}

function ep.describeLocation()
  local stats = {}
  local x, y = GetPlayerMapPosition('player')
  tinsert(stats, 'Zone: '..GetZoneText())
  tinsert(stats, 'Subzone: '..GetSubZoneText())
  tinsert(stats, '')
  tinsert(stats, 'MapID: '..GetCurrentMapAreaID())
  tinsert(stats, 'Level: '..GetCurrentMapDungeonLevel())
  tinsert(stats, 'Position: '..format('%d %d', floor(x * 10000), floor(y * 10000)))
  tinsert(stats, 'Facing: '..format('%0.3f', GetPlayerFacing()))

  local rgid, px, py = ep.spatial:getPlayerLocation()
  if rgid then
    tinsert(stats, '')
    tinsert(stats, 'RegionID: '..rgid)
    tinsert(stats, 'Position: '..px..' '..py)
  end
  return table.concat(stats, '\n')
end
