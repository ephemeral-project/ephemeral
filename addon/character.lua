local format, update
    = string.format, ep.update

CHARACTER_GENDERS = {'unknown', 'male', 'female'}

ep.characterProfile = ep.prototype('ep.characterProfile', {
  __segregation = {attr = '__aspects'},

  initialize = function(self, aspects)
    if aspects then
      self.__aspects = aspects
    end
  end,

  describeCharacter = function(cls, target)
    local target, realm = target or 'player', GetRealmName()
    local description = {
      class = select(2, UnitClass(target)):lower(),
      faction = UnitFactionGroup(target):lower(),
      designation = format('%s (%s)', UnitName(target), realm),
      gender = CHARACTER_GENDERS[UnitSex(target)],
      guild = select(1, GetGuildInfo(target)),
      id = UnitGUID(target):sub(8),
      level = UnitLevel(target),
      name = UnitName(target),
      race = select(2, UnitRace(target)):lower(),
      realm = realm
    }

    description.realmid = description.id:sub(1, 4)
    if description.guild then
      description.guildid = format('%s:%s', description.realmid, description.guild)
    end
    return description
  end,

  extract = function(self)
    return self.__aspects
  end,

  getAffinity = function(self, affinity)
    if affinity == '$c' or affinity == self.id then
      return self.id
    elseif affinity == '$r' or affinity == self.realmid then
      return self.realmid
    elseif affinity == '$g' or affinity == self.guildid then
      return self.guildid
    end
  end,
})

ep.characterization = {
  name = 'ephemeral:characterization',

  deploy = function(self)
    local description = ep.characterProfile:describeCharacter()
    ep.characters = ep.datastore({
      location = 'ephemeral.characters',
      instantiator = ep.characterProfile
    })

    ep.character = ep.characters:get(description.id)
    if ep.character then
      ep.update(ep.character, description)
    else
      ep.character = ep.characterProfile(description)
      ep.characters:put(ep.character)
    end
  end
}
