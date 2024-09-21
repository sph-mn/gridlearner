dom = {}; (dom[a.id] = a for a in document.querySelectorAll("[id]"))
localStorageSetJsonItem = (key, value) -> localStorage.setItem key, JSON.stringify(value)
object_array_add = (object, key, value) -> (object[key] ?= []).push value
random_element = (a) -> a[Math.random() * a.length // 1]
random_insert = (a, b) -> a.splice Math.random() * a.length // 1, 0, b
locale_sort = (a) -> a.slice().sort (a, b) -> a.localeCompare b
locale_sort_index = (a, i) -> a.slice().sort (a, b) -> a[i].localeCompare b[i]

localStorageGetJsonItem = (key) ->
  a = localStorage.getItem(key)
  if a then JSON.parse(a) else null

randomize = (a) ->
  return a unless a.length
  for i in [a.length - 1..0]
    i2 = (Math.random() * (i + 1)) // 1
    [a[i], a[i2]] = [a[i2], a[i]]
  a

class grid_mode
  constructor: (grid) -> @grid = grid

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
  mousedown: (cell) ->
    return if @options.click_to_remove
    @grid.class_set.selected cell
  mouseup: (cell) ->
    if @options.click_to_remove then @grid.class_set.hidden cell
    else @options.hold_to_flip and @grid.class_set.not_selected cell
  update: ->
    dom.grid.innerHTML = ""
    for a, index in @grid.data
      question = crel "div", a[0]
      answer = crel "div", a.slice(1).join(" ")
      dom.grid.appendChild crel "div", {"id": "q#{index}"}, question, answer

class grid_mode_pair_class extends grid_mode
  name: "pair"
  selection: null
  options:
    mix: false
    sort: false
  option_fields: [
    ["mix", "boolean"]
    ["sort", "boolean"]
  ]
  set_option: (key, value) ->
    @options[key] = value
    @update()
  mousedown: (cell) ->
    if cell.classList.contains "completed"
      id = (if "q" == cell.id[0] then "a" else "q") + cell.id.substring(1)
      @grid.pulsate document.getElementById id
      return
    unless @selection
      @selection = cell
      @grid.class_set.selected cell
      return
    if @selection == cell
      @grid.class_set.not_selected cell
      @selection = null
      return
    if @selection.id[0] == cell.id[0]
      @grid.pulsate cell
      return
    a = @grid.cell_data @selection
    b = @grid.cell_data cell
    if a[1] == b[1]
      @grid.class_set.completed @selection
      @grid.class_set.not_selected @selection
      @grid.class_set.completed cell
      @selection = null
      return
    @grid.pulsate cell
  mouseup: ->
  update: ->
    @selection = null
    dom.grid.innerHTML = ""
    questions = []
    answers = []
    for a, i in @grid.data
      [question, answer] = @grid.get_data_sides a
      questions.push [question, "q#{i}"]
      answers.push [answer, "a#{i}"]
    if @options.mix
      data = randomize questions.concat answers
    else if @options.sort
      data = locale_sort_index(questions, 0).concat locale_sort_index(answers, 0)
    else data = randomize(questions).concat randomize answers
    children = []
    for a in data
      dom.grid.appendChild crel("div", {id: a[1]}, crel("div", a[0]))

class grid_mode_synonym_class extends grid_mode
  name: "synonym"
  selection: null
  show_answer: (cell) ->
    cell
  update: ->
    @selection = null
    dom.grid.innerHTML = ""
    groups = {}
    for a, i in @grid.data
      object_array_add groups, a[1], [a, i]
    @odd = {}
    data = []
    for answer, group of groups
      continue if 2 > group.length
      data = data.concat group
      @odd[answer] = new Set(a[1] for a in group) if group.length & 1
    for a in randomize data
      [a, i] = a
      [question, answer] = @grid.get_data_sides a
      dom.grid.appendChild crel("div", {id: "q#{i}"}, crel("div", question))
  mouseup: ->
  mousedown: (cell) ->
    if cell.classList.contains "completed"
      if @selection && @selection.classList.contains "last"
        a = @grid.cell_data @selection
        b = @grid.cell_data cell
        if a[1] == b[1]
          @grid.class_set.completed @selection
          @grid.class_set.not_selected @selection
          @selection = null
        return
      @grid.show_hint cell.title
      return
    unless @selection
      @selection = cell
      @grid.class_set.selected cell
      a = @grid.cell_data cell
      cell.title = a[1]
      @grid.show_hint cell.title
      return
    if @selection == cell
      @grid.class_set.not_selected cell
      cell.title = ""
      @selection = null
      return
    a = @grid.cell_data @selection
    b = @grid.cell_data cell
    if a[1] == b[1]
      @grid.class_set.completed @selection
      @grid.class_set.not_selected @selection
      @grid.class_set.completed cell
      cell.title = @selection.title
      remaining = @odd[a[1]]
      if remaining
        remaining.delete @grid.cell_data_index @selection
        remaining.delete @grid.cell_data_index cell
        if 1 == remaining.size
          index = remaining.values().next().value
          @odd[a[1]] = null
          document.getElementById("q#{index}").classList.add "last"
      @selection = null
      return
    @grid.pulsate cell

class grid_mode_which_class extends grid_mode
  name: "which"
  options: choices: 5
  option_fields: [
    ["choices", "integer"]
    ["reverse", "boolean"]
  ]
  set_option: (key, value) ->
    @options[key] = value
    @update()
  random_answers: (data, a, i, n) ->
    result = []
    answers_set = new Set()
    while result.length < n
      index = Math.floor Math.random() * data.length
      answer = data[index]
      unless answer == a or answers_set.has answer
        result.push [index, answer]
        answers_set.add answer
    insert_index = Math.floor Math.random() * (n + 1)
    result.splice insert_index, 0, [i, a]
    result
  mouseup: ->
  mousedown: (cell) ->
    group = cell.parentNode
    console.log group
  update: ->
    dom.grid.innerHTML = ""
    for a, i in @grid.data
      answers = @random_answers @grid.data, a, i, @options.choices - 1
      answers = for b in answers
        answer = @grid.get_data_sides(b[1], @options.reverse)[1]
        crel "div", {id: "a#{b[0]}"}, crel("div", answer)
      question = @grid.get_data_sides(a, @options.reverse)[0]
      question = crel "div", {"id": "q#{i}"}, crel("div", question)
      group = crel "span", question, answers
      dom.grid.appendChild group

class grid_class
  data: []
  font_size: 10
  class_set: {}
  cell_state_names: ["hidden", "selected", "completed", "invisible", "last"]
  mousedown_selection: null
  show_hint: (a) ->
    dom.hint.innerHTML = a
    @class_set.not_invisible dom.hint
    clearTimeout @hint_timeout if @hint_timeout
    @hint_timeout = setTimeout (=> @class_set.invisible dom.hint), 1000
  get_config: ->
    {
      mode: @mode.name
      mode_options: @mode.options
      font_size: @font_size
      cell_states: @get_cell_states()
    }
  set_mode: (a) ->
    @mode = a
    dom.grid.setAttribute "data-mode", a.name
  set_config: (a) ->
    @set_mode @modes[a.mode] if a.mode
    @mode.options = a.mode_options if a.mode_options
    @cell_states = a.cell_states if a.cell_states
    if a.font_size
      @font_size = a.font_size
      @update_font_size()
  update: ->
    @mode.update()
    @set_cell_states @cell_states
  pulsate: (a) ->
    a.classList.remove "pulsate"
    a.classList.add "pulsate"
    a.addEventListener "animationend", (-> a.classList.remove "pulsate"), once: true
  update_font_size: -> dom.grid.style.fontSize = "#{@font_size / 10}em"
  cell_data: (a) -> @data[parseInt a.id.substring(1), 10]
  cell_data_index: (a) -> parseInt a.id.substring(1), 10
  for_each_cell: (f) ->
    cells = dom.grid.children
    return unless cells.length
    if "SPAN" == cells[0].tagName
      for group in cells
        f a for a in group
    else f a for a in cells
  set_cell_states: (states) ->
    @for_each_cell (cell) ->
      id = cell.id
      classes = states[id]
      return unless classes
      cell.classList.add b for b in classes
  get_cell_states: ->
    cells = dom.grid.children
    return {} unless cells.length
    result = {}
    @for_each_cell (cell) ->
      classes = cell.classList
      state_classes = []
      if classes.contains "hidden" then state_classes.push "hidden"
      if classes.contains "selected" then state_classes.push "selected"
      if classes.contains "completed" then state_classes.push "completed"
      if state_classes.length then result[cell.id] = state_classes
    result
  modify_font_size: (a) ->
    @font_size += a
    @update_font_size()
  get_data_sides: (a, is_reverse) ->
    b = a[0]
    c = a[1]
    if is_reverse then [c, b] else [b, c]
  add_events: ->
    mousedown = (event) =>
      cell = event.target.closest "#grid > div,#grid > span > div"
      return unless cell
      @mousedown_selection = cell
      @mode.mousedown @mousedown_selection
    mouseup = (event) =>
      return unless @mousedown_selection
      @mode.mouseup @mousedown_selection
      @mousedown_selection = null
    dom.grid.addEventListener "mousedown", mousedown
    document.body.addEventListener "mouseup", mouseup
    document.body.addEventListener "touchend", (event) ->
      mousedown event
      mouseup event
  constructor: ->
    @cell_state_names.forEach (a) =>
      @class_set[a] = (b) -> b.classList.add a
      @class_set["not_#{a}"] = (b) -> b.classList.remove a
    @modes = {
      single: new grid_mode_single_class @
      pair: new grid_mode_pair_class @
      synonym: new grid_mode_synonym_class @
      which: new grid_mode_which_class @
    }
    @set_mode @modes.single
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
  save: ->
    localStorageSetJsonItem "files", {files: @files, selection: @selection, next_id: @next_id}
  load: ->
    a = localStorageGetJsonItem "files"
    return unless a
    @files = a.files
    @selection = parseInt a.selection, 10
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
      id = parseInt id
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
      @selection = parseInt event.target.value
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
      crel "li", crel("label", name, a)
  set_mode: (a) ->
    @hide_selected_option_fields()
    @selection = @modes.indexOf a
    dom.modes.value = @selection
    @show_selected_option_fields()
  get_mode: -> @modes[@selection]
  hide_selected_option_fields: -> @mode_option_fields[@selection]?.classList.remove "show"
  show_selected_option_fields: ->
    selected_option_fields = @mode_option_fields[@selection]
    if selected_option_fields then selected_option_fields.classList.add "show"
    else dom.options.classList.add "hidden"
  update_options: (grid_modes) ->
    dom.mode_options.innerHTML = ""
    for name, i in @modes
      mode = grid_modes[name]
      option_fields = @make_option_fields mode
      if option_fields
        div = crel "ul", option_fields
        @mode_option_fields[i] = div
        dom.mode_options.appendChild div
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
    dom.options_button.addEventListener "click", (event) -> dom.options.classList.toggle "hidden"

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
    dom.menu_button.addEventListener "click", =>
      console.log "toggle"
      dom.menu.classList.toggle "show_content"
    dom.homepage.addEventListener "click", -> window.open dom.homepage.getAttribute("href"), "_blank"
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
      @grid.set_mode @grid.modes[mode]
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
