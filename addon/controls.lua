local _, Color, attachTooltip, attrsort, band, detachTooltip, exception, exceptional,
      fieldsort, floor, invoke, isinstance, put, ref, strip, tclear, tindex, tupdate
    = ep.localize, ep.Color, ep.attachTooltip, ep.attrsort, bit.band, ep.detachTooltip,
      ep.exception, ep.exceptional, ep.fieldsort, math.floor, ep.invoke, ep.isinstance, ep.put,
      ep.ref, ep.strip, ep.tclear, ep.tindex, ep.tupdate

ep.Button = ep.control('ep.Button', 'epButton', ep.BaseControl, 'button', {
  initialize = function(self, params)
    if params and params.tooltip then
      attachTooltip(self, params.tooltip, {delay=1,
        location={anchor=self, edge='BOTTOMLEFT', hook='TOPLEFT', x=-5}})
    end

    local text = self:GetText()
    if text then
      self:SetText(_(text))
    end
  end,

  disable = function(self)
    self:Disable()
    self:SetAlpha(0.6)
    return self
  end,

  enable = function(self)
    self:Enable()
    self:SetAlpha(1.0)
    return self
  end
})

ep.CheckBox = ep.control('ep.CheckBox', 'epCheckBox', ep.BaseControl, 'checkbox', {
  initialize = function(self, params)
    params = params or {}
    if params.onValueChanged then
      self:subscribe(':valueChanged', params.onValueChanged)
    end

    if params.tooltip then
      attachTooltip(self, params.tooltip, {delay=1,
        location={anchor=self, edge='BOTTOMLEFT', hook='TOPLEFT', x=-5}})
    end

    local width = self:GetTextWidth() + 6
    if self.reversedText then
      self:SetHitRectInsets(-width, 0, 0, 0)
    else
      self:SetHitRectInsets(0, -width, 0, 0)
    end

    local text = self:GetText()
    if text then
      self:SetText(_(text))
    end
  end,

  disable = function(self, state)
    self:Disable()
    if state ~= nil then
      self:SetChecked(state)
    end

    self:SetAlpha(0.6)
    return self
  end,

  enable = function(self, state)
    self:Enable()
    if state ~= nil then
      self:SetChecked(state)
    end

    self:SetAlpha(1.0)
    return self
  end,

  setValue = function(self, value, suppressEvent)
    if value ~= self:GetChecked() then
      self:SetChecked(value)
      if not suppressEvent then
        self:event(':valueChanged', value)
      end
    end
    return self
  end
})

ep.CheckBox.getValue = ep.CheckBox.GetChecked

ep.ColorSpot = ep.control('ep.ColorSpot', 'epColorSpot', ep.Button, nil, {
  initialize = function(self, params)
    params = params or {}
    self.defaultColor = params.defaultColor or 'black'

    self:setValue(self.defaultColor, true)
    if params.onValueChanged then
      self:subscribe(':valueChanged', params.onValueChanged)
    end

    if params and params.tooltip then
      attachTooltip(self, params.tooltip, {delay=1,
        location={anchor=self, edge='BOTTOMLEFT', hook='TOPLEFT', x=-5}})
    end

    if self.label then
      self.label:SetText(_(self.label:GetText()))
    end
  end,

  disable = function(self, cleared)
    self:SetAlpha(0.6)
    if cleared then
      self.spot:SetTexture(0, 0, 0, 0)
    end

    self:Disable()
    return self
  end,

  enable = function(self, value)
    self:SetAlpha(1.0)
    self:setValue(value or self.color, true)

    self:Enable()
    return self
  end,

  getValue = function(self)
    return self.color
  end,

  selectColor = function(self)
    epColorBrowser:display({anchor=self, color=self.color,
      onSelect={self.setValue, self}})
  end,

  setValue = function(self, value, suppressEvent)
    if not isinstance(value, Color) then
      value = Color(value)
    end

    if value == self.color then
      return self
    end

    self.color = value
    self.spot:SetTexture(unpack(self.color:toNative()))

    if not suppressEvent then
      self:event(':valueChanged', self.color)
    end
    return self
  end
})

ep.DropBox = ep.control('ep.DropBox', 'epDropBox', ep.Button, nil, {
  initialize = function(self, params)
    params = params or {}
    self.default = params.default
    self.items = {}
    self.prefix = ''
    self.sorted = params.sorted
    self.values = {}

    if params.prefix then
      self.prefix = ep.Color('label'):applyToken(params.prefix..': ')
    end

    self.menu = ep.Menu(self.name..'Menu', self, {
      callback = function(value)
        self:setValue(value)
      end,
      items = self.items,
      location = {anchor=self, x=0, y=-18},
      scrollable = (params.scrollable or false),
      window = (params.window or 8),
      width = self
    })

    if params.items then
      self:populate(params.items, self.default, params.value)
    end

    if params.onValueChanged then
      self:subscribe(':valueChanged', params.onValueChanged)
    end

    if params.tooltip then
      attachTooltip(self, params.tooltip, {delay=1,
        location={anchor=self, edge='BOTTOMLEFT', hook='TOPLEFT', x=-5}})
    end

    if self.label then
      self.label:SetText(_(self.label:GetText()))
    end
  end,

  add = function(self, value, label, position)
    local item = {value = value, label = label or value}
    if self.values[value] then
      self:remove(value)
    end

    self.values[value] = label or value
    if position then
      tinsert(self.items, position, item)
    else
      tinsert(self.items, item)
    end

    if self.sorted then
      sort(self.items, self._sortByLabel)
    end

    self.menu.built = false
    return self
  end,

  disable = function(self, cleared)
    self:SetAlpha(0.6)
    if cleared then
      self:SetText('')
    end

    self:Disable()
    return self
  end,

  enable = function(self, value)
    self:SetAlpha(1.0)
    if value then
      self:setValue(value, true)
    elseif self:GetText() == '' then
      self:setText(self.value)
    end

    self:Enable()
    return self
  end,

  getValue = function(self)
    return self.value
  end,

  open = function(self)
    if self.menu and #self.items > 0 then
      self.menu:toggle()
    end
    return self
  end,

  populate = function(self, population, default, value)
    local items, values = tclear(self.items), tclear(self.values)
    for i, item in ipairs(population) do
      if type(item) == 'table' then
        if item.label then
          values[item.value] = item.label
          items[i] = item
        else
          values[item[1]] = item[2]
          items[i] = {label=item[2], value=item[1]}
        end
      else
        values[item] = item
        items[i] = {label=item, value=item}
      end
    end

    self.menu.built = false
    if self.sorted then
      sort(items, self._sortByLabel)
    end

    self.default = default
    if value then
      self:setValue(value, true)
    elseif default then
      self:setValue(default, true)
    end
    return self
  end,

  remove = function(self, value, position)
    if value then
      for i, item in ipairs(self.items) do
        if item.value == value or (item.value == nil and item.label == value) then
          position = i
          break
        end
      end
    end

    if position then
      value = self.items[position].value
      self.values[value], self.menu.built = nil, false
      tremove(self.items, position)
      if value == self.value then
        self:setValue(self.default or self.items[1].value)
      end
    end
    return self
  end,
  
  setValue = function(self, value, suppressEvent)
    if self.values[value] and self.value ~= value then
      self.value = value
      P(suppressEvent)
      if not suppressEvent then
        self:event(':valueChanged', value)
      end
      self:setText(value)
    end
    return self
  end,

  setText = function(self, value)
    self:SetText(self.prefix..self.values[value])
  end,

  _sortByLabel = function(first, second)
    return first.label < second.label
  end
})

ep.ComboBox = ep.control('ep.ComboBox', 'epComboBox', ep.DropBox, 'editbox', {
  capture = function(self)
    self:setValue(self:GetText())
    return self
  end,

  disable = function(self, cleared)
    self:ClearFocus()
    self:super():disable(cleared)
    self:EnableKeyboard(false)
    self:EnableMouse(false)
    return self
  end,

  enable = function(self, value)
    self:super():enable(value)
    self:EnableKeyboard(true)
    self:EnableMouse(true)
    return self
  end,

  setValue = function(self, value, suppressEvent)
    if value ~= self.value then
      self.value = value
      if not suppressEvent then
        self:event(':valueChanged', value)
      end
      -- TODO reconcile this with dropbox's approach to values
      self:SetText(value)
    end

    self:ClearFocus()
    return self
  end
})

