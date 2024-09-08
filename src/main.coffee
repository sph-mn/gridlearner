dom = {}; (dom[a.id] = a for a in document.querySelectorAll("[id]"))

localStorageGetJsonItem = (key) ->
  a = localStorage.getItem(key)
  if a then JSON.parse(a) else null

localStorageSetJsonItem = (key, value) -> localStorage.setItem key, JSON.stringify(value)

class grid_mode
  constructor: (grid) -> @grid = grid
  set_option: (key, value) ->
    @options[key] = value
    @update()

class grid_mode_pair_class extends grid_mode
  name: "pair"
  update: ->
    dom.grid.innerHTML = ""

class grid_mode_synonym_class extends grid_mode
  name: "synonym"
  update: ->
    dom.grid.innerHTML = ""

class grid_mode_which_class extends grid_mode
  name: "which"
  options: alternatives: 5
  option_fields: [
    ["alternatives", "integer"]
  ]
  update: ->
    dom.grid.innerHTML = ""

class grid_mode_single_class extends grid_mode
  name: "single"
  options: hold_to_flip: false
  option_fields: [
    ["hold_to_flip", "boolean"]
  ]
  mousedown: (cell) -> cell.classList.toggle "selected"
  mouseup: (cell) -> @options.hold_to_flip and cell.classList.toggle("selected")
  update: ->
    dom.grid.innerHTML = ""
    for a, index in @grid.data
      question = crel "div", a[0]
      answer = crel "div", a.slice(1).join(" ")
      dom.grid.appendChild crel "div", {"data-index": index}, question, answer

class grid_class
  selection: []
  data: []
  font_size: 42
  key: space: 32
  get_config: ->
    {
      selection: @selection
      mode: @mode.name
      mode_options: @mode.options
      font_size: @font_size
    }
  set_config: (a) ->
    @mode = @modes[a.mode] if a.mode
    @mode.options = a.mode_options if a.mode_options
    @selection = a.selection if a.selection
    if a.font_size
      @font_size = a.font_size
      @update_font_size()
  update: -> @mode.update()
  update_font_size: -> dom.grid.style.fontSize = "#{@font_size}px"
  modify_font_size: (a) ->
    @font_size += a
    @update_font_size()
  add_events: ->
    dom.grid.addEventListener "mousedown", (event) =>
      cell = event.target.closest "div[data-index]"
      return unless cell
      @mode.mousedown and @mode.mousedown cell
    dom.grid.addEventListener "mouseup", (event) =>
      cell = event.target.closest "div[data-index]"
      return unless cell
      @mode.mouseup and @mode.mouseup cell
  constructor: ->
    @modes = {
      single: new grid_mode_single_class @
      pair: new grid_mode_pair_class @
      synonym: new grid_mode_synonym_class @
      which: new grid_mode_which_class @
    }
    @mode = @modes.single
    @add_events()
    @update_font_size()

class file_select_class
  hooks:
    add: null
    change: null
  selection: null
  next_id: 1
  files: {}
  file_data: {}
  add: (file) ->
    Papa.parse file,
      delimiter: " "
      complete: (data) =>
        data.errors.forEach (error) -> console.error error
        @files[@next_id] = name: file.name
        @file_data[@next_id] = data.data
        @selection = @next_id
        @hooks.add and @hooks.add()
        @save_file_data @selection
        @next_id += 1
        @save()
        @update_options()
  delete: ->
    return unless @selection?
    id = @selection
    a = @files[id]
    return unless confirm "delete file #{a.name}?"
    localStorage.removeItem "file_data_#{id}"
    delete @files[id]
    delete @file_data[id]
    ids = Object.keys @files
    @selection = if ids.length then ids[ids.length - 1] else null
    @save()
    @hooks.delete && @hooks.delete id
    @update_options()
  clear_files: ->
    localStorage.removeItem "files"
    ids = Object.keys @files
    for id in ids
      localStorage.removeItem "file_data_#{id}"
      @hooks.delete id if @hooks.delete
    @files = {}
    @file_data = {}
    @selection = null
    @save()
    @update_options()
  save: -> localStorageSetJsonItem "files", {files: @files, selection: @selection, next_id: @next_id}
  load: ->
    a = localStorageGetJsonItem "files"
    return unless a
    @files = a.files
    @selection = a.selection
    @next_id = a.next_id
    @update_options()
  save_file_data: (id) -> localStorageSetJsonItem "file_data_#{id}", @file_data[id]
  load_file_data: (id) ->
    a = localStorageGetJsonItem "file_data_#{id}"
    return unless a
    @file_data[id] = a
  update_options: ->
    dom.files.innerHTML = ""
    a = new Option "add", ""
    a.addEventListener "click", (event) -> dom.file.click()
    dom.files.appendChild a
    Object.keys(@files).forEach (id) =>
      b = new Option @files[id].name, id
      b.selected = true if id == @selection
      dom.files.appendChild b
    if @selection?
      a = new Option "delete", ""
      a.addEventListener "click", (event) => @delete @selection
      dom.files.appendChild a
  add_events: ->
    dom.file.addEventListener "change", (event) =>
      return unless event.target.files.length
      @add event.target.files[0]
    dom.files.addEventListener "click", (event) =>
      unless @selection?
        dom.file.click()
        event.stopPropagation()
        event.preventDefault()
    dom.files.addEventListener "change", (event) =>
      return unless event.target.value
      @selection = parseInt event.target.value, 10
      @load_file_data @selection
      @hooks.change and @hooks.change()
      @save()
  constructor: ->
    @load()
    @load_file_data(@selection) if @selection?
    @update_options()
    @add_events()
  get_file: -> @files[@selection]
  get_file_data: -> @file_data[@selection]
  set_file: (id) ->
    @selection = id
    @load_file_data id

