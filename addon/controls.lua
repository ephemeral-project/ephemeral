local attach_tooltip = ep.attach_tooltip
local band = bit.band
local fieldsort = ep.fieldsort
local floor = math.floor
local invoke = ep.invoke
local tint = ep.tint
local update = ep.update

ep.button = ep.control('ep.button', 'epButton', ep.basecontrol, 'button', {
  initialize = function(self, tooltip)
    self.tooltip = tooltip
    if tooltip then
      attach_tooltip(self, tooltip)
    end
  end,

  disable = function(self)
    self:Disable()
    self:SetAlpha(0.6)
  end,

  enable = function(self)
    self:Enable()
    self:SetAlpha(1.0)
  end
})

ep.checkbox = ep.control('ep.checkbox', 'epCheckBox', ep.basecontrol, 'checkbox', {
  initialize = function(self, reversed, tooltip)
    local width = self:GetTextWidth() + 6
    if reversed then
      self:SetHitRectInsets(-width, 0, 0, 0)
    else
      self:SetHitRectInsets(0, -width, 0, 0)
    end

    self.tooltip = tooltip
    if tooltip then
      attach_tooltip(self, tooltip)
    end
  end,

  check = function(self, value)
    if value ~= nil then
      self:SetChecked(value)
    end
    return self:GetChecked()
  end,

  disable = function(self, state)
    self:Disable()
    if state ~= nil then
      self:SetChecked(state)
    end
    self:SetAlpha(0.6)
  end,

  enable = function(self, state)
    self:Enable()
    if state ~= nil then
      self:SetChecked(state)
    end
    self:SetAlpha(1.0)
  end,

  _grid_set = function(self, value)
    self:SetChecked(value)
  end
})

ep.colorspot = ep.control('ep.colorspot', 'epColorSpot', ep.button, nil, {
  initialize = function(self, color)
    self.color = tint(color or 'black')
    self.spot:SetTexture(unpack(self.color))
  end
})

ep.dropbox = ep.control('ep.dropbox', 'epDropBox', ep.button, nil, {
  initialize = function(self, specification)
    if not specification then
      return
    end

    self.items = {}
    self.prefix = ''
    self.callback = specification.callback
    self.default = specification.default
    self.sorted = specification.sorted
    self.tooltip = specification.tooltip
    self.values = {}
    if specification.prefix then
      self.prefix = tint:format('label', specification.prefix..': ')
    end

    self.menu = ep.menu(self.name..'Menu', self, {
      callback = {self.select, self},
      items = self.items,
      location = {anchor = self, x = 0, y = -18},
      scrollable = specification.scrollable or false,
      window = specification.window or 8,
      width = self,
    })

    if specification.items then
      self:populate(specification.items, self.default, specification.value)
    end
    if tooltip then
      tooltip.location = {anchor = self, hook = 'BOTTOMLEFT', x = 10, y = -2}
      attach_tooltip(self, tooltip)
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
      sort(self.items, self._sort_by_label)
    end
    self.menu.built = false
  end,

  disable = function(self, cleared)
    self:SetAlpha(0.6)
    if cleared then
      self:SetText('')
    end
    self:Disable()
  end,

  enable = function(self, value)
    self:SetAlpha(1.0)
    if value then
      self:select(value, true)
    elseif self:GetText() == '' then
      self:set_text(self.value)
    end
    self:Enable()
  end,

  open = function(self)
    if self.menu and #self.items > 1 then
      self.menu:toggle()
    end
  end,

  populate = function(self, population, default, value)
    items, self.values = ep.clear(self.items), {}
    values = self.values

    for i, item in ipairs(population) do
      if type(item) == 'table' then
        values[item[1] ] = item[2]
        items[i] = {label = item[2], value = item[1]}
      else
        values[item] = item
        items[i] = {label = item, value = item}
      end
    end

    self.menu.built = false
    if self.sorted then
      sort(items, self._sort_by_label)
    end

    self.default = default
    if value then
      self:select(value, true)
    elseif default then
      self:select(default, true)
    end
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
        self:select(self.default or self.items[1].value)
      end
    end
  end,

  select = function(self, value, quiet)
    if self.values[value] then
      self.value = value
      if quiet ~= true and self.callback then
        invoke(self.callback, value, self)
      end
      self:set_text(value)
    end
  end,

  set_text = function(self, value)
    self:SetText(self.prefix..self.values[value])
  end,

  _grid_set = function(self, value)
    self:select(value, true)
  end,

  _sort_by_label = function(first, second)
    return first.label < second.label
  end
})

