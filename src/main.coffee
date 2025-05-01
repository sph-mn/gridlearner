dom = {}; (dom[a.id] = a for a in document.querySelectorAll("[id]"))
localStorageSetJsonItem = (key, value) -> localStorage.setItem key, JSON.stringify(value)
object_array_add = (object, key, value) -> (object[key] ?= []).push value
random_element = (a) -> a[Math.random() * a.length // 1]
random_insert = (a, b) -> a.splice Math.random() * a.length // 1, 0, b
locale_sort = (a) -> a.slice().sort (a, b) -> a.localeCompare b
locale_sort_index = (a, i) -> a.slice().sort (a, b) -> a[i].localeCompare b[i]
remove_extension = (filename) -> filename.substring 0, filename.lastIndexOf(".")
object_integer_keys = (a) -> Object.keys(a).map (a) -> parseInt a

interleave = (a, b) ->
  c = []
  max_length = Math.max a.length, b.length
  for i in [0...max_length]
    c.push a[i] if i < a.length
    c.push b[i] if i < b.length
  c

localStorageGetJsonItem = (key) ->
  a = localStorage.getItem(key)
  if a then JSON.parse(a) else null

randomize = (a) ->
  return a unless a.length
  for i in [a.length - 1..0]
    i2 = (Math.random() * (i + 1)) // 1
    [a[i], a[i2]] = [a[i2], a[i]]
  a

debounce = (func, wait, immediate = false) ->
  timeout = null
  ->
    context = @
    args = arguments
    later = ->
      timeout = null
      func.apply context, args unless immediate
    call_now = immediate and not timeout
    clearTimeout timeout
    timeout = setTimeout later, wait
    func.apply context, args if call_now

class grid_mode
  constructor: (grid) -> @grid = grid

class grid_mode_flip_class extends grid_mode
  name: "flip"
  pointerdown: (cell) -> cell.classList.toggle "selected"
  pointerup: (cell) ->
  update: ->
    @grid.dom_clear()
    for a, index in @grid.data
      question = crel "div", a[0]
      answer = crel "div", a.slice(1).join(" ")
      cell = crel "div", {class: "cell", id: "q#{index}"}, question, answer
      @grid.add_cell_states cell
      @grid.dom_main.appendChild cell

class grid_mode_pair_class extends grid_mode
  name: "pair"
  selection: null
  set_option: (key, value) ->
    @options[key] = value
    @update()
  pointerdown: (cell) ->
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
  pointerup: ->
  update: () ->
    @selection = null
    @grid.dom_clear()
    questions = []
    answers = []
    for a, i in @grid.data
      [question, answer] = @grid.get_data_sides a
      questions.push [question, "q#{i}"]
      answers.push [answer, "a#{i}"]
    data = interleave locale_sort_index(questions, 0), locale_sort_index(answers, 0)
    children = []
    for a in data
      cell = crel "div", {class: "cell", id: a[1]}, crel("div", a[0])
      @grid.add_cell_states cell
      @grid.dom_main.appendChild cell

class grid_mode_synonym_class extends grid_mode
  name: "synonym"
  selection: null
  pointerup: ->
  pointerdown: (cell) ->
    if cell.classList.contains "completed"
      if @selection && @selection.classList.contains "last"
        a = @grid.cell_data @selection
        b = @grid.cell_data cell
        answer = a[1]
        if b[1] == answer
          @grid.class_set.completed @selection
          @grid.class_set.not_selected @selection
          object_array_add @completed, answer, @selection
          @selection = null
        return
      a = @grid.cell_data cell
      for b in @completed[a[1]]
        @grid.pulsate b unless b == cell
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
    answer = a[1]
    if b[1] == answer
      @grid.class_set.completed @selection
      @grid.class_set.not_selected @selection
      @grid.class_set.completed cell
      cell.title = answer
      object_array_add @completed, answer, @selection
      object_array_add @completed, answer, cell
      remaining = @odd_remaining[answer]
      if remaining
        remaining.delete @grid.cell_data_index @selection
        remaining.delete @grid.cell_data_index cell
        if 1 == remaining.size
          index = remaining.values().next().value
          @odd_remaining[a[1]] = null
          document.getElementById("q#{index}").classList.add "last"
      @selection = null
      return
    @grid.pulsate cell
  update: ->
    @selection = null
    @grid.dom_clear()
    groups = {}
    for a, i in @grid.data
      object_array_add groups, a[1], [a, i]
    @completed = {}
    @odd_remaining = {}
    data = []
    for answer, group of groups
      continue if 2 > group.length
      data = data.concat group
      if group.length & 1
        @odd_remaining[answer] = new Set(a[1] for a in group)
    unless data.length then @grid.dom_main.innerHTML = "no synonyms found"
    else
      for a in randomize data
        [a, i] = a
        [question, answer] = @grid.get_data_sides a
        cell = crel "div", {class: "cell", id: "q#{i}"}, crel("div", question)
        @grid.add_cell_states cell
        @grid.dom_main.appendChild cell

class grid_mode_choice_class extends grid_mode
  name: "choice"
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
    attempts = 0
    while result.length < n and attempts < (n * 3)
      attempts += 1
      index = Math.floor Math.random() * data.length
      answer = data[index]
      unless answer[1].length != a[1].length or answer[1] == a[1] or answers_set.has answer[1]
        result.push [index, answer]
        answers_set.add answer[1]
    insert_index = Math.floor Math.random() * (result.length + 1)
    result.splice insert_index, 0, [i, a]
    result
  pointerup: (cell) ->
    return if cell.parentNode.children[0] == cell
    return if cell.parentNode.classList.contains "completed"
    if "a" == cell.id[0]
      @grid.class_set.completed cell.parentNode
    else
      @grid.pulsate cell
      mistakes = cell.parentNode.getAttribute "data-mistakes"
      if mistakes then mistakes = Math.min 4, parseInt(mistakes) + 1
      else mistakes = 1
      cell.parentNode.setAttribute "data-mistakes", mistakes
  pointerdown: (cell) ->
  update: ->
    @grid.dom_clear()
    for a, i in randomize @grid.data
      answers = @random_answers @grid.data, a, i, @options.choices - 1
      continue unless answers.length
      answers = for b in answers
        answer = @grid.get_data_sides(b[1], @options.reverse)[1]
        answer = crel "div", {class: "cell"}, crel("div", answer)
        if i == b[0]
          answer.id = "a#{i}"
          @grid.add_cell_states answer
        answer
      question = @grid.get_data_sides(a, @options.reverse)[0]
      question = crel "div", {class: "cell"}, crel("div", question)
      group = crel "span", {"id": "q#{i}"}, question, answers
      @grid.add_cell_states group
      @grid.dom_main.appendChild group

class grid_mode_group_class extends grid_mode
  name: "group"
  options: exhaustive: false
  option_fields: [
    ["exhaustive", "boolean"]
  ]
  set_option: (key, value) ->
    @options[key] = value
    @update()
  pointerdown: (cell) ->
  pointerup_long: (cell) ->
    cell.classList.toggle "completed"
    @update_stats()
  pointerup: (cell) ->
    return if cell.classList.contains "empty"
    views =+ (cell.getAttribute "data-views" or "0") + 1
    cell.setAttribute "data-views", views
    cell.setAttribute "data-last-tapped", Date.now()
    cell.classList.toggle "selected"
  prepare_maps: (data, canonical = true) ->
    children_map      = {}
    pinyin_map        = {}
    parent_candidates = {}
    direct_counts     = {}
    for [p, c, py] in data when c?
      p = null unless p? and p.length
      pinyin_map[c] = py if py?
      pinyin_map[p] ?= "" if p?
      if canonical
        parent_candidates[c] ?= new Set()
        parent_candidates[c].add p if p?
      else
        if p?
          children_map[p] ?= new Set()
          children_map[p].add c
    if canonical
      for c, cands_set of parent_candidates
        cands = Array.from cands_set
        continue unless cands.length
        chosen = cands.reduce (best, cand) ->
          if not best? then cand else if (direct_counts[cand] or 0) < (direct_counts[best] or 0) then cand else best
        children_map[chosen] ?= new Set()
        unless children_map[chosen].has c
          children_map[chosen].add c
          direct_counts[chosen] = (direct_counts[chosen] or 0) + 1
    for p, set of children_map
      children_map[p] = Array.from set
    size_map = {}
    get_size = (ch) ->
      return size_map[ch] if size_map[ch]?
      size_map[ch] = 1 + ((children_map[ch] or []).reduce ((s, cc) -> s + get_size cc), 0)
    for p in Object.keys children_map
      get_size p
    parents     = new Set Object.keys children_map
    descendants = new Set()
    gather = (ch) ->
      for cc in children_map[ch] or []
        unless descendants.has cc
          descendants.add cc
          gather cc
    for p in Object.keys children_map
      gather p
    roots = Array.from(new Set(Object.keys pinyin_map)).filter (x) -> x and not descendants.has x
    {children_map, pinyin_map, roots, size_map}
  render_node: (grid, wrapper, maps, ch, parent = "") ->
    {children_map, pinyin_map, size_map} = maps
    q = crel "div", ch
    a = crel "div", pinyin_map[ch] or ""
    cls = "cell"
    cls += " group-start" if children_map?[ch]
    cls += " empty" unless pinyin_map[ch]
    attrs =
      class: cls
      "data-char": ch
    attrs["data-parent"] = parent if parent
    cell = crel "div", attrs, q, a
    grid.add_cell_states cell
    wrapper.appendChild cell
    last_elem = cell
    if children_map?[ch]
      leaves = children_map[ch].filter (cc) -> not children_map?[cc]
      groups = children_map[ch].filter (cc) -> children_map?[cc]
      groups.sort (x, y) -> size_map[y] - size_map[x]
      for cch in leaves.concat groups
        last_elem = @render_node grid, wrapper, maps, cch, ch
      last_elem.classList.add "group-end"
    last_elem
  update_stats: ->
    group_count = @grid.dom_main.querySelectorAll(".group").length
    cell_count = @grid.dom_main.querySelectorAll(".cell").length
    cell_completed_count = @grid.dom_main.querySelectorAll(".cell.completed").length
    completed_groups = Array.from(@grid.dom_main.querySelectorAll(".group")).filter (g) ->
      g.querySelectorAll(".cell").length > 0 and g.querySelectorAll(".cell:not(.completed)").length is 0
    @grid.dom_header.innerHTML = "cards #{cell_completed_count}/#{cell_count}, groups #{completed_groups.length}/#{group_count}"
  update: ->
    @grid.dom_clear()
    maps = @prepare_maps @grid.data, !@options.exhaustive
    for root in maps.roots
      w = crel "div",
        class: "group"
        "data-root": root
      @grid.dom_main.appendChild w
      @render_node @grid, w, maps, root
    @update_stats()

class grid_class
  # this represents the state and UI of the cell area.
  data: []
  font_size: 10
  class_set: {}
  cell_state_classes: ["hidden", "selected", "completed", "last", "invisible", "seen"]
  cell_state_attributes: ["data-mistakes", "data-views", "data-last-tapped"]
  pointerdown_selection: null
  reset: ->
    @cell_states = {}
    @mode.update()
  dom_header: dom.grid.children[0]
  dom_main: dom.grid.children[1]
  dom_footer: dom.grid.children[2]
  dom_clear: (a) ->
    @dom_main.innerHTML = ""
    @dom_footer.innerHTML = ""
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
    @cell_states = {}
  set_config: (a) ->
    @set_mode @modes[a.mode] if a.mode && @modes[a.mode]
    @mode.options = a.mode_options if a.mode_options
    @cell_states = a.cell_states if a.cell_states
    if a.font_size
      @font_size = a.font_size
      @update_font_size()
  update: -> @mode.update()
  pulsate: (a) ->
    a.classList.remove "pulsate"
    a.classList.add "pulsate"
    a.addEventListener "animationend", (-> a.classList.remove "pulsate"), once: true
  update_font_size: -> dom.grid.style.fontSize = "#{@font_size / 10}em"
  cell_data: (a) -> @data[parseInt a.id.substring(1), 10]
  cell_data_index: (a) -> parseInt a.id.substring(1), 10
  for_each_cell: (f) ->
    for section in dom.grid.children
      continue unless section.children.length
      first_group_or_cell = section.children[0]
      switch first_group_or_cell.tagName
        when "SPAN"
          for group in section.children
            f group
            f cell for cell in group.children
        when "DIV" then f cell for cell in section.children
  add_cell_states: (cell) ->
    state = @cell_states[cell.id]
    return unless state
    if state.class
      cell.classList.add b for b in state.class
      delete state.class
    cell.setAttribute name, value for name, value of state
  get_cell_states: ->
    states = {}
    @for_each_cell (cell) =>
      state = {}
      state_classes = []
      for name in @cell_state_classes
        state_classes.push name if cell.classList.contains name
      state.class = state_classes if state_classes.length
      for name in @cell_state_attributes
        value = cell.getAttribute name
        state[name] = value if value
      states[cell.id] = state if Object.keys(state).length
    states
  modify_font_size: (a) ->
    @font_size += a
    @update_font_size()
  get_data_sides: (a, is_reverse) ->
    b = a[0]
    c = a[1]
    if is_reverse then [c, b] else [b, c]
  get_cell_from_event_target: (a) ->
    while a and a.parentNode
      return a if a.classList.contains "cell"
      a = a.parentNode
    false
  add_events: ->
    pointerdown = (event) =>
      cell = @get_cell_from_event_target event.target
      return unless cell
      @pointerdown_selection = cell
      @mode.pointerdown cell if event.pointerType == "mouse"
      @longtap_detector.detect "start"
    pointerup = (event) =>
      return unless @pointerdown_selection
      cell = @get_cell_from_event_target event.target
      return unless cell
      if @longtap_detector.detect "end"
        if event.pointerType == "mouse" then @mode.pointerup_long cell
        else if event.pointerType == "touch"
          if @pointerdown_selection == cell
            @mode.pointerdown_long cell
            @mode.pointerup_long cell
      else
        if event.pointerType == "mouse" then @mode.pointerup cell
        else if event.pointerType == "touch"
          if @pointerdown_selection == cell
            @mode.pointerdown cell
            @mode.pointerup cell
      @pointerdown_selection = null
    dom.grid.addEventListener "pointerdown", pointerdown
    document.body.addEventListener "pointerup", pointerup
  constructor: ->
    @longtap_detector = new longtap_detector_class 1000
    @cell_state_classes.forEach (a) =>
      @class_set[a] = (b) -> b.classList.add a
      @class_set["not_#{a}"] = (b) -> b.classList.remove a
    @modes = {
      flip: new grid_mode_flip_class @
      group: new grid_mode_group_class @
      pair: new grid_mode_pair_class @
      synonym: new grid_mode_synonym_class @
      choice: new grid_mode_choice_class @
    }
    @set_mode @modes.flip
    @add_events()
    @update_font_size()

class dropdown_class
  # a custom dropdown that works like a button in a classic menubar.
  hooks:
    click: null
    change: null
  constructor: (container, label) ->
    @container = container
    @container.classList.add "dropdown"
    @button = crel "button", label
    @options_container = crel "div", {"class": "options"}
    @button.addEventListener "click", =>
      @container.classList.toggle "open"
      @hooks.click && @hooks.click()
    document.addEventListener "click", (event) =>
      return unless @container.classList.contains "open"
      return if @container.contains event.target
      @container.classList.remove "open"
    @container.appendChild @button
    @container.appendChild @options_container
  set_selection: (value) ->
    @selection && @options[@selection]?.classList.remove "active"
    @selection = value
    @options[value].classList.add "active"
  set_options: (options) ->
    @options_container.innerHTML = ""
    @options = {}
    for a in options
      b = crel "div", a[0]
      @options[a[1]] = b
      o = @
      b.addEventListener "click", do (a) ->
        ->
          o.container.classList.remove "open"
          o.set_selection a[1]
          o.hooks.change and o.hooks.change a[1]
      @options_container.appendChild b

class file_editor_class
  # unfinished class for a possible edit mode feature
  edit: (data, name, save) ->
    # show edit area
    # user presses save&close, call save handler
    save data, name

class file_select_class
  # select, load, and persist files. this has its own storage separate from the main app.
  hooks:
    add: null
    change: null
    delete: null
    reset: null
  selection: null
  next_id: 1
  files: {}
  file_data: {}
  dropdown: new dropdown_class dom.files_container, "files"
  update: (id, data, meta) ->
    if data
      @file_data[id] = data if data
      @save_file_data id
    if meta
      @files[id] = meta
      @save()
  edit: ->
    id = @selection
    @editor.edit @file_data[id], @files[id], (data, meta) =>
      @update id, data, meta
  create: ->
    @editor.create @file_data[id], @files[id], (data, meta) =>
      @update id, data, meta
  add: (file) ->
    Papa.parse file,
      delimiter: " "
      complete: (data) =>
        data.errors.forEach (error) -> console.error error
        @files[@next_id] = name: remove_extension(file.name)
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
    unless confirm "delete file #{a.name}?"
      @dropdown.select id
      return
    delete @files[id]
    delete @file_data[id]
    ids = object_integer_keys @files
    @selection = if ids.length then ids[0] else null
    @save()
    @update_options()
    localStorage.removeItem "file_data_#{id}"
    @hooks.delete && @hooks.delete id
  reset: ->
    localStorage.removeItem "files"
    ids = object_integer_keys @files
    @files = {}
    @file_data = {}
    @selection = null
    @update_options()
    for id in ids
      localStorage.removeItem "file_data_#{id}"
    @hooks.reset && @hooks.reset()
  save: ->
    localStorageSetJsonItem "files", {files: @files, selection: @selection, next_id: @next_id}
  load: ->
    a = localStorageGetJsonItem "files"
    return unless a
    @files = a.files
    @selection = if a.selection then parseInt(a.selection) else null
    @next_id = a.next_id
    @update_options()
  save_file_data: (id) -> localStorageSetJsonItem "file_data_#{id}", @file_data[id]
  load_file_data: (id) ->
    a = localStorageGetJsonItem "file_data_#{id}"
    return unless a
    @file_data[id] = a
  update_options: ->
    options = [["add", -1]]
    #options = [["edit", -2]]
    #options = [["create", -3]]
    options = options.concat ([@files[id].name, id] for id in object_integer_keys @files)
    options.push ["delete current", -4]
    @dropdown.set_options options
    @dropdown.set_selection @selection if @selection?
  add_events: ->
    dom.file.addEventListener "change", (event) =>
      return unless event.target.files.length
      @add event.target.files[0]
    @dropdown.hooks.click = => dom.file.click() unless @selection?
    @dropdown.hooks.change = (a) =>
      if -1 == a then dom.file.click()
      else if -2 == a then @edit()
      else if -3 == a then @create()
      else if -4 == a then @delete()
      else
        @selection = a
        @load_file_data a
        @hooks.change and @hooks.change a
        return
        @save()
  constructor: ->
    @load()
    @load_file_data(@selection) if @selection?
    @update_options()
    @add_events()
  get_file: -> @files[@selection]
  get_file_data: ->
    @load_file_data[@selection]
    @file_data[@selection]

class mode_select_class
  # display a drowdown for selecting the grid mode as well as a form for the mode-specific options.
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
    @selection = @mode_names.indexOf a
    dom.modes.value = @selection
    @show_selected_option_fields()
  get_mode: -> @mode_names[@selection]
  hide_selected_option_fields: -> @mode_option_fields[@selection]?.classList.remove "show"
  show_selected_option_fields: ->
    selected_option_fields = @mode_option_fields[@selection]
    if selected_option_fields then selected_option_fields.classList.add "show"
    else dom.options.classList.add "hidden"
  update_options: ->
    dom.mode_options.innerHTML = ""
    for name, i in @mode_names
      mode = @modes[name]
      option_fields = @make_option_fields mode
      if option_fields
        div = crel "ul", option_fields
        @mode_option_fields[i] = div
        dom.mode_options.appendChild div
      else @mode_option_fields[i] = null
    @show_selected_option_fields()
  constructor: (modes) ->
    @modes = modes
    @mode_names = Object.keys modes
    for name, i in @mode_names
      dom.modes.appendChild new Option name.replace(/_/g, " "), i
    dom.modes.addEventListener "change", (event) =>
      @hide_selected_option_fields()
      @selection = parseInt event.target.value
      @hooks.change && @hooks.change()
      @show_selected_option_fields()
    dom.options_button.addEventListener "click", (event) -> dom.menu_content.classList.toggle "show_options"

class longtap_detector_class
  touch_start_time: 0
  constructor: (threshold_duration) ->
    @threshold_duration = if threshold_duration? then threshold_duration else 500
  detect: (event_type) ->
    if event_type == "start"
      @touch_start_time = Date.now()
      false
    else if event_type == "end"
      touch_end_time = Date.now()
      duration = touch_end_time - @touch_start_time
      if duration >= @threshold_duration then true
      else false
    else false

class app_class
  configs: {}
  add_events: ->
    dom.save.addEventListener "click", (event) => @save()
    reset_debounced = debounce @grid.reset, 250
    dom.reset.addEventListener "pointerdown", (event) => @longtap_detector.detect "start"
    dom.reset.addEventListener "pointerup", (event) =>
      if @longtap_detector.detect "end" then confirm("reset all?") && @reset()
      else @grid.reset()
    dom.font_increase.addEventListener "click", (event) => @grid.modify_font_size 2
    dom.font_decrease.addEventListener "click", (event) => @grid.modify_font_size -2
  reset: ->
    localStorage.removeItem "app"
    @file_select.reset()
  save: ->
    @configs[@file_select.selection] = @grid.get_config() if @file_select.selection?
    localStorageSetJsonItem "app", configs: @configs
  load: ->
    a = localStorageGetJsonItem "app"
    return unless a
    @configs = a.configs
    if @file_select.selection?
      config = a.configs[@file_select.selection]
      return unless config
      @mode_select.set_mode config.mode
      @grid.set_config config
      @grid.data = @file_select.get_file_data()
      @grid.update()
  load_preset: (data) ->
    return if localStorage.hasOwnProperty "app"
    localStorageSetJsonItem a, b for a, b of data
  constructor: (data) ->
    @load_preset data if data
    @file_select = new file_select_class
    @grid = new grid_class
    @longtap_detector = new longtap_detector_class 2000
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
      return
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
    @file_select.hooks.reset = () => location.reload()
    @add_events()
    @load()
    @mode_select.update_options()

new app_class(__data__)