ep.EditArea = ep.control('ep.EditArea', 'epEditArea', ep.BaseFrame, nil, {
  initialize = function(self, params)
    params = params or {}
    self.editbox = self.scrollFrame:GetScrollChild()
    self.placeholder = params.placeholder

    if params.locked then
      self:lock(true)
    end

    if self.placeholder then
      self.innerLabel:SetText(self.placeholder)
      if self.editbox:GetText() == '' then
        self.innerLabel:Show()
      end
    end

    if params.tooltip then
      attachTooltip(self, params.tooltip, {delay=1,
        location={anchor=self, edge='BOTTOMLEFT', hook='TOPLEFT', x=-5}})
    end
  end,

  append = function(self, content, unmoved)
    local position = (unmoved) and self.editbox:GetCursorPosition() or nil
    self.editbox:SetCursorPosition(self.editbox:GetNumLetters())
    self.editbox:Insert(content)

    if position then
      self.editbox:SetCursorPosition(position)
    end
  end,

  disable = function(self, cleared, saved)
    self.disabled = true
    self.editbox:ClearFocus()
    self:SetAlpha(0.6)

    if saved then
      self._savedText = self.editbox:GetText()
    end

    if cleared then
      self.editbox:SetText('')
    end

    self.editbox:EnableKeyboard(false)
    self.editbox:EnableMouse(false)
    return self
  end,

  enable = function(self, cleared)
    self.disabled = nil
    self:SetAlpha(1.0)

    if cleared then
      self.editbox:SetText('')
    elseif self._savedText then
      self.editbox:SetText(self._savedText)
      self._savedText = nil
    end

    self.editbox:EnableKeyboard(true)
    self.editbox:EnableMouse(true)
    return self
  end,

  getValue = function(self)
    return self:GetText()
  end,

  lock = function(self, locked)
    self.editbox:EnableKeyboard(not locked)
    return self
  end,

  setValue = function(self, value)
    self.editbox:SetText(value or '')
    if #self.editbox:GetText() == 0 then
      if self.placeholder then
        self.innerLabel:Show()
      end
    else
      self.innerLabel:Hide()
    end
    return self
  end,

  updateCursor = function(self, x, y)
    local offset, height, y = self.scrollFrame:GetVerticalScroll(), self:GetHeight() - 26, abs(y)
    if y < offset then
      self.scrollFrame:scroll(y)
    elseif y > (offset + height) then
      self.scrollFrame:scroll(y - height)
    end
  end,

  _focusLost = function(self)
    self.editbox:HighlightText(0, 0)
    if self.placeholder then
      if self.editbox:GetText() == '' then
        self.innerLabel:Show()
      else
        self.innerLabel:Hide()
      end
    end
  end
})

