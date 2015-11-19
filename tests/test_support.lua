require('base')
require('addon/support')

ep.character = {guid = 'xxxxxxxx'}

local function r(id, name, description, value)
  return {id=id, name=name, description=description, value=value}
end

local testdata = {
  r(1, 'alpha', 'something wicked this way comes', 'third'),
  r(2, 'bravo', 'a stitch in time saves nine', 'first'),
  r(3, 'charlie', 'take the road less travelled', 'second'),
  r(4, 'delta', 'the very model of a modern man', 'fourth'),
  r(5, 'echo', 'to be or not to be, that is the question', 'first'),
  r(6, 'foxtrot', 'ever is the time of his concern', 'second'),
  r(7, 'golf', 'stands he, a man apart', 'third'),
  r(8, 'hotel', 'long, long time ago in a galaxy far away', 'fifth'),
  r(9, 'india', 'luke, I am your father', 'fifth'),
  r(10, 'juliet', 'nevermore, said the raven', 'first'),
  r(11, 'kilo', 'quote him thusly, said my father', 'second'),
  r(12, 'lima', 'elementary, my dear watson', 'third'),
  r(13, 'mike', 'give all and take none', 'sixth'),
  r(14, 'november', 'virtue is its own punishment', 'first'),
  r(15, 'oscar', 'better them than us, said he', 'second'),
  r(16, 'papa', 'much ado about something', 'third'),
  r(17, 'quebec', 'dinner out, was the name of the op', 'fourth'),
  r(18, 'romeo', 'very tricky, is the way of the world', 'sixth'),
  r(19, 'sierra', 'join us or die', 'first'),
  r(20, 'tango', 'wait for it (wait for it)', 'second'),
  r(21, 'uniform', 'only here might that happen', 'second'),
  r(22, 'victor', 'dropping the ball is sometimes the best option', 'third'),
  r(23, 'whiskey', 'a life without the drink would not be my life', 'first'),
  r(24, 'x-ray', 'and on and on the story goes', 'sixth'),
}

local tests = {}

function tests.test_attempt()
  local willSucceed = function(value)
    return value
  end
  assert(ep.attempt(willSucceed, 1) == 1)

  local willFail = function(value)
    error('failed')
  end
  assert(ep.exceptional(ep.attempt(willFail, 1)))
end

function tests.test_clear()
  assert(cmpSeq(ep.clear({}), {}))
  assert(cmpSeq(ep.clear({1,2,3}), {}))
  assert(cmpMap(ep.clear({}), {}))
  assert(cmpMap(ep.clear({a=1, b=2}), {}))
end

function tests.test_combine()
  local result = ep.combine({}, {})
  assert(cmpMap(result, {}))

  result = ep.combine({'a', 'b'}, {1, 2})
  assert(cmpMap(result, {a=1, b=2}))
end

function tests.test_contains()
  assert(ep.contains({}, 1) == false)
  assert(ep.contains({1}, 1) == true)
  assert(ep.contains({3, 2, 1}, 1) == true)
end

function tests.test_copy()
  local original, copy = {a=1}
  copy = ep.copy(original)

  assert(original ~= copy)
  assert(cmpMap(original, copy))
end

function tests.test_count()
  assert(ep.count({}, 1) == 0)
  assert(ep.count({1, 2, 3}, 1) == 1)
  assert(ep.count({1, 2, 2, 3}, 2) == 2)
  assert(ep.count({1, 2, 2, 3}, 2, 1) == 1)
end

function tests.test_deepcopy()
  local original, copy = {a=1, b={c=3}}
  copy = ep.deepcopy(original)

  assert(copy ~= original)
  assert(copy.b ~= original.b)
  assert(cmpMap(original, copy, true))
  assert(cmpMap(original.b, copy.b))
end

function tests.test_empty()
  assert(ep.empty({}) == true)
  assert(ep.empty({a=1}) == false)
end

function tests.test_exceptions()
  assert(not ep.exceptional({}))
  assert(ep.exceptional(ep.exception()))
  assert(not ep.exceptional(ep.exception('test'), 'more'))
  assert(ep.exceptional(ep.exception('test'), 'test'))
end

function tests.test_extend()
  assert(cmpSeq(ep.extend({1}, {2}, {3}), {1, 2, 3}))
end

function tests.test_fieldsort()
  ep.fieldsort(testdata, {'value', true}, 'name')
  --print(ep.repr(extractValues(testdata, 'value')))