ep.combobox = ep.control('ep.combobox', 'epComboBox', ep.dropbox, 'editbox', {
  disable = function(self, cleared)
    self:ClearFocus()
    self:super():disable(cleared)
    self:EnableKeyboard(false)
    self:EnableMouse(false)
  end,

  enable = function(self, value)
    self:super():enable(value)
    self:EnableKeyboard(true)
    self:EnableMouse(true)
  end,

  select = function(self, value, quiet)
    self.value = value
    if not quiet and self.callback then
      invoke(self.callback, value, self)
    end
    if self.values[value] then
      self:set_text(value)
    else
      self:SetText(value)
    end
    self:ClearFocus()
  end
})

ep.editarea = ep.control('ep.editarea', 'epEditArea', ep.baseframe, nil, {
  initialize = function(self, label, locked, tooltip)
    self.editbox = self.scrollframe:GetScrollChild()
    self.label = label
    self.tooltip = tooltip
    if locked then
      self:lock(true)
    end
    if label then
      self.innerlabel:SetText(self.label)
      if self.editbox:GetText() == '' then
        self.innerlabel:Show()
      end
    end
    if tooltip then
      attach_tooltip(self, tooltip)
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
      self.ea_text = self.editbox:GetText()
    end
    if cleared then
      self.editbox:SetText('')
    end
    self.editbox:EnableKeyboard(false)
    self.editbox:EnableMouse(false)
  end,

  enable = function(self, cleared)
    self.disabled = nil
    self:SetAlpha(1.0)
    if cleared then
      self.editbox:SetText('')
    elseif self.ea_text then
      self.editbox:SetText(self.ea_text)
      self.ea_text = nil
    end
    self.editbox:EnableKeyboard(true)
    self.editbox:EnableMouse(true)
  end,

  get_value = function(self)
    return self:GetText()
  end,

  lock = function(self, locked)
    self.editbox:EnableKeyboard(not locked)
  end,

  set_value = function(self, value)
    self.editbox:SetText(value or '')
    if #self.editbox:GetText() == 0 then
      if self.label then
        self.innerlabel:Show()
      end
    else
      self.innerlabel:Hide()
    end
  end,

  update_cursor = function(self, x, y)
    local offset, height, y = self.scrollframe:GetVerticalScroll(), self:GetHeight() - 26, abs(y)
    if y < offset then
      self.scrollframe:scroll(y)
    elseif y > (offset + height) then
      self.scrollframe:scroll(y - height)
    end
  end,

  _focus_lost = function(self)
    self.editbox:HighlightText(0, 0)
    if self.label then
      if self.editbox:GetText() == '' then
        self.innerlabel:Show()
      else
        self.innerlabel:Hide()
      end
    end
  end
})

ep.editbox = ep.control('ep.editbox', 'epEditBox', ep.basecontrol, 'editbox', {
  initialize = function(self, label, clearable, tooltip)
    self.clearable = clearable
    self.label = label
    self.tooltip = tooltip
    if self.label then
      self.innerlabel:SetText(self.label)
      if self:GetText() == '' then
        self.innerlabel:Show()
      end
    end
    if self.clearable and self:GetText() ~= '' then
      self.clear_button:Show()
    end
    if tooltip then
      attach_tooltip(self, tooltip)
    end
  end,

  append = function(self, content, unmoved)
    local position = nil
    if #content > 0 then
      if unmoved then
        position = self:GetCursorPosition()
      end
      self:SetCursorPosition(self:GetNumLetters())
      self:Insert(content)
      if position then
        self:SetCursorPosition(position)
      end
    end
  end,

  disable = function(self, cleared, saved)
    self:ClearFocus()
    self:SetAlpha(0.6)
    if saved then
      self.eb_text = self:GetText()
    end
    if cleared then
      self:SetText('')
    end
    self:EnableKeyboard(false)
    self:EnableMouse(false)
  end,

  enable = function(self, cleared)
    self:SetAlpha(1.0)
    if cleared then
      self:SetText('')
    elseif self.eb_text then
      self:SetText(self.eb_text)
      self.eb_text = nil
    end
    self:EnableKeyboard(true)
    self:EnableMouse(true)
  end,

  get_value = function(self)
    return self:GetText()
  end,

  set_value = function(self, value)
    local original = self:GetText()
    self:SetText(value or '')
    if #self:GetText() == 0 then
      self.clear_button:Hide()
      if self.label and self:HasFocus() then
        self.innerlabel:Show()
      end
    else
      self.innerlabel:Hide()
      if self.clearable then
        self.clear_button:Show()
      end
    end
    return original
  end,

  _grid_set = function(self, value)
    self:set_value(value)
  end,

  _focus_lost = function(self)
    self:HighlightText(0, 0)
    if self.label then
      if self:GetText() == '' then
        self.innerlabel:Show()
      else
        self.innerlabel:Hide()
      end
    end
    if self.clearable then
      if self:GetText() == '' then
        self.clear_button:Hide()
      else
        self.clear_button:Show()
      end
    end
    self:event(':changed', self)
  end,

  _value_changed = function(self)
    self:event(':changed', self)
  end
})