class mode_select_class
  hooks: change: null
  selection: 0
  mode_option_fields: []
  make_option_fields: (mode) ->
    return null unless mode.option_fields
    mode.option_fields.map (field_config) ->
      name = field_config[0]
      type = field_config[1]
      value = mode.options[name]
      if type == "boolean"
        a = crel "input", {type: "checkbox"}
        a.checked = "checked" if value
        a.addEventListener "change", (event) -> mode.set_option name, event.target.checked
      else if type == "integer"
        a = crel "input", {type: "number", value, placeholder: name, min: 0, step: 1}
        a.addEventListener "change", (event) -> mode.set_option name, parseInt(event.target.value)
      crel "label", name, a
  set_mode: (a) ->
    @hide_selected_option_fields()
    @selection = @modes.indexOf a
    dom.modes.value = @selection
    @show_selected_option_fields()
  get_mode: -> @modes[@selection]
  hide_selected_option_fields: -> @mode_option_fields[@selection]?.classList.remove "show"
  show_selected_option_fields: ->
    selected_option_fields = @mode_option_fields[@selection]
    if selected_option_fields
      dom.options.classList.remove "hidden"
      selected_option_fields.classList.add "show"
    else
      dom.options_form.classList.add "hidden"
      dom.options.classList.add "hidden"
  constructor: (modes) ->
    @modes = Object.keys modes
    for name, i in @modes
      mode = modes[name]
      dom.modes.appendChild new Option mode.name, i
      option_fields = @make_option_fields mode
      if option_fields
        div = crel "div", option_fields
        @mode_option_fields[i] = div
        dom.options_form.appendChild div
      else @mode_option_fields[i] = null
    dom.modes.addEventListener "change", (event) =>
      @hide_selected_option_fields()
      @selection = parseInt event.target.value
      @hooks.change && @hooks.change()
      @show_selected_option_fields()
    dom.options.addEventListener "click", (event) -> dom.options_form.classList.toggle "hidden"
    @show_selected_option_fields()

class app_class
  file_select: new file_select_class
  grid: new grid_class
  configs: {}
  add_events: ->
    dom.save.addEventListener "click", (event) =>
      @save()
    dom.reset.addEventListener "click", (event) =>
      @grid.reset()
    dom.font_increase.addEventListener "click", (event) =>
      @grid.modify_font_size 3
      @save()
    dom.font_decrease.addEventListener "click", (event) =>
      @grid.modify_font_size -3
      @save()
  save: ->
    @configs[@file_select.selection] = @grid.get_config() if @file_select.selection?
    localStorageSetJsonItem "app", configs: @configs
  load: ->
    a = localStorageGetJsonItem "app"
    return unless a
    @configs = a.configs
    if @file_select.selection?
      config = a.configs[@file_select.selection]
      @mode_select.set_mode config.mode
      @grid.set_config config
      @grid.data = @file_select.get_file_data()
      @grid.update()
  constructor: ->
    @mode_select = new mode_select_class @grid.modes
    @mode_select.hooks.change = =>
      return unless @file_select.selection?
      mode = @mode_select.get_mode()
      @configs[@file_select.selection].mode = mode
      @grid.mode = @grid.modes[mode]
      @grid.update()
      @save()
    @file_select.hooks.add = () =>
      config = @grid.get_config()
      config.mode = @mode_select.get_mode()
      @configs[@file_select.selection] = config
      @grid.data = @file_select.get_file_data()
      @grid.set_config config
      @grid.update()
      @save()
    @file_select.hooks.change = =>
      @grid.data = @file_select.get_file_data()
      @grid.set_config @configs[@file_select.selection]
      @grid.update()
      @mode_select.set_mode @grid.mode.name
    @file_select.hooks.delete = (old_selection) =>
      delete @configs[old_selection]
      if @file_select.selection?
        @grid.data = @file_select.get_file_data()
        @grid.set_config @configs[@file_select.selection]
        @mode_select.set_mode @grid.mode.name
      else @grid.data = []
      @save()
      @grid.update()
    @add_events()
    @load()

app = new app_class()
