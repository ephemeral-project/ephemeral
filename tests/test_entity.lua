require('base')
require('addon/support')
require('addon/core')
require('addon/entity')

ep.character = {guid = 'xxxx-xxxxxxxx'}

local tests = {}

function tests.test_entities()
  local tester = ep.define('tester', ep.entity, {
    cl = 'tt',
    construct = function(self)
      self.xx = 3
    end
  })
  assert(ep.entityDefinitions.tt == tester)

  local entity = {a=1, tg='module:tag'}
  local e = tester(entity)

  assert(cmpMap(e.__entity, entity))
  assert(e.a == 1)
  assert(rawget(e, 'a') == nil)

  e.b = 2
  assert(e.b == 2)
  assert(rawget(e, 'b') == 2)

  local i1 = e()
  assert(i1.a == 1)
  assert(i1.b == 2)
  assert(#i1.id == 20)
  assert(i1.et == 'module:tag')
  assert(i1.xx == 3)

  assert(i1.cl == 'tt')
  assert(i1.__instance.cl == 'tt')

  i1.bb = 5
  assert(i1.__instance.bb == 5)

  i2 = e(i1.__instance)
  assert(cmpMap(i1.__instance, i2.__instance))
end

runTests('entity.lua', tests, true)