ep.grid = ep.control('ep.grid', 'epGrid', ep.baseframe, nil, {
  controls = {
    button = {constructor = ep.button, height = 19, minwidth = 19},
    checkbox = {constructor = ep.checkbox, height = 16, width = 20},
    colorspot = {constructor = ep.colorspot, height = 16, width = 16},
    combobox = {constructor = ep.combobox, height = 19, minwidth = 19},
    dropbox = {constructor = ep.dropbox, height = 19, minwidth = 19},
    editbox = {constructor = ep.editbox, height = 19, minwidth = 19},
    iconbox = {constructor = ep.iconbox, height = 38, width = 38},
    spinner = {constructor = ep.spinner, height = 19, minwidth = 19},
    statusbar = {constructor = ep.statusbar, height = 19, minwidth = 19}
  },

  initialize = function(self, params)
    params = params or {}
    self.alternated = (params.alternated ~= false)
    self.default_sort = params.default_sort
    self.hpadding = params.hpadding or params.padding or 2
    self.offset = 0
    self.resize_to_fit = params.resize_to_fit
    self.total = 0
    self.unselectable = params.unselectable
    self.vpadding = params.vpadding or params.padding or 1

    if params.header then
      self.headers, self.headers_by_field = {}, {}
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

    self.rowcount = floor((self:GetHeight() - clearance) / self.rowheight)
    self.rowwidth = self:GetWidth() - 17
    space = self.rowwidth - self.exactwidth - padding

    total, offset = 0, self.hpadding
    for i = 1, #cells do
      cell = cells[i]
      if cell.relwidth then
        cell.width = floor(space * cell.relwidth)
        total = total + cell.width
      end
      if not cell.staticwidth then
        cell.cwidth = cell.width - padding
       end
       cell.hoffset = offset + self.hpadding
       offset = offset + cell.width
    end
    if total < space then
      cell.width = cell.width + (space - total)
    end

    offset = (self.header and 20 or 1) + self.vpadding
    for i = 1, self.rowcount do
      row = self.rows[i]
      if not row then
        row = ep.gridrow(self.name..'r'..i, self, self, i)
        row:SetPoint('TOPLEFT', self, 'TOPLEFT', 1, -(offset + (self.rowheight * (i - 1))))
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
    for i = self.rowcount + 1, #self.rows do
      row = self.rows[i]
      row.visible = nil
      row:Hide()
    end

    if self.resize_to_fit then
      row = self.rows[self.rowcount]
      point = {row:GetPoint()}
      offset = abs(point[5]) + row:GetHeight() + 3
      if offset < self:GetHeight() then
        self:SetHeight(offset)
      end
    end
  end,

  construct = function(self, cells)
    local hpadding, control, header = self.hpadding * 2
    self.rowheight, self.exactwidth = 13, 0

    for i, cell in ipairs(cells) do
      if not cell.title then
        cell.unsortable = true
      end
      control = self.controls[cell.control]
      if control then
        cell.control = control
        if control.height then
          cell.cheight = control.height
          self.rowheight = max(self.rowheight, control.height)
        end
        if control.width then
          cell.width = control.width + hpadding
          cell.staticwidth = true
        elseif cell.width then
          cell.width = cell.width + hpadding
        end
        if cell.width then
          self.exactwidth = self.exactwidth + cell.width
        end
      else
        cell.control = nil
        if cell.width then
          cell.width = cell.width + hpadding
          self.exactwidth = self.exactwidth + cell.width
        end
      end
      cell.field = cell.field or i
      if self.headers then
        header = ep.gridheader(self.name..'h'..i, self.header, self, i, cell)
        self.headers[i], self.headers_by_field[cell.field] = header, header
      end
    end

    for i, cell in ipairs(cells) do
      if cell.cheight then
        cell.voffset = max(0, floor((self.rowheight - cell.cheight) / 2)) + self.vpadding
      else
        cell.cheight = self.rowheight
        cell.voffset = self.vpadding
      end
    end

    self.cells = cells
    self.rows = {}
    self.rowheight = self.rowheight + (self.vpadding * 2)
  end,

  load = function(self, data)
    self.data = data
    self.total = #self.data
    self:_update_scrollbar()
    self:update(0)
  end,

  resize = function(self)
    self:build()
    self:_update_scrollbar()
    self:update()
  end,

  sort = function(self, field, descending)
    if self.headers then
      if self.current_sort then
        self.headers_by_field[self.current_sort[1]]:clear_sort()
      end
      self.current_sort = {field, descending}
      self.headers_by_field[field]:set_sort(descending)
    end
    fieldsort(self.data, {field, descending}, self.default_sort)
    self:update()
  end,

  update = function(self, offset)
    offset = floor(offset or self.scrollbar:GetValue())
    if self.scrollbar:GetValue() == offset then
      if self.generator then
        self:_generate_data()
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

  _generate_data = function(self)
  end,

  _update_scrollbar = function(self)
    self.scrollbar:SetMinMaxValues(0, max(0, self.total - self.rowcount))
  end
})