end

function tests.test_filter()
  local cb = function(value)
    return (value > 0)
  end
  assert(cmpSeq(ep.filter({-1, 0, 1, 2, 1, 0, -1}, cb), {1, 2, 1}))
end

function tests.test_freeze_and_thaw()
  local obj = ep.thaw(ep.freeze(nil))
  assert(type(obj) == 'nil')

  obj = ep.thaw(ep.freeze(true))
  assert(type(obj) == 'boolean' and obj == true)

  obj = ep.thaw(ep.freeze(false))
  assert(type(obj) == 'boolean' and obj == false)

  obj = ep.thaw(ep.freeze(1))
  assert(type(obj) == 'number' and obj == 1)

  obj = ep.thaw(ep.freeze(1.1))
  assert(type(obj) == 'number' and obj == 1.1)

  obj = ep.thaw(ep.freeze(''))
  assert(type(obj) == 'string' and obj == '')

  obj = ep.thaw(ep.freeze('test'))
  assert(type(obj) == 'string' and obj == 'test')

  obj = ep.thaw(ep.freeze({}))
  assert(type(obj) == 'table' and cmpMap(obj, {}))

  obj = ep.thaw(ep.freeze({a=1}))
  assert(type(obj) == 'table' and cmpMap(obj, {a=1}))

  local everything = {a=true, b=false, c=1, d=1.0, e='', f='test', g={}, h={1,2,3},
    i={aa={bb=2}}, j={{cc=3}}}
  local thawed = ep.thaw(ep.freeze(everything))
  assert(type(thawed) == 'table')
  assert(cmpMap(everything, thawed, true))
  assert(cmpMap(everything.g, thawed.g))
  assert(cmpSeq(everything.h, thawed.h))

  local frozen = ep.freeze('testing with \n\n newlines')
  assert(not frozen:find('\n'))
  assert(ep.thaw(frozen) == 'testing with \n\n newlines')
end

function tests.test_hash()
  local tbl, func = {}, function() end
  assert(ep.hash(tbl) == tostring(tbl):sub(8))
  assert(ep.hash(func) == tostring(func):sub(11))
  assert(ep.hash('testing') == ep.strhash('testing'))
end

function tests.test_index()
  assert(ep.index({}, 1) == nil)
  assert(ep.index({1, 2, 3}, 1) == 1)
  assert(ep.index({1, 2, 3}, 3) == 3)
  assert(ep.index({2, 2, 2}, 2, 2) == 2)
end

function tests.test_inject()
  local tbl = {}
  assert(ep.inject(tbl, 1) == 1)
  assert(cmpSeq(tbl, {1}))

  tbl = {1, nil, 3}
  assert(ep.inject(tbl, 2) == 2)
  assert(cmpSeq(tbl, {1, 2, 3}))
end

function tests.test_invoke()
  local cb = function(...)
    return {...}
  end

  local args = ep.invoke(cb)
  assert(cmpSeq(args, {}))

  args = ep.invoke(cb, 1)
  assert(cmpSeq(args, {1}))

  args = ep.invoke({cb, 'a'})
  assert(cmpSeq(args, {'a'}))

  args = ep.invoke({cb, 'a'}, 1)
  assert(cmpSeq(args, {'a', 1}))
end

function tests.test_isderived()
  local alpha = ep.prototype('alpha', {})
  local beta = ep.prototype('beta', alpha, {})
  local gamma = ep.prototype('gamma', {})

  assert(ep.isderived(beta, alpha))
  assert(ep.isderived(beta, beta))
  assert(not ep.isderived(gamma, alpha))
  assert(not ep.isderived(beta, beta, true))
end

function tests.test_iterkeys()
  local keys = {}
  for key in ep.iterkeys({a=1, b=2, c=3}, true) do
    table.insert(keys, key)
  end
  assert(cmpSeq(keys, {'a', 'b', 'c'}))
end

function tests.test_itersplit()
  local splits = {}
  for split in ep.itersplit('a,b,c', ',') do
    table.insert(splits, split)
  end
  assert(cmpSeq(splits, {'a', 'b', 'c'}))
end

function tests.test_itervalues()
  local values = {}
  for value in ep.itervalues({a=1, b=2, c=3}, true) do
    table.insert(values, value)
  end
  assert(cmpSeq(values, {1, 2, 3}))
end