ep.EditBox = ep.control('ep.EditBox', 'epEditBox', ep.BaseControl, 'editbox', {
  initialize = function(self, params)
    params = params or {}
    self.clearable = params.clearable
    self.placeholder = params.placeholder
    self.historyEnabled = params.historyEnabled
    self.historyLimit = params.historyLimit or 30
    self.historyTable = params.historyTable

    if self.clearable and self:GetText() ~= '' then
      self.clearButton:Show()
    end

    if self.placeholder then
      self.innerLabel:SetText(self.placeholder)
      if self:GetText() == '' then
        self.innerLabel:Show()
      end
    end

    if params.tooltip then
      attachTooltip(self, params.tooltip, {delay=1, 
        location={anchor=self, edge='BOTTOMLEFT', hook='TOPLEFT', x=-5}})
    end

    if self.label then
      self.label:SetText(_(self.label:GetText()))
    end
  end,

  addToHistory = function(self, value)
    if not (self.historyEnabled and #value > 0) then
      self:cancelHistory()
      return self
    end

    local history = self:getHistory()
    for i, line in ipairs(history) do
      if value == line then
        if i > 1 then
          tremove(history, i)
        else
          self:cancelHistory()
          return self
        end
      end
    end

    tinsert(history, 1, value)
    if #history > self.historyLimit then
      tremove(history)
    end

    self:cancelHistory()
    return self
  end,

  append = function(self, content, unmoved)
    local position = nil
    if #content == 0 then
      return
    end

    if unmoved then
      position = self:GetCursorPosition()
    end

    self:SetCursorPosition(self:GetNumLetters())
    self:Insert(content)

    if position then
      self:SetCursorPosition(position)
    end
    return self
  end,

  cancelHistory = function(self)
    self.historyActive, self.historyOffset = nil, nil
  end,

  disable = function(self, cleared, saved)
    self:ClearFocus()
    self:SetAlpha(0.6)

    if saved then
      self._savedText = self:GetText()
    end

    if cleared then
      self:SetText('')
    end

    self:EnableKeyboard(false)
    self:EnableMouse(false)
    return self
  end,

  enable = function(self, cleared)
    self:SetAlpha(1.0)
    if cleared then
      self:SetText('')
    elseif self._savedText then
      self:SetText(self._savedText)
      self._savedText = nil
    end

    self:EnableKeyboard(true)
    self:EnableMouse(true)
    return self
  end,

  getHistory = function(self)
    local historyTable = self.historyTable
    if type(historyTable) == 'string' then
      historyTable = ref(historyTable)
      if type(historyTable) ~= 'table' then
        historyTable = {}
        put(self.historyTable, historyTable)
      end
    elseif not historyTable then
      historyTable = {}
      self.historyTable = historyTable
    end
    return historyTable
  end,

  setValue = function(self, value)
    if type(value) ~= 'string' or value == self:GetText() then
      return self
    end

    self:SetText(value)
    if #value == 0 then
      self.clearButton:Hide()
      if self.placeholder and self:HasFocus() then
        self.innerLabel:Show()
      end
    else
      self.innerLabel:Hide()
      if self.clearable then
        self.clearButton:Show()
      end
    end
    return self
  end,

  showHistory = function(self)
    if not self.historyEnabled then
      return
    end

    if IsControlKeyDown() then
      self:setValue(self.historyStub or '')
      self:cancelHistory()
      return
    end

    local history = self:getHistory()
    if #history == 0 then
      return
    end

    if self.historyActive then
      if IsShiftKeyDown() then
        self.historyOffset = self.historyOffset - 1
        if self.historyOffset == 0 then
          self.historyOffset = #history
        end
      else
        self.historyOffset = self.historyOffset + 1
        if self.historyOffset > #history then
          self.historyOffset = 1
        end
      end
    else
      self.historyActive = true
      self.historyOffset = 1
    end
    self:setValue(history[self.historyOffset])
  end,

  _focusLost = function(self)
    self:HighlightText(0, 0)
    self:cancelHistory()

    if self.placeholder then
      if self:GetText() == '' then
        self.innerLabel:Show()
      else
        self.innerLabel:Hide()
      end
    end

    if self.clearable then
      if self:GetText() == '' then
        self.clearButton:Hide()
      else
        self.clearButton:Show()
      end
    end
  end
})

ep.EditBox.getValue = ep.EditBox.GetText

ep.Grid = ep.control('ep.Grid', 'epGrid', ep.BaseFrame, nil, {
  controls = {
    button = {constructor = ep.Button, height = 19, minwidth = 19},
    checkbox = {constructor = ep.CheckBox, height = 16, width = 20},
    colorspot = {constructor = ep.ColorSpot, height = 16, width = 16},
    combobox = {constructor = ep.ComboBox, height = 19, minwidth = 19},
    dropbox = {constructor = ep.DropBox, height = 19, minwidth = 19},
    editbox = {constructor = ep.EditBox, height = 19, minwidth = 19},
    iconbox = {constructor = ep.IconBox, height = 38, width = 38},
    spinner = {constructor = ep.Spinner, height = 19, minwidth = 19},
    statusbar = {constructor = ep.StatusBar, height = 19, minwidth = 19}
  },

  initialize = function(self, params)
    params = params or {}
    self.alternated = (params.alternated ~= false)
    self.defaultSort = params.defaultSort
    self.hpadding = params.hpadding or params.padding or 2
    self.offset = 0
    self.resizeToFit = params.resizeToFit
    self.total = 0
    self.unselectable = params.unselectable
    self.vpadding = params.vpadding or params.padding or 1

    if params.header then
      self.headers, self.headersByField = {}, {}
      self.header:Show()
      self.scrollbar:SetPoint('TOPRIGHT', self, 'TOPRIGHT', 0, -32)
    end

    if params.cells then
      self:construct(params.cells)
      self:build()
      if params.data then
        self:load(params.data)
      end
    end
  end,

  --[[
  cell = {
    control = (id of embedded control)
    field = (field name for this cell)
    relwidth = (relative width of this cell)
    sortable = (boolean indicating sortability of this cell)
    width = (absolute width of this cell)

    <generated>
    cheight = (height of embedded control)
    staticwidth = (boolean indicating ...)
    voffset = (vertical offset for this cell)
  }
  ]]

  build = function(self)
    local cells, padding, clearance, space, total, offset, cell, row, point = self.cells
    padding, clearance = self.hpadding * 2, 2 + (self.vpadding * 2)
    if self.header then
      clearance = clearance + 19
    end

    self.rowCount = floor((self:GetHeight() - clearance) / self.rowHeight)
    self.rowWidth = self:GetWidth() - 17
    space = self.rowWidth - self.exactWidth - padding

    total, offset = 0, self.hpadding
    for i = 1, #cells do
      cell = cells[i]
      if cell.relWidth then
        cell.width = floor(space * cell.relWidth)
        total = total + cell.width
      end
      if not cell.staticWidth then
        cell.cwidth = cell.width - padding
      end
      cell.hoffset = offset + self.hpadding
      offset = offset + cell.width
    end

    if total < space then
      cell.width = cell.width + (space - total)
    end

    offset = (self.header and 20 or 1) + self.vpadding
    for i = 1, self.rowCount do
      row = self.rows[i]
      if not row then
        row = ep.GridRow(self.name..'r'..i, self, self, i)
        row:SetPoint('TOPLEFT', self, 'TOPLEFT', 1, -(offset + (self.rowHeight * (i - 1))))
        self.rows[i] = row
      end
      row:Show()
      row.visible = true
      row:layout()
    end

    if self.headers then
      for i = 1, #self.headers do
        self.headers[i]:layout()
      end
    end

    for i = self.rowCount + 1, #self.rows do
      row = self.rows[i]
      row.visible = nil
      row:Hide()
    end

    if self.resizeToFit then
      row = self.rows[self.rowCount]
      point = {row:GetPoint()}
      offset = abs(point[5]) + row:GetHeight() + 3
      if offset < self:GetHeight() then
        self:SetHeight(offset)
      end
    end
  end,

  construct = function(self, cells)
    local hpadding, control, header = self.hpadding * 2
    self.rowHeight, self.exactWidth = 13, 0

    for i, cell in ipairs(cells) do
      if not cell.title then
        cell.unsortable = true
      end

      control = self.controls[cell.control]
      if control then
        cell.control = control
        if control.height then
          cell.cheight = control.height
          self.rowHeight = max(self.rowHeight, control.height)
        end
        if control.width then
          cell.width = control.width + hpadding
          cell.staticwidth = true
        elseif cell.width then
          cell.width = cell.width + hpadding
        end
        if cell.width then
          self.exactWidth = self.exactWidth + cell.width
        end
      else
        cell.control = nil
        if cell.width then
          cell.width = cell.width + hpadding
          self.exactWidth = self.exactWidth + cell.width
        end
      end

      cell.field = cell.field or i
      if self.headers then
        header = ep.GridHeader(self.name..'h'..i, self.header, self, i, cell)
        self.headers[i], self.headersByField[cell.field] = header, header
      end
    end

    for i, cell in ipairs(cells) do
      if cell.cheight then
        cell.voffset = max(0, floor((self.rowHeight - cell.cheight) / 2)) + self.vpadding
      else
        cell.cheight = self.rowHeight
        cell.voffset = self.vpadding
      end
    end

    self.cells = cells
    self.rows = {}
    self.rowHeight = self.rowHeight + (self.vpadding * 2)
  end,

  load = function(self, data)
    self.data = data
    self.total = #self.data
    self:_updateScrollbar()
    self:update(0)
  end,

  resize = function(self)
    self:build()
    self:_updateScrollbar()
    self:update()
  end,

  sort = function(self, field, descending)
    if self.headers then
      if self.currentSort then
        self.headersByField[self.currentSort[1]]:clearSort()
      end
      self.currentSort = {field, descending}
      self.headersByField[field]:setSort(descending)
    end

    fieldsort(self.data, {field, descending}, self.defaultSort)
    self:update()
  end,

  update = function(self, offset)
    offset = floor(offset or self.scrollbar:GetValue())
    if self.scrollbar:GetValue() == offset then
      if self.generator then
        self:_generateData()
        offset = 0
      end
      if self.data then
        for i, row in ipairs(self.rows) do
          if row.visible then
            row.data = self.data[i + offset]
            row:update()
          else
            break
          end
        end
      end
    else
      self.scrollbar:SetValue(offset)
    end
  end,

  _generateData = function(self)
  end,

  _updateScrollbar = function(self)
    self.scrollbar:SetMinMaxValues(0, max(0, self.total - self.rowCount))
  end
})

ep.GridCell = ep.control('ep.GridCell', 'epGridCell', ep.BaseFrame, nil, {
  initialize = function(self, row)
    self.row = row
  end,

  setValue = function(self, value)
    self.text:SetText(value)
  end
})

ep.GridHeader = ep.control('ep.GridHeader', 'epGridHeader', ep.Button, nil, {
  initialize = function(self, grid, id, cell)
    self:RegisterForClicks('LeftButtonUp', 'RightButtonUp')
    self.cell = cell
    self.grid = grid
    self.id = id

    if cell.title then
      self:SetText(cell.title)
    end

    if cell.unsortable then
      self:Disable()
    end
  end,

  clearSort = function(self)
    self.sorting = nil
    self.arrow:Hide()
    self.slightHighlight:Hide()
  end,

  click = function(self, button)
    if button == 'LeftButton' then
      local descending = self.sorting
      if descending ~= nil then
        descending = not descending
      else
        descending = false
      end
      self.grid:sort(self.cell.field, descending)
    else

    end
  end,

  enter = function(self)
  end,

  layout = function(self)
    self:SetWidth(self.cell.width)
    self:SetPoint('TOPLEFT', self:GetParent(), 'TOPLEFT', self.cell.hoffset, 0)
  end,

  leave = function(self)
  end,

  setSort = function(self, descending)
    self.sorting = descending
    if descending then
      self.arrow:SetTexture('Interface\\AddOns\\ephemeral\\textures\\arrow-down')
    else
      self.arrow:SetTexture('Interface\\AddOns\\ephemeral\\textures\\arrow-up')
    end
    self.arrow:Show()
    self.slightHighlight:Show()
  end
})

ep.GridRow = ep.control('ep.GridRow', 'epGridRow', ep.BaseFrame, nil, {
  initialize = function(self, grid, id)
    local instance, cellName, constructor
    self.grid = grid
    self.id = id
    self.cells = {}

    for i, cell in ipairs(grid.cells) do
      cellName = self.name..'c'..i
      if cell.control then
        constructor = cell.control.constructor
        if constructor.forGrid then
          instance = constructor:forGrid(cellName, self, cell)
        else
          instance = constructor(cellName, self)
        end
        instance.row = row
      else
        instance = ep.GridCell(cellName, self, self)
      end
      instance.cell = cell
      self.cells[i] = instance
    end

    if grid.alternated and band(id, 1) ~= 1 then
      self.diff:Show()
    end
    self:SetHeight(grid.rowHeight)
  end,

  enter = function(self)
    self.highlight:Show()
  end,

  layout = function(self)
    self:SetWidth(self.grid.rowWidth)
    for i, instance in ipairs(self.cells) do
      if instance.cell.cwidth then
        instance:SetWidth(instance.cell.cwidth)
      end
      if instance.cell.cheight then
        instance:SetHeight(instance.cell.cheight)
      end
      instance:SetPoint('TOPLEFT', self, 'TOPLEFT', instance.cell.hoffset, -instance.cell.voffset)
    end
  end,

  leave = function(self)
    self.highlight:Hide()
  end,

  manipulate = function(self, button)
  end,

  update = function(self)
    if self.data then
      for i, instance in ipairs(self.cells) do
        if instance.cell.field then
          instance:setValue(self.data[instance.cell.field])
        end
      end
      self:Show()
    else
      self:Hide()
    end
  end
})

ep.IconBox = ep.control('ep.IconBox', 'epIconBox', ep.Button, nil, {
  initialize = function(self, params)
    params = params or {}
    if params.static then
      self:disable()
    end
    if params.default then
      self:setValue(default)
    end

    self.anchor = params.anchor or self
    self.enableBrowsing = params.enableBrowsing

    if params.onValueChanged then
      self:subscribe(':valueChanged', params.onValueChanged)
    end

    if params.tooltip then
      attachTooltip(self, params.tooltip, {delay=1,
        location={anchor=self, edge='BOTTOMLEFT', hook='TOPLEFT', x=-5}})
    end

    self:child('T'):SetGradientAlpha('vertical', 1, 1, 1, 0.2, 1, 1, 1, 1)
    self:child('B'):SetGradientAlpha('vertical', 1, 1, 1, 1, 1, 1, 1, 0.2)
    self:child('L'):SetGradientAlpha('horizontal', 1, 1, 1, 1, 1, 1, 1, 0.2)
    self:child('R'):SetGradientAlpha('horizontal', 1, 1, 1, 0.2, 1, 1, 1, 1)
    self.texture:SetVertexColor(1.0, 1.0, 1.0, 0.9)
  end,

  browse = function(self)
    if self.enableBrowsing then
      epIconBrowser:display({self.setValue, self}, self.anchor)
    end
  end,

  desaturate = function(self, desaturated)
    if not self.texture:SetDesaturated(desaturated) then
      if desaturated then
        self.texture:SetVertexColor(0.5, 0.5, 0.5, 0.9)
      else
        self.texture:SetVertexColor(1.0, 1.0, 1.0, 0.9)
      end
    end
    return self
  end,

  disable = function(self, shaded)
    self:Disable()
    if shaded then
      self:SetAlpha(0.6)
    end
    return self
  end,

  enable = function(self)
    self:Enable()
    self:SetAlpha(1.0)
    return self
  end,

  getValue = function(self)
    return self.icon
  end,

  setValue = function(self, icon, suppressEvent)
    if icon == self.icon then
      return self
    end

    self.icon = icon
    if icon then
      self.texture:SetTexture(ep.icon(icon))
    else
      self.texture:SetTexture('')
    end

    if not suppressEvent then
      self:event(':valueChanged', icon)
    end
    return self
  end
})

ep.ListBuilder = ep.control('ep.ListBuilder', 'epListBuilder', ep.BaseFrame, nil, {
  initialize = function(self, params)
    params = params or {}
    self.buttons = {}
    self.defaultColor = Color(params.defaultColor or 'label')
    self.entries = {}
    self.formatter = params.formatter
    self.placeholder = params.placeholder
    self.sorter = params.sorter or attrsort(1)
    self.supportColor = params.supportColor
    self.tooltipGenerator = params.tooltipGenerator
    self.validator = params.validator

    if self.placeholder then
      self.placeholderLabel:SetText(self.placeholder)
      if not params.entries then
        self.placeholderLabel:Show()
      end
    end

    if params.entries then
      self:setValue(params.entries)
    end

    if params.onValueChanged then
      self:subscribe(':valueChanged', params.onValueChanged)
    end

    if params.tooltip then
      attachTooltip(self, params.tooltip, {delay=1,
        location={anchor=self, edge='BOTTOMLEFT', hook='TOPLEFT', x=-5}})
    end

    if self.label then
      self.label:SetText(_(self.label:GetText()))
    end

    self.editor.text:subscribe('OnEnterPressed', {self.submit, self})
  end,

  addEntry = function(self, entry, skipUpdate)
    if not entry[2] then
      entry[2] = self.defaultColor
    end

    entry = self:_prepareEntry(entry)
    if exceptional(entry) then
      return entry
    end

    self:_addIfUnique(entry, true)
    if not skipUpdate then
      self:update()
    end
    return entry
  end,

  close = function(self)
    if self.currentEntry then
      self.buttons[self.currentEntry[2]]:UnlockHighlight()
      self.currentEntry = nil
    end

    self.editor:Hide()
    self.editing = nil
  end,

  delete = function(self)
    local entry = self.currentEntry
    if entry then
      tremove(self.entries, entry[2])
      self:update()
    end
    self:close()
  end,

  edit = function(self, entry, index)
    if self.editing then
      if self.currentEntry and self.currentEntry ~= entry then
        self.buttons[self.currentEntry[2]]:UnlockHighlight()
      elseif not entry then
        self:close()
        return
      end
    end

    if entry then
      self.editor.text:setValue(entry[1])
      if entry[2] then
        self.editor.color:setValue(entry[2])
      end
      self.currentEntry = {entry, index}
      self.buttons[index]:LockHighlight()
    else
      self.editor.text:setValue('')
    end

    self.editor:SetWidth(self:GetWidth())
    self.editor:Show()
    self.editor.text:SetFocus()
    self.editing = true
  end,

  getTooltip = function(self, entry)
    if self.tooltipGenerator then
      return self.tooltipGenerator(entry)
    end
  end,

  getValue = function(self)
    return self.entries
  end,

  setValue = function(self, entries)
    self.entries = {}
    for i, entry in ipairs(entries) do
      entry = self:addEntry(entry, true)
      if exceptional(entry) then
        return entry
      end
    end

    self:update()
    return self
  end,

  submit = function(self)
    local value = self.editor.text:getValue()
    if value == nil or #strip(value) == 0 then
      self:close()
      return
    end

    local entry = self:_prepareEntry({value, self.editor.color:getValue()})
    if exceptional(entry) then
      -- handle this
      return
    end

    if self.currentEntry then
      local currentEntry, currentIndex = unpack(self.currentEntry)
      if entry[1] ~= currentEntry[1] or entry[2] ~= currentEntry[2] then
        tremove(self.entries, currentIndex)
        self:_addIfUnique(entry, true)
        self:update()
      end
    else
      self:_addIfUnique(entry, true)
      self:update()
    end
    self:close()
  end,

  update = function(self)
    table.sort(self.entries, self.sorter)
    if self.placeholder then
      if #self.entries > 0 then
        self.placeholderLabel:Hide()
      else
        self.placeholderLabel:Show()
      end
    end

    local width, x, y, bw = self:GetWidth() - 24, 4, -4 
    for i, entry in ipairs(self.entries) do
      local button = self.buttons[i]
      if not button then
        button = ep.ListBuilderButton(self.name..'Entry'..i, self, self, i)
        self.buttons[i] = button
      end
    
      if button.entry ~= entry then
        button:update(entry)
      end
      button:Show()

      bw = button:GetWidth()
      if (x + bw) > width then
        x, y = 4, y - 20
      end

      button:SetPoint('TOPLEFT', self, 'TOPLEFT', x, y)
      x = x + bw + 3
    end
    self:SetHeight(math.abs(y) + 21)

    local idx = #self.entries + 1
    while true do
      button = self.buttons[idx]
      if button then
        button:update(nil)
        button:Hide()
        idx = idx + 1
      else
        break
      end
    end
  end,

  _addIfUnique = function(self, entry, updateColor)
    for i, existing in ipairs(self.entries) do
      if entry[1] == existing[1] then
        if updateColor then
          existing[2] = entry[2]
        end
        return
      end
    end
    tinsert(self.entries, entry)
  end,

  _prepareEntry = function(self, entry)
    if self.formatter then
      entry = self.formatter(entry)
    end

    if self.validator then
      local failure = self.validator(entry)
      if exceptional(failure) then
        return failure
      end
    end
    return entry
  end
})

ep.ListBuilderButton = ep.control('ep.ListBuilderButton', 'epListBuilderButton', ep.Button, nil, {
  initialize = function(self, frame, id)
    self.entry = nil
    self.font = self:GetNormalFontObject()
    self.frame = frame
    self.id = id
    self:setBorderColors(1, 1, 1, 0.5)
  end,

  edit = function(self)
    self.frame:edit(self.entry, self.id)
  end,

  enter = function(self)
    local tooltip = self.tooltip
    if not tooltip then
      tooltip = self.frame:getTooltip(self.entry)
      if tooltip then
        tooltip.location = {anchor=self, edge='BOTTOMLEFT', hook='TOPLEFT', x=-5}
        self.tooltip = tooltip
      end
    end
    if tooltip then
      epTooltip:display(tooltip)
    end
  end,

  leave = function(self)
    epTooltip:hide()
  end,

  update = function(self, entry)
    self.entry = entry
    self.tooltip = nil

    if self.entry then
      self:SetText(self.entry[1])
      if self.entry[2] then
        Color:setTextColor(self.font, self.entry[2])
      else
        Color:setTextColor(self.font, self.frame.defaultColor)
      end
      self:SetWidth(self:GetTextWidth() + 11)
    else
      self:SetText('')
    end
  end
})

ep.Menu = ep.control('ep.Menu', 'epMenu', ep.BaseFrame, nil, {
  menus = {},

  initialize = function(self, params)
    params = params or {}
    self.buttons = {}
    self.callback = params.callback
    self.defaultColor = Color(params.defaultColor or 'label')
    self.items = params.items
    self.generator = params.generator
    self.location = params.location
    self.offset = 0
    self.width = params.width or 0
    self.window = params.window or 0

    self.scrollbar = false
    if params.scrollable then
      self.scrollbar = ep.VerticalScrollBar(self.name..'ScrollBar', self, {self.scroll, self})
      self.scrollbar:SetPoint('TOPRIGHT', self, 'TOPRIGHT', 0, -13)
      self.scrollbar:SetPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', 0, 13)
    end
  end,

  build = function(self)
    local items, buttons, target, button, scrolled = #self.items, #self.buttons
    if items == 0 then
      self.built = false
      return
    elseif items < buttons then
      for i = items + 1, buttons do
        self.buttons[i]:Hide()
      end
      if self.scrollbar then
        self.scrollbar:Hide()
      end
    elseif items > buttons then
      target = (self.scrollbar) and min(self.window, items) or items
      for i = buttons + 1, target do
        button = ep.MenuButton(self.name..i, self, self, i)
        button:SetPoint('TOPLEFT', self, 'TOPLEFT', 5, -(4 + (13 * (i - 1))))
        self.buttons[i] = button
      end
      if self.scrollbar then
        if items > #self.buttons then
          self.scrollbar:SetMinMaxValues(0, items - self.window)
          self.scrollbar:Show()
        else
          self.scrollbar:Hide()
        end
      end
    end
    scrolled = (self.scrollbar and self.scrollbar:IsShown())

    local model, haschecks, hasarrows, hasspots, widest = self.buttons[1], false, false, false, 0
    for i, item in ipairs(self.items) do
      if item.items then
        hasarrows = true
      end
      if item.checkable then
        haschecks = true
      end
      if item.spot then
        hasspots = true
      end
      model:SetText(item.label)
      widest = max(widest, model:GetTextWidth() + 1)
    end

    local iwidth = self.width
    if type(iwidth) == 'table' then
      iwidth = self.width:GetWidth()
    end

    local padding, offset, width = max(0, iwidth - (widest + 10)), 0, max(iwidth - 10, widest)
    if haschecks then
      offset, padding = 15, padding - 15
      if padding < 0 then
        width = width + abs(padding)
        padding = 0
      end
    end

    if hasspots then
      offset, padding = offset + 15, padding - 15
      if padding < 0 then
        width = width + abs(padding)
        padding = 0
      end
    end

    if hasarrows then
      padding = padding - 6
      if padding < 0 then
        width = width + abs(padding)
        padding = 0
      end
    end

    if scrolled and (width - 15) >= widest then
      width = width - 15
    end

    local buttons, text = 0
    for i, button in ipairs(self.buttons) do
      text = button:child('Text')
      if button:IsShown() then
        button:SetWidth(width)
        text:ClearAllPoints()
        text:SetPoint('TOPLEFT', button, 'TOPLEFT', offset, 1)
        buttons = buttons + 1
      else
        break
      end
    end

    self:SetHeight((buttons * 13) + 8)
    if scrolled and (width - 15) >= widest then
      width = width + 15
    end

    self:SetWidth(width + 10)
    self.built = true
  end,

  close = function(self)
    local target
    if self.depth then
      for i = #self.menus, self.depth, -1 do
        target = tremove(self.menus, i)
        target.depth = nil
        target:Hide()
      end
    end
  end,

  closeAll = function(self)
    if #self.menus >= 1 then
      self.menus[1]:close()
    end
  end,

  display = function(self, location)
    location = location or self.location
    if not self.built then
      if self.generator then
        self.items = self.generator(self)
      end
      self:build()
      if not self.built then
        return
      end
    elseif type(self.width) == 'table' then
      if not self.savedWidth or self.savedWidth ~= self.width:GetWidth() then
        self:build()
        if not self.built then
          return
        end
      end
    end

    if self.scrollbar and self.scrollbar:IsShown() then
      self.scrollbar:SetValue(0)
    end

    local menuCount = #self.menus
    if self.ancestor then
      if menuCount > self.ancestor.depth then
        self.menus[self.ancestor.depth + 1]:close()
      end
    elseif menuCount > 0 then
      self.menus[1]:close()
    end

    self.menus[#self.menus + 1] = self
    self.anchor = location.anchor
    self.depth = #self.menus

    self:update()
    if not location.static then
      self:position(location, {edge = 'TOPLEFT', hook = 'TOPLEFT'})
    end
    self:Show()
  end,

  populate = function(self, items)
    self.items, self.built = items, false
  end,

  scroll = function(self, offset)
    self.offset = offset
    self:update()
  end,

  toggle = function(self, location)
    location = location or self.location
    if self:IsShown() and self.anchor == location.anchor then
      self:close()
    else
      self:display(location)
    end
  end,

  update = function(self)
    for i, button in ipairs(self.buttons) do
      button.item = self.items[i + self.offset]
      if button.item then
        button:update()
      else
        break
      end
    end
  end
})

ep.MenuButton = ep.control('ep.MenuButton', 'epMenuButton', ep.Button, nil, {
  initialize = function(self, frame, id)
    self.arrow, self.checkbox, self.highlight = self:children('Arrow', 'Check', 'Highlight')
    self.font = self:GetNormalFontObject()
    self.frame = frame
    self.id = id
  end,

  activate = function(self)
    local responder, ancestor
    if not self.item.submenu then
      responder = self.item.callback or self.frame.callback
      if not responder and self.frame.depth > 1 then
        for i = self.frame.depth - 1, 1, -1 do
          ancestor = self.frame.menus[i]
          if ancestor.callback then
            responder = ancestor.callback
            break
          end
        end
      end
      if self.item.checkable then
        self.item.checked = not self.item.checked
        if responder then
          invoke(responder, self.item.value or self.item.label, self.item)
        end
        self:check(self.item.checked)
      elseif self.item.spot then

      else
        self.frame.menus[1]:close()
        if responder then
          invoke(responder, self.item.value or self.item.label, self.item)
        end
      end
    end
  end,

  check = function(self, checked)
    local texture = (checked) and 'box-check' or 'box-empty'
    self.checkbox:SetTexture('Interface\\AddOns\\ephemeral\\textures\\'..texture)
  end,

  enter = function(self)
    self.highlight:Show()
    if self.item.submenu then
      self.arrow:SetTexture('Interface\\AddOns\\ephemeral\\textures\\arrow-right-highlight')
      if not self.item.submenu.ancestor then
        self.item.submenu = ep.Menu(self.frame.name..self.item.label..'Menu', self.frame, self.item.submenu)
        self.item.submenu.ancestor = self.frame
      end
      self.item.submenu:display({anchor = self, x = self:GetWidth() + 5, y = 4})
    else
      if #self.frame.menus > self.frame.depth then
        self.frame.menus[self.frame.depth + 1]:close()
      end
      if self.item.tooltip then
        self.item.tooltip.location = {anchor=self, hook='TOPRIGHT', x=5, y=8}
        epTooltip:display(self.item.tooltip)
      end
    end
  end,

  leave = function(self)
    self.highlight:Hide()
    if self.item.submenu then
      self.arrow:SetTexture('Interface\\AddOns\\ephemeral\\textures\\arrow-right')
    elseif self.item.tooltip then
      epTooltip:hide(self)
    end
  end,

  update = function(self)
    if self.item then
      self:SetText(self.item.label)
      if self.item.color then
        Color:setTextColor(self.font, self.item.color)
      else
        Color:setTextColor(self.font, self.frame.defaultColor)
      end

      if self.item.checkable then
        self.checkbox:Show()
        self:check(self.item.checked)
      else
        self.checkbox:Hide()
      end

      if self.item.submenu then
        self.arrow:Show()
      else
        self.arrow:Hide()
      end

      if self.item.disabled then
        self:disable()
      else
        self:enable()
      end
      self:Show()
    else
      self:Hide()
    end
  end
})

ep.MessageFrame = ep.control('ep.MessageFrame', 'epMessageFrame', ep.BaseControl, 'messageframe', {
  initialize = function(self, params)
    self.range = 0
    if params and params.defaultColor then
      self.defaultColor = Color(params.color):toNative()
    else
      self.defaultColor = Color('standard'):toNative()
    end
  end,

  append = function(self, text, color, id)
    if color then
      color = Color(color):toNative()
    else
      color = self.defaultColor
    end
    self.messages:AddMessage(text, color[1], color[2], color[3], id)

    self.range = self.messages:GetNumMessages() - 1
    self.scrollbar:SetMinMaxValues(0, self.range)
    self.scrollbar:SetValue(self.range)
  end,

  scroll = function(self, offset)
    self.messages:SetScrollOffset(self.range - offset)
  end,

  setFontObject = function(self, font)
    self.messages:SetFontObject(font)
  end
})

ep.MultiButton = ep.control('ep.MultiButton', 'epMultiButton', ep.BaseControl, 'button', {
  initialize = function(self, params)
    local text = self:GetText()
    if text then
      self:SetText(_(text))
    end

    params = params or {}
    self.menu = ep.Menu(self.name..'Menu', self, {
      items = params.items,
      location = {anchor = self, x = 0, y = -18},
      window = params.window or 8,
      width = self,
    })

    if params.tooltip then
      attachTooltip(self, params.tooltip, {delay=1,
        location={anchor=self, edge='BOTTOMLEFT', hook='TOPLEFT', x=-5}})
    end
  end,

  disable = function(self)
    self:SetAlpha(0.6)
    self:Disable()

    self.opener:SetAlpha(0.6)
    self.opener:Disable()
    return self
  end,

  enable = function(self)
    self:SetAlpha(1.0)
    self:Enable()

    self.opener:SetAlpha(1.0)
    self.opener:Enable()
    return self
  end,

  open = function(self)
    self.menu:toggle()
  end,
})

ep.MultiFrame = ep.control('ep.MultiFrame', 'epMultiFrame', ep.BaseFrame, nil, {
  initialize = function(self, params)
    params = params or {}
    self.frames = nil
    self.selectedFrame = nil

    if params.frames then
      self:populate(params.frames)
      if params.defaultFrame then
        self:select(params.defaultFrame)
      end
    end

    if params.onSelectionChanged then
      self:subscribe(':selectionChanged', params.onSelectionChanged)
    end
  end,

  populate = function(self, frames)
    for name, frame in pairs(frames) do
      if type(frame.client) == 'string' then
        frame.client = self:child(frame.client)
      end
    end
    self.frames = frames
  end,
  
  select = function(self, name)
    if self.frames[name] then
      if self.selectedFrame then
        if self.selectedFrame ~= name then
          self.frames[self.selectedFrame].client:Hide()
        else
          return
        end
      end
      self.frames[name].client:Show()
      self.selectedFrame = name
    else
      return exception('UnknownFrame')
    end
  end
})

ep.ScrollFrame = ep.control('ep.ScrollFrame', 'epScrollFrame', ep.BaseControl, 'scrollframe', {
  initialize = function(self, params)
    self.hideable = params.hideable or false
    self.managed = params.managed or false
    self.resizable = params.resizable or false
    self.childFrame = self:GetScrollChild()
  end,

  scroll = function(self, value)
    local min, max = self.scrollbar:GetMinMaxValues()
    if value > max then
      self.scrollbar:SetMinMaxValues(min, value)
    end

    self.scrollbar:SetValue(value)
    return self
  end,

  update = function(self, xrange, yrange)
    local yoffset, yrange = self.scrollbar:GetValue(), yrange or self:GetVerticalScrollRange()
    if yoffset > yrange then
      yoffset = yrange
    end

    self.scrollbar:SetMinMaxValues(0, yrange)
    self.scrollbar:SetValue(yoffset)

    if floor(yrange) == 0 then
      if self.hideable then
        self.scrollbar:Hide()
        if self.resizable then
          self.childFrame:SetWidth(self.childFrame:GetWidth() + 20)
        end
      end
    else
      if self.hideable then
        if self.resizable then
          self.childFrame:SetWidth(self.childFrame:GetWidth() - 20)
        end
        self.scrollbar:Show()
      end
    end
  end,

  updateScroll = function(self, value)
    self:SetVerticalScroll(value)
  end
})

ep.Slider = ep.control('ep.Slider', 'epSlider', ep.BaseControl, 'slider', {
  initialize = function(self, params)
    params = params or {}
    self.multiplier = params.multiplier
    self.window = params.window

    local min, max = self:GetMinMaxValues()
    if floor(self:GetValueStep()) == 0 then
      self:SetValueStep(1)
    end

    if type(self:GetValue()) ~= 'number' then
      self:SetValue(min)
    end

    self:update(min or 0)
    self.callback = params.callback
  end,

  move = function(self, direction, absolute)
    local min, max, value = self:GetMinMaxValues()
    if absolute then
      value = (direction > 0) and max or min
    else
      if self.window then
        value = self:GetValue() + (self.window * direction)
      elseif self.multiplier then
        value = self:GetValue() + (max * self.multiplier * direction)
      else
        value = self:GetValue() + (self:GetValueStep() * direction)
      end
    end
    self:SetValue(value)
  end,

  update = function(self, value)
    local min, max = self:GetMinMaxValues()
    if value <= min then
      self.less:Disable()
    else
      self.less:Enable()
    end

    if value >= max then
      self.more:Disable()
    else
      self.more:Enable()
    end

    if self.callback then
      invoke(self.callback, value, self)
    end
  end
})

ep.Spinner = ep.control('ep.Spinner', 'epSpinner', ep.EditBox, nil, {
  initialize = function(self, params)
    params = params or {}
    if params.values then
      self.circular = params.circular
      self.value = params.value
      self.values = params.values
      if self.value then
        self:setValue(self.value)
      else
        self.offset = 1
        self.value = self.values[1]
        self:update()
      end
    else
      self.bounded = params.bounded
      self.formatter = params.formatter
      self.maximum = params.maximum
      self.minimum = params.minimum
      self.precision = params.precision
      self.step = params.step or 1
      self.validator = params.validator
      self:setValue(params.value or 0)
    end

    self.static = params.static
    if self.static then
      self:EnableKeyboard(false)
      self:EnableMouse(false)
    end

    if params.onValueChanged then
      self:subscribe(':valueChanged', params.onValueChanged)
    end

    if params.tooltip then
      attachTooltip(self, params.tooltip, {delay=1,
        location={anchor=self, edge='BOTTOMLEFT', hook='TOPLEFT', x=-5}})
    end

    if self.label then
      self.label:SetText(_(self.label:GetText()))
    end
  end,

  disable = function(self, cleared)
    self:ClearFocus()
    if cleared then
      self:SetText('')
    end
    self:SetAlpha(0.6)

    self:EnableMouseWheel(false)
    if not self.static then
      self:EnableKeyboard(false)
      self:EnableMouse(false)
    end

    self.less:Disable()
    self.less:EnableMouseWheel(false)

    self.more:Disable()
    self.more:EnableMouseWheel(false)
    return self
  end,

  enable = function(self, value)
    self:SetAlpha(1.0)
    if value then
      self:setValue(value)
    else
      self:update()
    end

    self:EnableMouseWheel(true)
    if not self.static then
      self:EnableKeyboard(true)
      self:EnableMouse(true)
    end

    self.less:Enable()
    self.less:EnableMouseWheel(true)

    self.more:Enable()
    self.more:EnableMouseWheel(true)
    return self
  end,

  getValue = function(self)
    return self.value
  end,

  setValue = function(self, value, suppressEvent)
    self:ClearFocus()
    if self.values then
      local offset = tindex(self.values, value)
      if offset and offset ~= self.offset then
        self.offset = offset
      else
        return self
      end
    else
      value = tonumber(value)
      if type(value) ~= 'number' then
        return self
      elseif self.minimum and value < self.minimum then
        value = self.minimum
      elseif self.maximum and value > self.maximum then
        value = self.maximum
      elseif self.bounded then
        value = self.minimum + (floor((value - self.minimum) / self.step) * self.step)
      end
      if value == self.value then
        return self
      end
    end

    self.value = value
    if not suppressEvent then
      self:event(':valueChanged', value)
    end

    self:update()
    return self
  end,

  spin = function(self, direction, absolute)
    if self.values then
      local count, offset = #self.values, self.offset
      if absolute then
        offset = (direction < 0) and count or 1
      else
        offset = offset - direction
        if offset < 1 then
          offset = (self.circular) and count or 1
        elseif offset > count then
          offset = (self.circular) and 1 or count
        end
      end
      if offset ~= self.offset then
        self.offset = offset
        self.value = self.values[offset]
      else
        return self
      end
    else
      local value
      if absolute then
        value = (direction < 0) and (self.minimum or 0) or (self.maximum or 0)
      else
        value = self.value + (self.step * direction)
        if self.minimum and value < self.minimum then
          value = self.minimum
        elseif self.maximum and value > self.maximum then
          value = self.maximum
        end
      end
      if value ~= self.value then
        self.value = value
      else
        return self
      end
    end

    self:event(':valueChanged', self.value)
    self:update()
    return self
  end,

  update = function(self)
    if self.formatter then
      self:SetText(invoke(self.formatter, self.value, self))
    elseif self.precision then
      self:SetText(format('%0.0'..self.precision..'f', self.value))
    else
      self:SetText(tostring(self.value))
    end
  end
})

ep.TabButton = ep.control('ep.TabButton', 'epTabButton', ep.Button, nil, {
  initialize = function(self, id, frame)
    self.background = self:child('Background')
    self.border = self:child('Border')
    self.frame = frame
    self.id = id
    self.bottomBorder:SetVertexColor(1, 1, 1, 0.5)
  end,

  toggle = function(self, active)
    if active then
      self.background:Show()
      self:SetNormalFontObject(epTitleFont)
      self:Disable()
      if self.frame.showBottomBorder then
        self.bottomBorder:Show()
      end
    else
      self.background:Hide()
      self:SetNormalFontObject(epLabelFont)
      self:Enable()
      if self.frame.showBottomBorder then
        self.bottomBorder:Hide()
      end
    end
  end
})

ep.TabbedFrame = ep.control('ep.TabbedFrame', 'epTabbedFrame', ep.BaseFrame, nil, {
  initialize = function(self, params)
    params = params or {}
    self.callback = params.callback
    self.showBottomBorder = params.showBottomBorder
    self.sorted = params.sorted

    self.items = {}
    self.tab = 0
    self.tabs = {}

    if type(params.tabs) == 'table' then
      self:populate(params.tabs)
      if #self.items >= 1 then
        self:select(1)
      end
    end
  end,

  add = function(self, item, offset)
    if type(item) ~= 'table' then
      item = {label = item}
    end

    if item.client and type(item.client) == 'string' then
      item.client = self:child(item.client)
    end

    if offset and offset >= 1 and offset <= #self.items then
      tinsert(self.items, offset, item)
      if self.tab >= offset then
        self.tab = self.tab + 1
      end
    else
      tinsert(self.items, item)
    end

    self:build()
    return self
  end,

  build = function(self)
    local items, tabs, offset, index, tab, border = #self.items, #self.tabs
    if items > tabs then
      for i = tabs + 1, items do
        self.tabs[i] = ep.TabButton(self.name..i, self, i, self)
      end
    end

    if self.sorted then
      sort(self.items, self.sort)
    end

    offset, index = 1, 1
    for i, item in ipairs(self.items) do
      if not item.hidden then
        tab = self.tabs[index]
        tab.index = i
        tab:SetText(item.label)
        tab:SetWidth((tab:GetTextWidth() * 1.03) + 18)

        if item.tooltip then
          attachTooltip(tab, item.tooltip, {delay=1,
            location={anchor=tab, edge='BOTTOMLEFT', hook='TOPLEFT', x=-5}})
        else
          detachTooltip(tab)
        end

        if item.disabled then
          tab:disable()
        else
          tab:enable()
        end

        tab:SetPoint('TOPLEFT', self, 'TOPLEFT', offset, 0)
        tab:Show()
        offset = offset + tab:GetWidth() + 1
        index = index + 1
      end
    end

    if index <= tabs then
      for i = index, tabs do
        self.tabs[i]:Hide()
      end
    end

    self.tf_tr:SetPoint('TOPRIGHT', self, 'TOPLEFT', offset + 6, 6)
    self:select(self.tab, true)
  end,

  identify = function(self, value)
    local id = value
    if type(value) == 'string' then
      for i, item in ipairs(self.items) do
        if value == item.label then
          id = i
          break
        end
      end
    end

    if type(id) == 'number' and id >= 1 and id <= #self.items then
      return id
    end
  end,

  modify = function(self, offset, item)
    if type(item) ~= 'table' then
      item = {label = item}
    end

    if item.client and type(item.client) == 'string' then
      item.client = _G[item.client]
    end

    if offset >= 1 and offset <= #self.items then
      tupdate(self.items[offset], item)
      self:build()
    end
    return self
  end,

  populate = function(self, items)
    local item
    for i = 1, #items do
      item = items[i]
      if type(item) ~= 'table' then
        items[i] = {label = item}
        item = items[i]
      end
      if item.client and type(item.client) == 'string' then
        item.client = self:child(item.client)
      end
    end

    self.items, self.tab = items, 0
    self:build()
    return self
  end,

  remove = function(self, id)
    id = self:identify(id)
    if type(id) == 'number' then
      tremove(self.items, id)
      if self.tab > id then
        self.tab = self.tab - 1
      elseif self.tab == id then
        self.tab = 1
      end
      self:build()
    end
    return self
  end,

  select = function(self, id, silent)
    local id, tabcount, tab = self:identify(id), #self.tabs
    if type(id) ~= 'number' or id == self.tab or self.items[id].disabled then
      return
    end

    if self.tab > 0 then
      tab = self.tabs[self.tab]
      if self.items[tab.index].client then
        self.items[tab.index].client:Hide()
      end
      tab:toggle(false)
    end

    tab = self.tabs[id]
    if self.items[tab.index].client then
      self.items[tab.index].client:Show()
    end
    tab:toggle(true)

    self.tf_rc:SetPoint('TOPRIGHT', tab, 'BOTTOMRIGHT', 6, 6)
    if id == tabcount then
      self.tf_side:Hide()
      self.tf_rc_v:SetPoint('TOPRIGHT', self.tf_rc, 'TOPRIGHT', 1, 9)
    else
      self.tf_side:Show()
      self.tf_rc_v:SetPoint('TOPRIGHT', self.tf_rc, 'TOPRIGHT', 1, 14)
    end

    if id > 1 then
      self.tf_lc:SetPoint('TOPLEFT', tab, 'BOTTOMLEFT', -6, 6)
      self.tf_lc:Show()
      self.tf_lc_h:Show()
      self.tf_lc_v:Show()
    else
      self.tf_lc:Hide()
      self.tf_lc_h:Hide()
      self.tf_lc_v:Hide()
    end

    for i = 1, tabcount do
      tab = self.tabs[i]
      if (id - 1 >= 2) or (i > id and i < tabcount) then
        tab.border:Show()
      else
        tab.border:Hide()
      end
    end

    self.tab = id
    if self.callback and not silent then
      invoke(self.callback, self.tabs[id], id)
    end
    return self
  end
})

ep.testitems = {
  {label='alpha'},
  {label='beta', items={
    {label='one', items={
      {label='jordan'}}},
    {label='two'},
    {label='three'}}},
  {label='gamma', items={
    {label='four'},
    {label='five'}}},
  {label='delta'},
  {label='eplison'},
  {label='iota'},
  {label='mu'},
  {label='nothing'}
}

ep.Tree = ep.control('ep.Tree', 'epTree', ep.BaseFrame, nil, {
  initialize = function(self, params)
    params = params or {}
    self.buttonHeight = params.buttonHeight or 16
    self.defaultExpansion = params.defaultExpansion or 0
    self.expandOnSelect = params.expandOnSelect
    self.flat = params.flat
    self.noDefaultSelection = params.noDefaultSelection
    self.resizeToFit = params.resizeToFit
    self.title = params.title
    self.tooltipDelay = params.tooltipDelay or 1

    self.buttons = {}
    self.buttonCount = 0
    self.buttonWidth = 0
    self.offset = 0
    self.scrolling = false
    self.selection = nil
    self.sequence = {}

    if self.title then
      self.titleString:SetText(self.title)
      self.titleString:Show()
      self.titleDivider:SetVertexColor(1, 1, 1, 0.5)
      self.titleDivider:Show()
    end

    self:constructButtons()
    if params.items then
      self:populate(params.items)
    else
      self:update()
    end

    if params.onSelectionChanged then
      self:subscribe(':selectionChanged', params.onSelectionChanged)
    end
  end,

  constructButtons = function(self)
    local initialOffset = 4
    if self.title then
      initialOffset = initialOffset + 25
    end

    self.buttonCount = floor((self:GetHeight() - 8) / self.buttonHeight)
    for i = 1, self.buttonCount do
      local button = self.buttons[i]
      if button then
        button:Show()
      else
        button = ep.TreeButton(self.name..'b'..i, self, self, i)
        button:SetPoint('TOPLEFT', self, 'TOPLEFT', 5,
          -(initialOffset + (self.buttonHeight * (i - 1))))
        self.buttons[i] = button
      end
    end
    for i = self.buttonCount + 1, #self.buttons do
      self.buttons[i]:Hide()
    end
  end,

  close = function(self, idx)
    local node, candidate = self.sequence[idx]
    if node and node.item.items and node.open then
      node.open, idx = nil, idx + 1
      while true do
        candidate = self.sequence[idx]
        if candidate and candidate.indent > node.indent then
          if candidate == self.selection then
            self.selection = node
          end
          tremove(self.sequence, idx)
        else
          break
        end
      end
      for i = idx, #self.sequence do
        self.sequence[i].idx = i
      end
    end
    self:update()
  end,

  disable = function(self, deselect)
  end,

  enable = function(self, selection)
  end,

  open = function(self, idx)
    local node = self.sequence[idx]
    if node and node.item.items and not node.open then
      node.open = true
      for i, item in ipairs(node.item.items) do
        idx = idx + 1
        tinsert(self.sequence, idx, {
          item=item, idx=idx, indent=(node.indent + 1)
        })
      end
      for i = idx + 1, #self.sequence do
        self.sequence[i].idx = i
      end
    end
    self:update()
  end,

  populate = function(self, items, expansion)
    local stack, level, item, node, idx
    expansion = expansion or self.defaultExpansion

    self.items = items
    self.sequence = {}
    self.selection = nil

    stack, idx = {{items=items, idx=1}}, 1
    while true do
      item = stack[1].items[stack[1].idx]
      stack[1].idx = stack[1].idx + 1
      if item then
        node = {item=item, idx=idx, indent=#stack - 1}
        if item.selected or (idx == 1 and not self.noDefaultSelection) then
          self.selection = node
        end
        if not self.flat and item.items and node.indent + 1 <= expansion then
          node.open = true
          tinsert(stack, 1, {items=item.items, idx=1})
        end
        tinsert(self.sequence, node)
        idx = idx + 1
      else
        tremove(stack, 1)
        if #stack == 0 then
          break
        end
      end
    end

    self:update()
    return self
  end,

  resize = function(self)
    self:constructButtons()
    if self.sequence then
      self:update()
    end
  end,

  selectNode = function(self, idx, suppressEvent)
    local node = self.sequence[idx]
    if not node or node == self.selection then
      return self
    end

    self.selection = node
    if self.expandOnSelect then
      self:open(node, idx)
    end

    if not suppressEvent then
      self:event(':selectionChanged', node)
    end
    
    self:update()
    return self
  end,

  update = function(self, offset)
    self:_updateScrollbar()
    if self.scrolling then
      offset = floor(offset or self.scrollbar:GetValue())
      if self.scrollbar:GetValue() == offset then
        self.offset = offset
        self.buttonWidth = self:GetWidth() - 27
      else
        self.scrollbar:SetValue(offset)
        return
      end
    else
      self.offset = 0
      self.buttonWidth = self:GetWidth() - 10
    end

    for i = 1, self.buttonCount do
      self.buttons[i]:update(self.sequence[i + self.offset])
    end
  end,

  _updateScrollbar = function(self)
    local nodes = #self.sequence
    if nodes > self.buttonCount then
      self.scrolling = true
      self.scrollbar:SetMinMaxValues(0, max(0, nodes - self.buttonCount))
      self.scrollbar:Show()
    else
      self.scrolling = false
      self.scrollbar:Hide()
    end
  end
})

ep.TreeButton = ep.control('ep.TreeButton', 'epTreeButton', ep.Button, nil, {
  initialize = function(self, frame, id)
    self.font = self:GetNormalFontObject()
    self.frame = frame
    self.id = id
    self.selected = false
  end,

  enter = function(self)
    local tooltip = self.node.item.tooltip
    if tooltip then
      tooltip.location = {anchor=self, edge='BOTTOMLEFT', hook='TOPLEFT', x=-5}
      tooltip.delay = self.frame.tooltipDelay
      epTooltip:display(tooltip)
    end
    self.highlight:Show()
  end,

  leave = function(self)
    if not self.selected then
      self.highlight:Hide()
    end
    if self.node.item.tooltip then
      epTooltip:hide(self)
    end
  end,

  openOrClose = function(self)
    if self.node.open then
      self.frame:close(self.node.idx, self.id)
    else
      self.frame:open(self.node.idx, self.id)
    end
  end,

  select = function(self)
    self.frame:selectNode(self.node.idx)
  end,

  scroll = function(self, delta)
    local scrollbar = self.frame.scrollbar
    if scrollbar and scrollbar:IsShown() then
      scrollbar:move(-delta)
    end
  end,

  update = function(self, node)
    self.node = node
    if node then
      self:SetText(node.item.label)
      if not self.frame.flat then
        self.text:ClearAllPoints()
        self.text:SetPoint('TOPLEFT', self, 'TOPLEFT', 10 + (node.indent * 10), 0)
      end
      if node.item.items then
        self.arrow:ClearAllPoints()
        self.arrow:SetPoint('LEFT', self, 'LEFT', (node.indent * 10) - 7, -1)
        if node.open then
          self.arrow:SetNormalTexture('Interface\\AddOns\\ephemeral\\textures\\arrow-down')
        else
          self.arrow:SetNormalTexture('Interface\\AddOns\\ephemeral\\textures\\arrow-right')
        end
        self.arrow:Show()
      else
        self.arrow:Hide()
      end
      if node == self.frame.selection then
        self.selected = true
        self.highlight:Show()
        self:LockHighlight()
      else
        self.selected = nil
        self.highlight:Hide()
        self:UnlockHighlight()
      end
      self:SetWidth(self.frame.buttonWidth)
      self:Show()
    else
      self:Hide()
    end
  end
})

ep.VerticalScrollBar = ep.control('ep.VerticalScrollBar', 'epVerticalScrollBar', ep.Slider)