ep.gridcell = ep.control('ep.gridcell', 'epGridCell', ep.baseframe, nil, {
  initialize = function(self, row)
    self.row = row
  end,

  _grid_set = function(self, value)
    self.text:SetText(value)
  end
})

ep.gridheader = ep.control('ep.gridheader', 'epGridHeader', ep.button, nil, {
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

  clear_sort = function(self)
    self.sorting = nil
    self.arrow:Hide()
    self.slight_highlight:Hide()
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

  set_sort = function(self, descending)
    self.sorting = descending
    if descending then
      self.arrow:SetTexture('Interface\\AddOns\\ephemeral\\textures\\arrow-down')
    else
      self.arrow:SetTexture('Interface\\AddOns\\ephemeral\\textures\\arrow-up')
    end
    self.arrow:Show()
    self.slight_highlight:Show()
  end
})

ep.gridrow = ep.control('ep.gridrow', 'epGridRow', ep.baseframe, nil, {
  initialize = function(self, grid, id)
    local instance, cell_name, constructor
    self.grid = grid
    self.id = id
    self.cells = {}
    for i, cell in ipairs(grid.cells) do
      cell_name = self.name..'c'..i
      if cell.control then
        constructor = cell.control.constructor
        if constructor.for_grid then
          instance = constructor:for_grid(cell_name, self, cell)
        else
          instance = constructor(cell_name, self)
        end
        instance.row = row
      else
        instance = ep.gridcell(cell_name, self, self)
      end
      instance.cell = cell
      self.cells[i] = instance
    end
    if grid.alternated and band(id, 1) ~= 1 then
      self.diff:Show()
    end
    self:SetHeight(grid.rowheight)
  end,

  enter = function(self)
    self.highlight:Show()
  end,

  layout = function(self)
    self:SetWidth(self.grid.rowwidth)
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
          instance:_grid_set(self.data[instance.cell.field])
        end
      end
      self:Show()
    else
      self:Hide()
    end
  end
})