function tests.test_keys()
  assert(cmpSeq(ep.keys({}), {}))
  assert(cmpSeq(ep.keys({a=1, b=2, c=3}, true), {'a', 'b', 'c'}))
end

function tests.test_lstrip()
  assert(ep.lstrip('') == '')
  assert(ep.lstrip('test') == 'test')
  assert(ep.lstrip('   test') == 'test')
  assert(ep.lstrip('   test   ') == 'test   ')
  assert(ep.lstrip('test', '+') == 'test')
  assert(ep.lstrip('+test', '+') == 'test')
  assert(ep.lstrip('++test', '+') == 'test')
  assert(ep.lstrip('+test+', '+') == 'test+')
end

function tests.test_map()
  local cb = function(value)
    return value + 1
  end
  assert(cmpSeq(ep.map({1, 2, 3}, cb), {2, 3, 4}))
end

function tests.test_partition()
  assert(cmpSeq({ep.partition('onetwothree')}, {'onetwothree'}))
  assert(cmpSeq({ep.partition('onetwothree', 3, 3, 5)}, {'one', 'two', 'three'}))
  assert(cmpSeq({ep.partition('onetwothree', 3, 3)}, {'one', 'two', 'three'}))
end

function tests.test_promise()
  local calls, proto = {}, ep.prototype()
  local cb = function(...)
    table.insert(calls, {...})
  end

  ep.satisfy(proto, 'test', 2)
  assert(#calls == 0)

  ep.promise(proto, 'test', {cb, 1})
  assert(#calls == 0)
  ep.satisfy(proto, 'test', 2)
  assert(cmpSeq(table.remove(calls, 1), {1, 2}))

  ep.satisfy(proto, 'test', 2)
  assert(#calls == 0)
end

function tests.test_prototype()
  local alpha = ep.prototype({
    action = function(self, value)
      return value + 1
    end
  })
  assert(alpha():action(1) == 2)

  local beta = ep.prototype(alpha, {
    action = function(self, value)
      return value + 2
    end
  })
  assert(beta():action(1) == 3)

  local gamma = ep.prototype(beta, {
    action = function(self, value)
      return self:super():action(value) + 1
    end
  })
  assert(gamma():action(1) == 4)
end

function tests.test_pseudoid()
  assert(#ep.pseudoid() == 8)
  local ids = {}
  for i = 1, 10, 1 do
    table.insert(ids, ep.pseudoid())
  end
  assert(#ep.unique(ids) == 10)
end

function tests.test_put()
  _G.one = {two={}}
  assert(ep.put('one.two.three', 'test') == true)
  assert(_G.one.two.three == 'test')
  assert(ep.put('one.two.three', 'more') == false)
  assert(_G.one.two.three == 'test')
  assert(ep.put('one.two.three', 'more', true) == true)
  assert(_G.one.two.three == 'more')
  _G.one = nil
end

function tests.test_ref()
  _G.one = {two={a=1}}
  assert(ep.ref('one') == _G.one)
  assert(ep.ref('one.two') == _G.one.two)
  assert(ep.ref('one.two.a') == _G.one.two.a)
  assert(ep.ref('one.two.three') == nil)
  _G.one = nil
end

function tests.test_remove()
  assert(cmpSeq(ep.remove({}, 4), {}))
  assert(cmpSeq(ep.remove({1, 2, 3}, 4), {1, 2, 3}))
  assert(cmpSeq(ep.remove({1, 2, 3}, 2), {1, 3}))
end

function tests.test_repr()
  assert(ep.repr(nil) == 'nil')
  assert(ep.repr(true) == 'true')
  assert(ep.repr(false) == 'false')
  assert(ep.repr('') == "''")
  assert(ep.repr(1) == '1')
  assert(ep.repr(1.1) == '1.1')
end

function tests.test_reverse()
  assert(cmpSeq(ep.reverse({}), {}))
  assert(cmpSeq(ep.reverse({1, 2, 3}), {3, 2, 1}))
end

function tests.test_rstrip()
  assert(ep.rstrip('') == '')
  assert(ep.rstrip('test') == 'test')
  assert(ep.rstrip('test   ') == 'test')
  assert(ep.rstrip('   test   ') == '   test')
  assert(ep.rstrip('test', '+') == 'test')
  assert(ep.rstrip('test+', '+') == 'test')
  assert(ep.rstrip('test++', '+') == 'test')
  assert(ep.rstrip('+test+', '+') == '+test')
end

function tests.test_splice()
  assert(cmpSeq(ep.splice({}, 0, 0), {}))
  assert(cmpSeq(ep.splice({1, 2, 3}, 2, 1), {1, 3}))
  assert(cmpSeq(ep.splice({1, 2, 3}, 2, 1, 4), {1, 4, 3}))
  assert(cmpSeq(ep.splice({1, 2, 3}, 2, 0, 4), {1, 4, 2, 3}))
end

function tests.test_split()
  assert(cmpSeq({ep.split('', ',')}, {''}))
  assert(cmpSeq({ep.split('a,b,c', ';')}, {'a,b,c'}))
  assert(cmpSeq({ep.split('a,b,c', ',')}, {'a', 'b', 'c'}))
  assert(cmpSeq({ep.split('a,b,c', ',', 1)}, {'a', 'b,c'}))
end

function tests.test_strcount()
  assert(ep.strcount('', 'a') == 0)
  assert(ep.strcount('aaa', 'a') == 3)
end

function tests.test_strhash()
  assert(ep.strhash('test') == ep.strhash('test'))
  assert(ep.strhash('test') ~= ep.strhash('more'))
  assert(ep.strhash('a moderately long string') == ep.strhash('a moderately long string'))
  assert(ep.strhash('a moderately long string') ~= ep.strhash('a moderately mong string'))
  assert(#ep.strhash('a somewhat long string to barely sanity check strhash with') == 8)
end

function tests.test_strip()
  assert(ep.strip('') == '')
  assert(ep.strip('test') == 'test')
  assert(ep.strip('test   ') == 'test')
  assert(ep.strip('   test') == 'test')
  assert(ep.strip('   test   ') == 'test')
  assert(ep.strip('test', '+') == 'test')
  assert(ep.strip('test+', '+') == 'test')
  assert(ep.strip('test++', '+') == 'test')
  assert(ep.strip('+test', '+') == 'test')
  assert(ep.strip('++test', '+') == 'test')
  assert(ep.strip('+test+', '+') == 'test')
end

function tests.test_surrogate()
  local obj = {a=1, b={c=2}}
  local s = ep.surrogate(obj)
  assert(cmpMap(s, obj, true))
  assert(cmpMap(s.b, {c=2}))

  s.x = 2
  assert(s.x == nil)
  s.b.x = 2
  assert(s.b.x == nil)
end

function tests.test_unique()
  assert(cmpSeq(ep.unique({}), {}))
  assert(cmpSeq(ep.unique({1, 2, 3}), {1, 2, 3}))
  assert(cmpSeq(ep.unique({1, 2, 2, 3, 3, 3}), {1, 2, 3}))
end

function tests.test_update()
  assert(cmpMap(ep.update({}, {}), {}))
  assert(cmpMap(ep.update({a=1}, {b=2}), {a=1, b=2}))
  assert(cmpMap(ep.update({a=1, b=2}, {b=22, c=3}), {a=1, b=22, c=3}))
  assert(cmpMap(ep.update({a=1}, {b=2}, {c=3}), {a=1, b=2, c=3}))
end

function tests.test_values()
  assert(cmpSeq(ep.values({}), {}))
  assert(cmpSeq(ep.values({a=1, b=2, c=3}, true), {1, 2, 3}))
end

function tests.test_pqueue()
  local queue = ep.pqueue('value')
  assert(queue:push({id='a', value=1}) == 1)
  assert(queue:push({id='c', value=2}) == 2)
  assert(queue:push({id='b', value=1}) == 3)

  assert(queue:peek(0) == nil)
  assert(queue:peek(1).id == 'a')

  assert(queue:pop(0) == nil)
  assert(queue:pop(1).id == 'a')
  assert(queue:pop(1).id == 'b')
  assert(queue:pop(1) == nil)
end

function tests.test_ring()
  local ring = ep.ring()
  assert(ring:next() == nil)

  local v1 = {v=1}
  ring:add(v1)

  assert(ring:next().v == 1)
  assert(ring:next().v == 1)

  local v2 = {v=2}
  ring:add(v2)

  assert(ring:next().v == 1)
  assert(ring:next().v == 2)
  assert(ring:next().v == 1)
  assert(ring:next().v == 2)

  ring:remove(v2)
  assert(ring:next().v == 1)
  assert(ring:next().v == 1)

  ring:remove(v1)
  assert(ring:next() == nil)
end

runTests('support.lua', tests, true)
