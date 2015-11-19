_G.date = os.date
_G.time = os.time

if not _G._testsPathInitialized then
  package.path = package.path..';../?.lua'
  _G._testsPathInitialized = true
end

function cmpMap(a, b, ignore_tables)
  for k, v in pairs(a) do
    if b[k] ~= v and not (ignore_tables and type(v) == 'table') then
      return false
    end
  end
  for k, v in pairs(b) do
    if a[k] ~= v and not (ignore_tables and type(v) == 'table') then
      return false
    end
  end
  return true
end

function cmpSeq(a, b)
  for i, v in ipairs(a) do
    if b[i] ~= v then
      return false
    end
  end
  for i, v in ipairs(b) do
    if a[i] ~= v then
      return false
    end
  end
  return true
end

function extractValues(items, field)
  local result = {}
  for i, item in ipairs(items) do
    result[i] = item[field]
  end
  return result
end

function runTests(title, tests, output)
  local results = {}
  for name, test in pairs(tests) do
    status, result = pcall(test)
    if status then
      table.insert(results, name..': completed')
    else
      table.insert(results, string.format('%s: failed (%s)', name, result))
    end
  end

  if output then
    print('Testing '..title)
    print('--------------------------------')
    print(table.concat(results, '\n'))
  end
  return results
end