ep.iconbox = ep.control('ep.iconbox', 'epIconBox', ep.button, nil, {
  initialize = function(self, params)
    self:child('T'):SetGradientAlpha('vertical', 1, 1, 1, 0.2, 1, 1, 1, 1)
    self:child('B'):SetGradientAlpha('vertical', 1, 1, 1, 1, 1, 1, 1, 0.2)
    self:child('L'):SetGradientAlpha('horizontal', 1, 1, 1, 1, 1, 1, 1, 0.2)
    self:child('R'):SetGradientAlpha('horizontal', 1, 1, 1, 0.2, 1, 1, 1, 1)
    self.texture:SetVertexColor(1.0, 1.0, 1.0, 0.9)

    params = params or {}
    if params.static then
      self:disable()
    end
    if params.default then
      self:set(default)
    end

    self.anchor = params.anchor or self
    self.enable_browsing = params.enable_browsing
  end,

  browse = function(self)
    if self.enable_browsing then
      epIconBrowser:display({self.set, self}, self.anchor)
    end
  end,

  clear = function(self)
    self.icon = nil
    self.texture:SetTexture('')
  end,

  desaturate = function(self, desaturated)
    if not self.texture:SetDesaturated(desaturated) then
      if desaturated then
        self.texture:SetVertexColor(0.5, 0.5, 0.5, 0.9)
      else
        self.texture:SetVertexColor(1.0, 1.0, 1.0, 0.9)
      end
    end
  end,

  disable = function(self, shaded)
    self:Disable()
    if shaded then
      self:SetAlpha(0.6)
    end
  end,

  enable = function(self)
    self:Enable()
    self:SetAlpha(1.0)
  end,

  set = function(self, identifier)
    if identifier then
      self.icon = identifier
      self.texture:SetTexture(ep.icon(identifier))
    end
  end,

  _grid_set = function(self, value)
    self:set(value)
  end
})

ep.listbuilder = ep.control('ep.listbuilder', 'epListBuilder', ep.baseframe, nil, {
  initialize = function(self, specification)
    self.buttons = {}
    self.entries = {}
    self.opened = false
  end,

  add = function(self, entry)
    for i, existing in ipairs(self.entries) do
      if existing[1] == entry[1] then
        return
      end
    end

    local idx, button = #self.entries + 1
    if self.buttons[idx] then
      button = self.buttons[idx]
    else
      button = CreateFrame('Button', self.name..idx, self.container, 'epListEntry')
      self.buttons[idx] = button
    end
  end,

  cancel = function(self)
    if self.opened then
      self.editor:Hide()
      self.opened = false
    end
  end,

  open = function(self, item)
    if self.opened then
      self.editor:Hide()
      self.opened = false
    else
      self.editor:SetWidth(self:GetWidth())
      self.editor:Show()
      self.opened = true
    end
  end,
})

