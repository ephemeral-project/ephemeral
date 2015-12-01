local exception, exceptional, itersplit, ref, split
    = ep.exception, ep.exceptional, ep.itersplit, ep.ref, ep.split

local registeredAddons = {}
local registeredComponents = {}
local registeredModules = {}

ep.registeredAddons = registeredAddons
ep.registeredComponents = registeredComponents
ep.registeredModules = registeredModules

ep.module = ep.prototype('ep.module', {
  initialize = function(self, params)
    self.dependencies = {}
    self.components = {}

    if params then
      for attr, value in pairs(params) do
        self[attr] = value
      end
    end
  end,

  deploy = function(self)
    if self.deployed then
      return self.implementation
    end

    local addon = registeredAddons[self.addon]
    if not addon.loaded then
      local result = ep.loadAddon(addon)
      if exceptional(result) then
        return result
      elseif self.deployed then
        return self.implementation
      end
    end

    for dependency, version in pairs(self.dependencies) do
      local candidate = registeredModules[dependency]
      if not candidate then
        return exception('DependencyNotFound', format("module '%s' depends on module '%s',"
          .." which cannot be found", self.name, dependency))
      elseif candidate.version < version then
        return exception('InvalidDependency', format("module '%s' depends on newer version %d"
          .." of module '%s', which is currently at version %d", self.name, version,
          dependency, candidate.version))
      elseif not candidate.deployed then
        local result = candidate:deploy()
        if exceptional(result) then
          return result
        end
      end
    end

    local impl = ref(self.path)
    if type(impl) ~= 'table' then
      return exception('InvalidModule', format("implementation of module '%s' at '%s' is"
        .." not a valid module", self.name, self.path))
    end

    local deployment = ep.deployedModules:getData(self.name)
    if deployment then
      if deployment.version < self.version then
        self:upgrade(deployment.version)
      elseif deployment.version > self.version then
        self:downgrade(deployment.version)
      end
    end

    if impl.deploy then
      local result = impl:deploy()
      if exceptional(result) then
        return result
      end
    end

    if impl.activate then
      local result = impl:activate()
      if exceptional(result) then
        return result
      end
    end

    self.activated = true
    self.deployed = true
    self.implementation = impl

    ep.deployedModules:put(self)
    return impl
  end,

  downgrade = function(self, version)
  end,

  extract = function(self)
    return {id = self.name, version = self.version}
  end,

  isValid = function(self)
    return (self.name and self.path)
  end,

  upgrade = function(self, version)
  end
})

function ep.bootstrapModules()
  ep.deployedModules = ep.datastore({
    location = 'ephemeral.modules',
    instantiator = ep.module
  })
  
  local compatibility
  for i = 1, GetNumAddOns() do
    compatibility = tonumber(GetAddOnMetadata(i, 'X-Ephemeral-Compatibility'))
    if compatibility then
      ep.parseAddon(i, compatibility)
    end
  end

  for name, addon in pairs(registeredAddons) do
    if addon.loaded then
      ep.loadAddon(addon)
    end
  end
end

function ep.deployComponent(class, name)
  local registrations = registeredComponents[class]
  if not (registrations or registrations[name]) then
    return exception('ComponentNotFound')
  end

  local registration = registrations[name]
  if registration.component then
    return registration.component
  end

  local result = ep.deployModule(registration.module)
  if exceptional(result) then
    return result
  end

  local component = ref(registration.path)
  if not component then
    return exception('ComponentNotFound', format("component '%s:%s' from module '%s'"
      .." cannot be found at path '%s'", class, name, registration.module, registration.path))
  end

  registration.component = component
  return component
end

function ep.deployComponents(class)
  local registrations = registeredComponents[class]
  if registrations then
    local components = {}
    for name, registration in pairs(registrations) do
      components[name] = ep.deployComponent(class, name)
    end
    return components
  else
    return {}
  end
end

function ep.deployModule(module, onlyIfDeployed)
  local name
  if type(module) == 'string' then
    name, module = module, registeredModules[module]
  end

  if not module then
    if name then
      return exception('DeployFailed', format("no module named '%s' exists", name))
    else
      return exception('DeployFailed', 'specified module is not a valid module')
    end
  end

  if module.deployed then
    return module.implementation
  elseif onlyIfDeployed then
    return exception('DeployRequired', 'requested module is not deployed yet')
  else
    return module:deploy()
  end
end

function ep.loadAddon(addon)
  local loaded, reason, name, module, result
  if type(addon) == 'string' then
    addon = registeredAddons[addon]
    if not addon then
      return exception('UnknownAddon')
    end
  end

  if not addon.compatible then
    return exception('IncompatibleAddon')
  end

  if not addon.loaded then
    if not addon.loadable then
      return exception('UnloadableAddon')
    end

    loaded, reason = LoadAddOn(addon.name)
    if loaded then
      addon.loaded = true
    else
      return exception('LoadFailed', reason)
    end
  end

  if not addon.deployed then
    for i, module in ipairs(addon.modules) do
      if not module.deployed then
        result = module:deploy()
        if exceptional(result) then
          return result
        end
      end
    end
    addon.deployed = true
  end
end

function ep.parseAddon(id, compatibility)
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
    title = title
  }

  local idx, entry, aspects, module, key, value, class, tag, path, dependencies, components = 1
  while true do
    entry = 'X-Ephemeral-Module['..idx..']'
    aspects = GetAddOnMetadata(id, entry)

    if not aspects then
      break
    end

    module = ep.module({
      addon = addon.name,
      description = GetAddOnMetadata(id, entry..'-Description')
    })

    for pair in itersplit(aspects:gsub('%s*', ''), ',') do
      key, value = split(pair, '=', 1)
      if key == 'version' then
        value = tonumber(value)
      end
      module[key] = value
    end

    dependencies = GetAddOnMetadata(id, entry..'-Dependencies')
    if dependencies then
      for pair in itersplit(dependencies:gsub('%s*', ''), ',') do
        key, value = split(pair, '=', 1)
        module.dependencies[key] = tonumber(value)
      end
    end

    components = GetAddOnMetadata(id, entry..'-Components')
    if components then
      for pair in itersplit(components:gsub('%s*', ''), ',') do
        key, value = split(pair, '=', 1)
        class, tag = split(key, ':', 1)
        tinsert(module.components, {class, tag, value})
      end
    end

    if module:isValid() then
      tinsert(addon.modules, module)
      registeredModules[module.name] = module
      for i, component in ipairs(module.components) do
        class, tag, path = unpack(component)
        if ep.registeredComponents[class] then
          ep.registeredComponents[class][tag] = {module=module.name, path=path}
        else
          ep.registeredComponents[class] = {[tag] = {module=module.name, path=path}}
        end
      end
    end
    idx = idx + 1
  end
  registeredAddons[addon.name] = addon
end
