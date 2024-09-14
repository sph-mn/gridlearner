dom = {}; (dom[a.id] = a for a in document.querySelectorAll("[id]"))

localStorageGetJsonItem = (key) ->
  a = localStorage.getItem(key)
  if a then JSON.parse(a) else null

localStorageSetJsonItem = (key, value) -> localStorage.setItem key, JSON.stringify(value)
object_array_add = (object, key, value) -> (object[key] ?= []).push value

randomize = (a) ->
  for i in [a.length - 1..0]
    i2 = (Math.random() * (i + 1)) // 1
    [a[i], a[i2]] = [a[i2], a[i]]
  a

class grid_mode
  constructor: (grid) -> @grid = grid

class grid_mode_which_class extends grid_mode
  name: "which"
  options: alternatives: 5
  option_fields: [
    ["alternatives", "integer"]
  ]
  set_option: (key, value) -> @options[key] = value
  update: ->
    dom.grid.innerHTML = ""

class grid_mode_synonym_class extends grid_mode
  name: "synonym"
  selection: []
  update: ->
    dom.grid.innerHTML = ""
    groups = {}
    for a, i in @grid.data
      object_array_add groups, a[1], [i, a]
    for group in Object.values groups
      continue if 2 > group.length
      for a in group
        question = crel "div", a[1][0]
        answer = crel "div", a[1].slice(1).join(" ")
        div = crel "div", {"data-index": a[0]}, question, answer
        dom.grid.appendChild div
  mousedown: (cell, index) ->
    if @selection.length
      [selected_cell, selected_index] = @selection[0]
      if selected_index == index
        @selection = []
        selected_cell.classList.remove "selected"
        return
      a = @grid.data[selected_index]
      b = @grid.data[index]
      if a[1] == b[1]
        cell.classList.add "hidden"
        selected_cell.classList.add "hidden"
        @selection = []
      else
        cell.classList.remove "pulsate"
        cell.classList.add "pulsate"
    else
      @selection.push [cell, index]
      cell.classList.add "selected"

class grid_mode_pair_class extends grid_mode
  name: "pair"
  selection: []
  options: mix: false
  option_fields: [
    ["mix", "boolean"]
  ]
  set_option: (key, value) ->
    @options[key] = value
    @update()
  mousedown: (cell, index) ->
    if @selection.length
      [selected_cell, selected_index] = @selection[0]
      if selected_index == index
        @selection = []
        selected_cell.classList.remove "selected"
        return
      if selected_cell.getAttribute("data-type") == cell.getAttribute ("data-type")
        cell.classList.remove "pulsate"
        cell.classList.add "pulsate"
        return
      a = @grid.data[selected_index]
      b = @grid.data[index]
      if a[1] == b[1]
        cell.classList.add "hidden"
        selected_cell.classList.add "hidden"
        @selection = []
      else
        cell.classList.remove "pulsate"
        cell.classList.add "pulsate"
    else
      @selection.push [cell, index]
      cell.classList.add "selected"
  update: ->
    dom.grid.innerHTML = ""
    questions = []
    answers = []
    for a, index in @grid.data
      question = crel "div", a[0]
      answer = crel "div", a.slice(1).join(" ")
      questions.push crel("div", {"data-index": index, "data-type": "question"}, question)
      answers.push crel("div", {"data-index": index, "data-type": "answer"}, answer)
    if @options.mix
      dom.grid.appendChild a for a in randomize questions.concat answers
    else
      dom.grid.appendChild a for a in randomize questions
      dom.grid.appendChild a for a in randomize answers

class grid_mode_single_class extends grid_mode
  name: "single"
  options:
    hold_to_flip: false
    click_to_remove: false
  option_fields: [
    ["hold_to_flip", "boolean"]
    ["click_to_remove", "boolean"]
  ]
  set_option: (key, value) -> @options[key] = value
  mousedown: (cell, index) ->
    return if @options.click_to_remove
    cell.classList.toggle "selected"
  mouseup: (cell, index) ->
    if @options.click_to_remove
      cell.classList.add "hidden"
    else
      @options.hold_to_flip and cell.classList.toggle "selected"
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
    if a.mode
      @mode = @modes[a.mode]
      dom.grid.setAttribute "data-mode", a.mode
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
  mousedown_selection: null
  add_events: ->
    dom.grid.addEventListener "mousedown", (event) =>
      cell = event.target.closest "div[data-index]"
      return unless cell
      index = parseInt cell.getAttribute "data-index"
      @mousedown_selection = [cell, index]
      @mode.mousedown and @mode.mousedown.apply @mode, @mousedown_selection
    dom.grid.addEventListener "mouseup", (event) =>
      # call even without cell to handle situations where the mouse moved after mousedown
      @mode.mouseup and @mode.mouseup.apply @mode, @mousedown_selection
  constructor: ->
    @modes = {
      single: new grid_mode_single_class @
      pair: new grid_mode_pair_class @
      synonym: new grid_mode_synonym_class @
      which: new grid_mode_which_class @
    }
    @mode = @modes.single
    dom.grid.setAttribute "data-mode", @mode.name
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
    for id in Object.keys @files
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
  hooks:
    change: null
    set_grid_option: null
  selection: 0
  mode_option_fields: []
  make_option_fields: (mode) ->
    return null unless mode.option_fields
    mode.option_fields.map (field_config) =>
      name = field_config[0]
      type = field_config[1]
      value = mode.options[name]
      if type == "boolean"
        a = crel "input", {type: "checkbox"}
        a.checked = "checked" if value
        a.addEventListener "change", (event) =>
          mode.set_option name, event.target.checked
          @hooks.set_grid_option && @hooks.set_grid_option name
      else if type == "integer"
        a = crel "input", {type: "number", value, placeholder: name, min: 0, step: 1}
        a.addEventListener "change", (event) =>
          mode.set_option name, parseInt(event.target.value)
          @hooks.set_grid_option && @hooks.set_grid_option name
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
  update_options: (grid_modes) ->
    dom.options_form.innerHTML = ""
    for name, i in @modes
      mode = grid_modes[name]
      option_fields = @make_option_fields mode
      if option_fields
        div = crel "div", option_fields
        @mode_option_fields[i] = div
        dom.options_form.appendChild div
      else @mode_option_fields[i] = null
    @show_selected_option_fields()
  constructor: (modes) ->
    @modes = Object.keys modes
    for name, i in @modes
      dom.modes.appendChild new Option name, i
    dom.modes.addEventListener "change", (event) =>
      @hide_selected_option_fields()
      @selection = parseInt event.target.value
      @hooks.change && @hooks.change()
      @show_selected_option_fields()
    dom.options.addEventListener "click", (event) -> dom.options_form.classList.toggle "hidden"

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
    @mode_select.hooks.set_grid_option = => @save()
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
    @mode_select.update_options @grid.modes

app = new app_class()