ep.menu = ep.control('ep.menu', 'epMenu', ep.baseframe, nil, {
  menus = {},

  initialize = function(self, specification)
    self.buttons = {}
    self.callback = specification.callback
    self.items = specification.items
    self.generator = specification.generator
    self.location = specification.location
    self.offset = 0
    self.width = specification.width or 0
    self.window = specification.window or 0

    self.scrollbar = false
    if specification.scrollable then
      self.scrollbar = ep.vscrollbar(self.name..'ScrollBar', self, {self.scroll, self})
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
        button = ep.menubutton(self.name..i, self, self, i)
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

  closeall = function(self)
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
      if not self.savedwidth or self.savedwidth ~= self.width:GetWidth() then
        self:build()
        if not self.built then
          return
        end
      end
    end
    if self.scrollbar and self.scrollbar:IsShown() then
      self.scrollbar:SetValue(0)
    end

    local menucount = #self.menus
    if self.ancestor then
      if menucount > self.ancestor.depth then
        self.menus[self.ancestor.depth + 1]:close()
      end
    elseif menucount > 0 then
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

ep.menubutton = ep.control('ep.menubutton', 'epMenuButton', ep.button, nil, {
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
        self.item.submenu = ep.menu(self.frame.name..self.item.label..'Menu', self.frame, self.item.submenu)
        self.item.submenu.ancestor = self.frame
      end
      self.item.submenu:display({anchor = self, x = self:GetWidth() + 5, y = 4})
    elseif #self.frame.menus > self.frame.depth then
      self.frame.menus[self.frame.depth + 1]:close()
    end
  end,

  leave = function(self)
    self.highlight:Hide()
    if self.item.submenu then
      self.arrow:SetTexture('Interface\\AddOns\\ephemeral\\textures\\arrow-right')
    end
  end,

  update = function(self)
    if self.item then
      self:SetText(self.item.label)
      if self.item.color then
        self.font:SetTextColor(unpack(tint(self.item.color)))
      else
        self.font:SetTextColor(unpack(tint.label))
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

ep.messageframe = ep.control('ep.messageframe', 'epMessageFrame', ep.basecontrol, 'messageframe', {
  initialize = function(self, color)
    self.range = 0
    if color then
      self.color = tint(color)
    else
      self.color = tint.standard
    end
  end,

  append = function(self, text, color, id)
    color = (color) and tint(color) or self.color
    self.messages:AddMessage(text, color[1], color[2], color[3], id)
    self.range = self.messages:GetNumMessages() - 1
    self.scrollbar:SetMinMaxValues(0, self.range)
    self.scrollbar:SetValue(self.range)
  end,

  scroll = function(self, offset)
    self.messages:SetScrollOffset(self.range - offset)
  end,

  set_font_object = function(self, font)
    self.messages:SetFontObject(font)
  end
})

ep.multibutton = ep.control('ep.multibutton', 'epMultiButton', ep.basecontrol, 'button', {
  initialize = function(self, params)
    if not params then
      return
    end
    self.tooltip = params.tooltip
    self.menu = ep.menu(self.name..'Menu', self, {
      items = params.items,
      location = {anchor = self, x = 0, y = -18},
      window = params.window or 8,
      width = self,
    })
    if tooltip then
      tooltip.location = {anchor = self, hook = 'BOTTOMLEFT', x = 10, y = -2}
      attach_tooltip(self, tooltip)
    end
  end,

  disable = function(self)
    self:SetAlpha(0.6)
    self:Disable()

    self.opener:SetAlpha(0.6)
    self.opener:Disable()
  end,

  enable = function(self)
    self:SetAlpha(1.0)
    self:Enable()

    self.opener:SetAlpha(1.0)
    self.opener:Enable()
  end,

  open = function(self)
    self.menu:toggle()
  end,
})

ep.scrollframe = ep.control('ep.scrollframe', 'epScrollFrame', ep.basecontrol, 'scrollframe', {
  initialize = function(self, specification)
    self.hideable = specification.hideable or false
    self.managed = specification.managed or false
    self.resizable = specification.resizable or false
    self.childframe, self.scrollbar = self:GetScrollChild(), self:child('ScrollBar')
  end,

  scroll = function(self, value)
    local min, max = self.scrollbar:GetMinMaxValues()
    if value > max then
      self.scrollbar:SetMinMaxValues(min, value)
    end
    self.scrollbar:SetValue(value)
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
          self.childframe:SetWidth(self.childframe:GetWidth() + 20)
        end
      end
    else
      if self.hideable then
        if self.resizable then
          self.childframe:SetWidth(self.childframe:GetWidth() - 20)
        end
        self.scrollbar:Show()
      end
    end
  end,

  update_scroll = function(self, value)
    self:SetVerticalScroll(value)
  end
})

ep.slider = ep.control('ep.slider', 'epSlider', ep.basecontrol, 'slider', {
  initialize = function(self, callback, window, multiplier)
    self.multiplier = multiplier
    self.window = window

    local min, max = self:GetMinMaxValues()
    if floor(self:GetValueStep()) == 0 then
      self:SetValueStep(1)
    end
    if type(self:GetValue()) ~= 'number' then
      self:SetValue(min)
    end

    self:update(min or 0)
    self.callback = callback
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

ep.spinner = ep.control('ep.spinner', 'epSpinner', ep.editbox, nil, {
  initialize = function(self, params)
    params = params or {}
    if params.values then
      self.circular = params.circular
      self.value = params.value
      self.values = params.values
      if self.value then
        self:set_value(self.value)
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
      self.value = params.value or 0
      self:set_value(self.value)
    end

    self.onchange = params.onchange
    self.static = params.static
    if self.static then
      self:EnableKeyboard(false)
      self:EnableMouse(false)
    end

    self.tooltip = params.tooltip
    if self.tooltip then
      attach_tooltip(self, self.tooltip)
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
  end,

  enable = function(self, value)
    self:SetAlpha(1.0)
    if value then
      self:set_value(value)
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
  end,

  set_value = function(self, value)
    self:ClearFocus()
    if self.values then
      local offset = ep.index(self.values, value)
      if offset then
        self.offset, self.value = offset, value
      end
    else
      value = tonumber(value)
      if type(value) ~= 'number' then
        value = self.value
      elseif self.validator then
        value = invoke(self.validator, value, self)
      elseif self.minimum and value < self.minimum then
        value = self.minimum
      elseif self.maximum and value > self.maximum then
        value = self.maximum
      elseif self.bounded then
        value = self.minimum + (floor((value - self.minimum) / self.step) * self.step)
      end
      self.value = value
    end
    if self.onchange then
      invoke(self.onchange, self.value, self)
    end
    self:update()
  end,

  spin = function(self, direction, absolute)
    local value, count = self.value
    if self.values then
      count = #self.values
      if absolute then
        self.offset = (direction < 0) and count or 1
      else
        self.offset = self.offset - direction
        if self.offset < 1 then
          self.offset = (self.circular) and count or 1
        elseif self.offset > count then
          self.offset = (self.circular) and 1 or count
        end
      end
      self.value = self.values[self.offset]
    else
      if absolute then
        self.value = (direction < 0) and (self.minimum or 0) or (self.maximum or 0)
      else
        value = value + (self.step * direction)
        if self.minimum and value < self.minimum then
          value = self.minimum
        elseif self.maximum and value > self.maximum then
          value = self.maximum
        end
        self.value = value
      end
    end
    if self.onchange then
      invoke(self.onchange, self.value, self)
    end
    self:update()
  end,

  update = function(self)
    if self.formatter then
      self:SetText(invoke(self.formatter, self.value, self))
    elseif self.precision then
      self:SetText(format('%0.0'..self.precision..'f', self.value))
    else
      self:SetText(tostring(self.value))
    end
  end,

  _grid_set = function(self, value)
    self:set_value(value)
  end
})

ep.tabbutton = ep.control('ep.tabbutton', 'epTabButton', ep.button, nil, {
  initialize = function(self, id, frame)
    self.background = self:child('Background')
    self.border = self:child('Border')
    self.frame = frame
    self.id = id
    self.bottomborder:SetVertexColor(1, 1, 1, 0.5)
  end,

  toggle = function(self, active)
    if active then
      self.background:Show()
      self:SetNormalFontObject(epTitleFont)
      self:Disable()
      if self.frame.show_bottom_border then
        self.bottomborder:Show()
      end
    else
      self.background:Hide()
      self:SetNormalFontObject(epLabelFont)
      self:Enable()
      if self.frame.show_bottom_border then
        self.bottomborder:Hide()
      end
    end
  end
})

ep.tabbedframe = ep.control('ep.tabbedframe', 'epTabbedFrame', ep.baseframe, nil, {
  initialize = function(self, items, params)
    params = params or {}
    self.callback = params.callback
    self.show_bottom_border = params.show_bottom_border
    self.sorted = params.sorted

    self.items = {}
    self.tab = 0
    self.tabs = {}

    if type(items) == 'table' then
      self:populate(items)
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
  end,

  build = function(self)
    local items, tabs, offset, index, tab, border = #self.items, #self.tabs
    if items > tabs then
      for i = tabs + 1, items do
        self.tabs[i] = ep.tabbutton(self.name..i, self, i, self)
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
      update(self.items[offset], item)
      self:build()
    end
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

ep.tree = ep.control('ep.tree', 'epTree', ep.baseframe, nil, {
  initialize = function(self, params)
    params = params or {}
    self.callback = params.callback
    self.default_expansion = params.default_expansion or 0
    self.expand_on_select = params.expand_on_select
    self.flat = params.flat
    self.no_default_selection = params.no_default_selection
    self.resize_to_fit = params.resize_to_fit

    self.buttons = {}
    self.button_count = 0
    self.button_width = 0
    self.offset = 0
    self.scrolling = false
    self.selection = nil
    self.sequence = nil

    self:construct_buttons()
    if params.items then
      self:populate(params.items)
    end
  end,

  construct_buttons = function(self)
    self.button_count = floor((self:GetHeight() - 8) / 13)
    for i = 1, self.button_count do
      local button = self.buttons[i]
      if button then
        button:Show()
      else
        button = ep.treebutton(self.name..'b'..i, self, self, i)
        button:SetPoint('TOPLEFT', self, 'TOPLEFT', 5, -(4 + (13 * (i - 1))))
        self.buttons[i] = button
      end
    end
    for i = self.button_count + 1, #self.buttons do
      self.buttons[i]:Hide()
    end
  end,

  close = function(self, idx)
    local row, candidate = self.sequence[idx]
    if row and row.item.items and row.open then
      row.open, idx = nil, idx + 1
      while true do
        candidate = self.sequence[idx]
        if candidate and candidate.indent > row.indent then
          if candidate == self.selection then
            self.selection = row
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
    local row = self.sequence[idx]
    if row and row.item.items and not row.open then
      row.open = true
      for i, item in ipairs(row.item.items) do
        idx = idx + 1
        tinsert(self.sequence, idx, {
          item=item, idx=idx, indent=(row.indent + 1)
        })
      end
      for i = idx + 1, #self.sequence do
        self.sequence[i].idx = i
      end
    end
    self:update()
  end,

  populate = function(self, items, expansion)
    local stack, level, item, row, idx
    expansion = expansion or self.default_expansion

    self.items = items
    self.sequence = {}
    self.selection = nil

    stack, idx = {{items=items, idx=1}}, 1
    while true do
      item = stack[1].items[stack[1].idx]
      stack[1].idx = stack[1].idx + 1
      if item then
        row = {item=item, idx=idx, indent=#stack - 1}
        if item.selected or (idx == 1 and not self.no_default_selection) then
          self.selection = row
        end
        if not self.flat and item.items and row.indent + 1 <= expansion then
          row.open = true
          tinsert(stack, 1, {items=item.items, idx=1})
        end
        tinsert(self.sequence, row)
        idx = idx + 1
      else
        tremove(stack, 1)
        if #stack == 0 then
          break
        end
      end
    end
    self:update()
  end,

  resize = function(self)
    self:construct_buttons()
    if self.sequence then
      self:update()
    end
  end,

  select = function(self, idx, quiet)
    local row = self.sequence[idx]
    if row then
      self.selection = row
      if self.expand_on_select then
        self:open(row.idx)
      end
      if quiet ~= true and self.callback then
        invoke(self.callback, row, self)
      end
    end
    self:update()
  end,

  update = function(self, offset)
    self:_update_scrollbar()
    if self.scrolling then
      offset = floor(offset or self.scrollbar:GetValue())
      if self.scrollbar:GetValue() == offset then
        self.offset = offset
        self.button_width = self:GetWidth() - 27
      else
        self.scrollbar:SetValue(offset)
        return
      end
    else
      self.offset = 0
      self.button_width = self:GetWidth() - 10
    end

    for i = 1, self.button_count do
      self.buttons[i]:update(self.sequence[i + self.offset])
    end
  end,

  _update_scrollbar = function(self)
    local rows = #self.sequence
    if rows > self.button_count then
      self.scrolling = true
      self.scrollbar:SetMinMaxValues(0, max(0, rows - self.button_count))
      self.scrollbar:Show()
    else
      self.scrolling = false
      self.scrollbar:Hide()
    end
  end
})

ep.treebutton = ep.control('ep.treebutton', 'epTreeButton', ep.button, nil, {
  initialize = function(self, frame, id)
    self.font = self:GetNormalFontObject()
    self.frame = frame
    self.id = id
    self.selected = false
  end,

  enter = function(self)
    self.highlight:Show()
  end,

  leave = function(self)
    if not self.selected then
      self.highlight:Hide()
    end
  end,

  open_or_close = function(self)
    if self.row.open then
      self.frame:close(self.row.idx, self.id)
    else
      self.frame:open(self.row.idx, self.id)
    end
  end,

  select = function(self)
    self.frame:select(self.row.idx)
  end,

  scroll = function(self, delta)
    local scrollbar = self.frame.scrollbar
    if scrollbar and scrollbar:IsShown() then
      scrollbar:move(-delta)
    end
  end,

  update = function(self, row)
    self.row = row
    if row then
      self:SetText(row.item.label)
      if not self.frame.flat then
        self.text:ClearAllPoints()
        self.text:SetPoint('TOPLEFT', self, 'TOPLEFT', 10 + (row.indent * 10), 0)
      end
      if row.item.items then
        self.arrow:ClearAllPoints()
        self.arrow:SetPoint('LEFT', self, 'LEFT', (row.indent * 10) - 7, -1)
        if row.open then
          self.arrow:SetNormalTexture('Interface\\AddOns\\ephemeral\\textures\\arrow-down')
        else
          self.arrow:SetNormalTexture('Interface\\AddOns\\ephemeral\\textures\\arrow-right')
        end
        self.arrow:Show()
      else
        self.arrow:Hide()
      end
      if row == self.frame.selection then
        self.selected = true
        self.highlight:Show()
        self:LockHighlight()
      else
        self.selected = nil
        self.highlight:Hide()
        self:UnlockHighlight()
      end
      self:SetWidth(self.frame.button_width)
      self:Show()
    else
      self:Hide()
    end
  end
})

ep.vscrollbar = ep.control('ep.vscrollbar', 'epVerticalScrollBar', ep.slider)
