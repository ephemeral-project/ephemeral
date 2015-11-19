require('base')
require('addon/support')
require('addon/core')

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

function tests.test_events()
    local calls = {}
    local cb = function(...)
        table.insert(calls, {...})
    end

    ep.event('test:test', 'arg')
    assert(#calls == 0)

    local ref = ep.subscribe('test:test', cb)
    ep.event('test:test', 'arg')
    assert(#calls == 1)
    assert(cmpSeq(calls[1], {'test:test', 'arg'}))

    ep.unsubscribe(ref)
    assert(ep.events['test:test'][cb] == nil)

    ep.event('test:test', 'arg')
    assert(#calls == 1)
end

function tests.test_scheduling()
    local calls = {}
    local cb = function(action, ...)
        table.insert(calls, {...})
        if action == 'cancel' then
            return false
        end
    end
end

function tests.test_scripts()
    local script = ep.script('return abs(-1) + 2 + value', {value=3}, 'test')
    assert(script:execute() == 6)
end

runTests('core.lua', tests, true)
