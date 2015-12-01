
CHARACTER_GENDERS = {'unknown', 'male', 'female'}

ep.characterProfile = ep.prototype('ep.characterProfile', {
  initialize = function(self, params)
    if params then
      for attr, value in pairs(params) do
        self[attr] = value
      end
    end
  end,

  construct = function(cls)
    local id = UnitGUID('player'):sub(8)
    return cls({
      class = select(2, UnitClass('player')):lower(),
      faction = UnitFactionGroup('player'):lower(),
      designation = format('%s (%s)', UnitName('player'), GetRealmName()),
      gender = CHARACTER_GENDERS[UnitSex('player')],
      guild = select(1, GetGuildInfo('player')),
      id = id,
      level = UnitLevel('player'),
      name = UnitName('player'),
      race = select(2, UnitRace('player')):lower(),
      realm = GetRealmName(),
      realmid = id:sub(1, 4),
    })
  end,

  extract = function(self)
    return {
      class = self.class,
      faction = self.faction,
      designation = self.designation,
      gender = self.gender,
      guild = self.gulid,
      id = self.id,
      level = self.level,
      name = self.name,
      race = self.race,
      realm = self.realm,
      realmid = self.realmid
    }
  end
})

ep.characterization = {
  name = 'ephemeral:characterization',
  version = 1,

  deploy = function(self)
    ep.characters = ep.datastore({
      location = 'ephemeral.characters',
      instantiator = ep.characterProfile
    })

    ep.character = ep.characterProfile:construct()
    ep.characters:put(ep.character)
  end
}
