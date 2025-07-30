dom = {}; (dom[a.id] = a for a in document.querySelectorAll("[id]"))
localStorageSetJsonItem = (key, value) -> localStorage.setItem key, JSON.stringify(value)
object_array_add = (object, key, value) -> (object[key] ?= []).push value
random_element = (a) -> a[Math.random() * a.length // 1]
random_insert = (a, b) -> a.splice Math.random() * a.length // 1, 0, b
locale_sort = (a) -> a.slice().sort (a, b) -> a.localeCompare b
locale_sort_index = (a, i) -> a.slice().sort (a, b) -> a[i].localeCompare b[i]
remove_extension = (filename) -> filename.substring 0, filename.lastIndexOf(".")
object_integer_keys = (a) -> Object.keys(a).map (a) -> parseInt a
split_chars = (a) -> [...a]
random_color = -> "#" + Math.floor(Math.random() * 0xffffff).toString(16).padStart(6, "0")

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
  b = a.slice()
  for i in [b.length - 1..0]
    i2 = (Math.random() * (i + 1)) // 1
    [b[i], b[i2]] = [b[i2], b[i]]
  b

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

class emitter_class
  constructor: -> @listeners = {}
  on:  (evt, fn) -> (@listeners[evt] ?= []).push fn
  off: (evt, fn) -> @listeners[evt] = (@listeners[evt] or []).filter (x) -> x != fn
  emit: (evt, args...) -> (fn args... for fn in @listeners[evt] or [])

class store_class extends emitter_class
  state:
    configs: {}
    selection: null
  commit: (op) ->
    @state = op @state
    @emit "change", @state
  persist: -> localStorageSetJsonItem "app", @state
  load: ->
    a = localStorageGetJsonItem "app"
    @state = a if a?

class grid_mode
  constructor: (grid) -> @grid = grid
  pointerdown: (cell) ->
  pointerup: (cell) ->
  pointerdown_long: (cell) ->
  pointerup_long: (cell) ->

class grid_mode_flip_class extends grid_mode
  name: "flip"
  base_interval_ms: 2000 * 86400
  max_interval_ms: 1000 * 365 * 86400
  constructor: (grid) ->
    super grid
    @timer = null
    @timer_cell = null
  pointerdown: (cell) ->
    if cell.classList.contains("completed") && cell.classList.contains("selected")
      @cell_reset cell
      cell.classList.remove "selected"
      return
    cell.classList.add "selected"
    needs_affirm = not cell.hasAttribute("data-last-affirmed") or cell.classList.contains "due"
    @cell_affirm cell if needs_affirm
    id = cell.id
    if @timer? and @timer_cell is id
      clearTimeout @timer
    @timer_cell = id
    @timer = setTimeout =>
      @grid.emit "update"
      @timer = null
      @timer_cell = null
    , 4000
  pointerdown_long: (cell) ->
  cell_affirm: (cell) ->
    now = Date.now()
    interval = parseInt(cell.getAttribute("data-interval") or @base_interval_ms)
    interval = Math.min interval * 2, @max_interval_ms
    cell.setAttribute "data-interval", interval
    cell.setAttribute "data-last-affirmed", now
    cell.classList.add "completed"
    cell.classList.remove "due"
  cell_reset: (cell) ->
    cell.removeAttribute "data-interval"
    cell.removeAttribute "data-last-affirmed"
    cell.classList.remove "completed"
    cell.classList.remove "due"
  refresh_due: ->
    now = Date.now()
    for cell in @grid.dom_main.querySelectorAll ".cell.completed"
      last = + (cell.getAttribute "data-last-affirmed" or 0)
      interval = + (cell.getAttribute "data-interval" or @base_interval_ms)
      overdue = last and (now - last > interval)
      cell.classList.toggle "due", overdue
      if overdue
        cell.classList.remove "selected"
  update: ->
    for a, index in @grid.data
      question = crel "div", a[0]
      answer = crel "div", a.slice(1).join " "
      cell = crel "div", {class: "cell", id: "q#{index}"}, question, answer
      @grid.add_cell_states cell
      @grid.dom_main.appendChild cell
    @refresh_due()

class grid_mode_pair_class extends grid_mode
  name: "pair"
  selection: null
  set_option: (key, value) ->
    @options[key] = value
    @update()
    @grid.emit "update"
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
      @grid.emit "update"
      return
    @grid.pulsate cell
  pointerup: ->
  update: ->
    @selection = null
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
          g = parseInt @selection.getAttribute "data-group"
          @selection.style.borderTopColor = @group_colors[g]
          @selection = null
          @update_stats()
          @grid.emit "update"
        return
      a = @grid.cell_data cell
      for b in @completed[a[1]]
        @grid.pulsate b unless b == cell
      @grid.show_hint cell.getAttribute "data-title"
      return
    unless @selection
      @selection = cell
      @grid.class_set.selected cell
      a = @grid.cell_data cell
      @grid.show_hint cell.getAttribute "data-title"
      return
    if @selection == cell
      @grid.class_set.not_selected cell
      @selection = null
      return
    a = @grid.cell_data @selection
    b = @grid.cell_data cell
    answer = a[1]
    if b[1] == answer
      @grid.class_set.completed @selection
      @grid.class_set.not_selected @selection
      @grid.class_set.completed cell
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
      g = parseInt @selection.getAttribute "data-group"
      @selection.style.borderTopColor = @group_colors[g]
      cell.style.borderTopColor = @group_colors[g]
      @selection = null
      @update_stats()
      @grid.emit "update"
      return
    @selection.setAttribute "data-mistakes", 1 + parseInt(@selection.getAttribute("data-mistakes") || 0)
    @grid.pulsate cell
  update_stats: ->
    cells = Array.from @grid.dom_main.querySelectorAll ".cell"
    completed_cells = cells.filter (a) -> a.classList.contains "completed"
    mistakes = cells.reduce ((m, a) -> m + parseInt (a.getAttribute("data-mistakes") || 0)), 0
    @grid.dom_header.innerHTML = "completed #{completed_cells.length}/#{cells.length}, mistakes #{mistakes}"
    @stats = {total: cells.length, completed: completed_cells.length, mistakes: mistakes}
  update: ->
    @selection = null
    groups = {}
    object_array_add groups, a[1], [a, i] for a, i in @grid.data
    @completed = {}
    @odd_remaining = {}
    @group_colors = {}
    data = []
    group_index = 0
    for answer, group of groups
      continue if 2 > group.length
      for item in group
        item.push group_index
        data.push item
      @group_colors[group_index] = random_color()
      if group.length & 1
        @odd_remaining[answer] = new Set(a[1] for a in group)
      group_index += 1
    unless data.length then @grid.dom_main.innerHTML = "no synonyms found"
    else
      for [a, i, g] in randomize data
        [question, answer] = @grid.get_data_sides a
        cell = crel "div", {class: "cell", id: "q#{i}", "data-group": g, "data-title": answer}, crel("div", question)
        @grid.add_cell_states cell
        if cell.classList.contains "completed"
          cell.style.borderTopColor = @group_colors[g]
          object_array_add @completed, answer, cell
        @grid.dom_main.appendChild cell
    @update_stats()

class grid_mode_choice_class extends grid_mode
  name: "choice"
  options:
    choices: 5
    reverse: false
    tries: 2
  option_fields: [
    ["choices", "integer"]
    ["reverse", "boolean"]
    ["tries", "integer"]
  ]
  set_option: (key, value) ->
    @options[key] = value
    @update()
    @grid.emit "update"
  stats:
    total: 0
    completed: 0
    failed: 0
    mistakes: 0
  random_answers: (data, a, i, n) ->
    result = []
    answers_set = new Set()
    attempts = 0
    while result.length < n and attempts < (n * 3)
      attempts += 1
      index = Math.floor( Math.random() * data.length )
      entry = data[index]
      unless entry[1] == a[1] or answers_set.has entry[1]
        result.push [index, entry]
        answers_set.add entry[1]
    insert_at = Math.floor Math.random() * (result.length + 1)
    result.splice insert_at, 0, [i, a]
    result
  update_stats: ->
    groups = Array.from @grid.dom_main.querySelectorAll ".group"
    completed_groups = groups.filter (a) -> a.classList.contains "completed"
    failed_groups = groups.filter (a) -> a.classList.contains "failed"
    mistakes = groups.reduce ((m, a) -> m + parseInt (a.getAttribute("data-mistakes") || 0)), 0
    @grid.dom_header.innerHTML = "completed #{completed_groups.length}/#{groups.length}, failed #{failed_groups.length}, mistakes #{mistakes}"
    @stats = {total: groups.length, completed: completed_groups.length, failed: failed_groups.length, mistakes: mistakes}
  pointerup: (cell) ->
    return if cell.parentNode.children[0] == cell
    return if cell.parentNode.classList.contains "completed"
    if "a" == cell.id[0]
      @grid.class_set.completed cell.parentNode
      @grid.emit "update"
      @update_stats()
    else
      @grid.pulsate cell
      mistakes = parseInt(cell.parentNode.getAttribute("data-mistakes") or "0") + 1
      if mistakes >= @options.tries
        cell.parentNode.setAttribute "data-mistakes", @options.tries
        cell.parentNode.classList.add "failed"
        @grid.class_set.completed cell.parentNode
        @grid.emit "update"
        @update_stats()
      else
        cell.parentNode.setAttribute "data-mistakes", mistakes
    if @stats.total == @stats.completed + @stats.failed
      @grid.dom_header.appendChild @next_round_button
  next_round: ->
    count = 0
    for a in @grid.dom_main.querySelectorAll ".group"
      if parseInt a.getAttribute "data-mistakes" or 0
        a.setAttribute "data-mistakes", 0
        a.classList.remove "completed","failed"
        count += 1
      else a.remove()
    unless count then @grid.reset()
  constructor: (grid) ->
    super grid
    @next_round_button = crel "button", "next round"
    @next_round_button.addEventListener "click", =>
      @next_round()
      @next_round_button.remove()
  update: ->
    for a in randomize @grid.data
      idx = @grid.data.indexOf a
      answers = @random_answers @grid.data, a, idx, @options.choices - 1
      continue unless answers.length
      answers = for b in answers
        answer = @grid.get_data_sides(b[1], @options.reverse)[1]
        answer = crel "div", {class: "cell"}, crel("div", answer)
        if idx == b[0]
          answer.id = "a#{idx}"
          @grid.add_cell_states answer
        answer
      question = @grid.get_data_sides(a, @options.reverse)[0]
      question = crel "div", {class: "cell"}, crel("div", question)
      group = crel "span", {"id": "q#{idx}", class: "group"}, question, answers
      @grid.add_cell_states group
      @grid.dom_main.appendChild group

class grid_mode_group_class extends grid_mode
  name: "group"
  options: exhaustive: false, char_tuning: false
  option_fields: [
    ["exhaustive", "boolean"]
    ["char_tuning", "boolean"]
  ]
  set_option: (key, value) ->
    @options[key] = value
    @update()
    @grid.emit "update"
  base_interval_ms: 2000 * 86400
  max_interval_ms: 1000 * 365 * 86400
  pointerdown: (cell) ->
    return if cell.classList.contains "empty"
    if cell.classList.contains("completed") && cell.classList.contains("selected")
      @cell_reset cell
      cell.classList.remove "selected"
      return
    cell.classList.add "selected"
    needs_affirm = not cell.hasAttribute("data-last-affirmed") or cell.classList.contains "due"
    @cell_affirm cell if needs_affirm
  pointerup_long: (cell) ->
  pointerup: (cell) ->
  cell_affirm: (cell) ->
    now = Date.now()
    interval = parseInt(cell.getAttribute("data-interval") or @base_interval_ms)
    interval = Math.min interval * 2, @max_interval_ms
    cell.setAttribute "data-interval", interval
    cell.setAttribute "data-last-affirmed", now
    cell.classList.add "completed"
    cell.classList.remove "due"
    @update_stats()
    @update_set_completed()
    @grid.emit "update"
  cell_reset: (cell) ->
    cell.removeAttribute "data-interval"
    cell.removeAttribute "data-last-affirmed"
    cell.classList.remove "completed"
    cell.classList.remove "due"
    @update_stats()
    @update_set_completed()
    @grid.emit "update"
  refresh_due: ->
    now = Date.now()
    for cell in @grid.dom_main.querySelectorAll ".cell.completed"
      last = + (cell.getAttribute "data-last-affirmed" or 0)
      interval = + (cell.getAttribute "data-interval" or @base_interval_ms)
      overdue = last and (now - last > interval)
      cell.classList.toggle "due", overdue
      cell.classList.remove "selected" if overdue
  ingest: (data) ->
    children = {}
    pinyin = {}
    cand = {}
    pot = {}
    for [p, c, py] in data when c?
      p = null unless p? and p.length
      pinyin[c] ?= ""
      pinyin[p] ?= "" if p?
      pinyin[c] = py if py?
      if @canonical and p?
        cand[c] ?= []
        cand[c].push p
        pot[p] ?= new Set()
        pot[p].add c
      else if p?
        children[p] ?= new Set()
        children[p].add c
        pot[p] ?= new Set()
        pot[p].add c
    {children, pinyin, cand, pot}
  choose_parents: (children, cand, pot) ->
    @priorities ?= new Set split_chars "朵殳圣吴召奈青齐步𢀖咅否音至亲吉㕛台另古去妾辛尗责育幸舌君支亘旦瓜畐"
    allow_parent = (p) => @demote.indexOf(p) < 0 or @priorities.has p
    parent_of = {}
    root_sizes = {}
    get_root = (n) -> r = n; r = parent_of[r] while parent_of[r]?; r
    inc_root = (r, k = 1) -> root_sizes[r] = (root_sizes[r] or 1) + k
    taken = new Set()
    parents_by_size = Object.entries(pot).sort (a, b) -> b[1].size - a[1].size
    for [p, set] in parents_by_size
      continue unless allow_parent p
      kids = Array.from set
      free = kids.filter (x) -> not taken.has x
      need_full = @priorities.has(p) or (free.length >= @min_size and free.length <= @max_size)
      continue unless need_full
      children[p] ?= new Set()
      for ch in free
        parent_of[ch] = p
        children[p].add ch
        taken.add ch
      inc_root p, free.length
    min_cluster = 3
    for c, cands of cand
      continue if parent_of[c]?
      pri = cands.filter (x) => @priorities.has x
      ok  = cands.filter (x) => @demote.indexOf(x) < 0
      pool = if pri.length then pri else if ok.length then ok else cands
      best   = null
      best_v = 1 / 0
      for p in pool
        load    = root_sizes[get_root p] or 0
        penalty = if @demote.indexOf(p) >= 0 then 1e6 else 0
        score   = load + penalty
        if score < best_v
          best   = p
          best_v = score
      continue unless best?
      parent_of[c] = best
      children[best] ?= new Set()
      children[best].add c
      inc_root get_root best
    {children, parent_of}
  calc_sizes: (children) ->
    size_map = {}
    fn = (n) -> size_map[n] ?= 1 + Array.from(children[n] or []).reduce ((s, ch) -> s + fn(ch)), 0
    for n of @pinyin_map then fn n
    {size_map, fn}
  merge_small: (children, cand, parent_of) ->
    get_root = (n) -> r = n; r = parent_of[r] while parent_of[r]?; r
    loop
      {size_map} = @calc_sizes children
      roots = Object.keys(@pinyin_map).filter (x) -> x and not parent_of[x]?
      target = roots.find (r) => size_map[r] < @min_size and not @priorities.has r and cand?[r]
      break unless target?
      alts = (cand?[target] or []).filter (p) -> get_root(p) isnt target and @demote.indexOf(p) < 0
      alts = (cand?[target] or []).filter (p) -> get_root(p) isnt target unless alts.length
      break unless alts.length
      best = alts.reduce (a, b) ->
        (size_map[get_root a] or 1) < (size_map[get_root b] or 1) and a or b
      parent_of[target] = best
      children[best] ?= new Set()
      children[best].add target
    {children, parent_of}
  merge_tiny: (children, parent_of, size_map, limit = 2, wildcard = "﹡") ->
    @pinyin_map[wildcard] ?= ""
    children[wildcard] ?= new Set()
    roots = Object.keys(@pinyin_map).filter (x) -> x and not parent_of[x]?
    tiny  = roots.filter (r) -> size_map[r] <= limit
    for r in tiny
      parent_of[r] = wildcard
      children[wildcard].add r
    {children, parent_of}
  fan_out: (children, parent_of, L, U) ->
    loop
      changed = false
      {size_map} = @calc_sizes children
      roots = Object.keys(@pinyin_map).filter (x)->x and not parent_of[x]?
      for r in roots when size_map[r] > U
        kids = Array.from(children[r] or [])
        for c in kids when size_map[c] >= L and size_map[r] - size_map[c] >= L
          parent_of[c] = null
          kids = kids.filter (x)->x isnt c
          changed = true
        children[r] = kids
      break unless changed
    {children, parent_of}
  normalize: (children) ->
    for p, s of children
      children[p] = Array.from s
    children
  display_result_analysis: (roots, children) ->
    {size_map} = @calc_sizes children
    sizes = roots.map (r) -> size_map[r]
    sorted = sizes.slice().sort (a, b) -> a - b
    mid = Math.floor(sorted.length / 2)
    median = if sorted.length % 2 then sorted[mid] else (sorted[mid - 1] + sorted[mid]) / 2
    mean = sizes.reduce(((a, b) -> a + b), 0) / sizes.length
    variance = sizes.reduce(((a, b) -> a + (b - mean) * (b - mean)), 0) / sizes.length
    stdev = Math.sqrt variance
    console.log (r + ": " + size_map[r] for r in roots).join(", ")
    console.log "mean: #{mean.toFixed 2}, median: #{median.toFixed 2}, stdev: #{stdev.toFixed 2}"
  prepare_maps: (data, canonical = true) ->
    @min_size  = 6
    @max_size  = 60
    @canonical = canonical
    if @options.char_tuning
      @demote = split_chars "氵忄讠饣扌刂阝扌犭纟钅忄彳衤灬罒亻冫月牜礻𧾷口土人木"
      @priorities = new Set split_chars "朵殳圣吴召奈青齐步𢀖咅否音至亲吉㕛台另古去妾辛尗责育幸舌君支亘旦瓜畐"
    else
      @demote = []
      @priorities = new Set()
    {children, pinyin, cand, pot} = @ingest data
    @pinyin_map = pinyin
    {children, parent_of} = @choose_parents children, cand, pot
    {children, parent_of} = @merge_small children, cand, parent_of
    {size_map} = @calc_sizes children
    {children, parent_of} = @fan_out children, parent_of, @min_size, 60
    {children, parent_of} = @merge_tiny children, parent_of, size_map
    children = @normalize children
    roots = Object.keys(pinyin).filter (x) -> x and not parent_of[x]?
    {children_map: children, pinyin_map: pinyin, roots, size_map}
  render_node: (grid, wrapper, maps, ch, parent = "") ->
    {children_map, pinyin_map, size_map} = maps
    q = crel "div", ch
    a = crel "div", pinyin_map[ch] or ""
    cls = "cell"
    cls += " group-start" if children_map?[ch]
    cls += " empty" unless pinyin_map[ch]
    id = if parent then parent + ch else ch
    attrs =
      class: cls
      id: id
      "data-answer": pinyin_map[ch] or ""
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
    cells = Array.from @grid.dom_main.querySelectorAll ".cell"
    completed_cells = cells.filter (a) -> a.classList.contains "completed"
    due_cells = completed_cells.filter (a) -> a.classList.contains "due"
    @grid.dom_header.innerHTML = "due #{due_cells.length}, cards #{completed_cells.length}/#{cells.length}"
  update_set_completed: ->
    groups = @grid.dom_main.querySelectorAll ".group"
    for g in groups
      by_ans = {}
      for cell in g.querySelectorAll ".cell"
        ans = cell.getAttribute("data-answer") or ""
        by_ans[ans] ?= []
        by_ans[ans].push cell
      for ans, arr of by_ans
        all_completed = arr.length > 0 and arr.every (c) -> c.classList.contains "completed"
        for c in arr
          c.classList.toggle "set-completed", all_completed
  update: ->
    maps = @prepare_maps @grid.data, !@options.exhaustive
    for root in maps.roots
      w = crel "div",
        class: "group"
        "data-root": root
      @grid.dom_main.appendChild w
      @render_node @grid, w, maps, root
    @refresh_due()
    @update_stats()
    @update_set_completed()

class grid_class extends emitter_class
  # this represents the state and UI of the cell area.
  data: []
  font_size: 10
  class_set: {}
  cell_state_classes: ["hidden", "selected", "completed", "last", "due", "failed"]
  cell_state_attributes: ["data-mistakes", "data-interval", "data-last-affirmed"]
  pointerdown_selection: null
  reset: ->
    @dom_clear()
    @cell_states = {}
    @mode.update()
    @emit "update"
  dom_header: dom.grid.children[0]
  dom_main: dom.grid.children[1]
  dom_footer: dom.grid.children[2]
  dom_clear: (a) ->
    @dom_header.innerHTML = ""
    @dom_main.innerHTML = ""
    @dom_footer.innerHTML = ""
  show_hint: (a) ->
    dom.hint.innerHTML = a
    dom.hint.classList.remove "invisible"
    clearTimeout @hint_timeout if @hint_timeout
    @hint_timeout = setTimeout (=> dom.hint.classList.add "invisible"), 1000
  get_config: ->
    {
      mode_options: @mode.options
      font_size: @font_size
      cell_states: @get_cell_states()
    }
  set_mode: (a) ->  # grid_mode ->
    @mode = a
    dom.grid.setAttribute "data-mode", a.name
  set_config: (cfg) ->
    @set_mode @modes[cfg.mode or @mode.name] if @modes[cfg.mode or @mode.name]?
    @mode.options = cfg.mode_options if cfg.mode_options?
    @cell_states = cfg.cell_states if cfg.cell_states?
    if cfg.font_size?
      @font_size = cfg.font_size
      @update_font_size()
  update: ->
    @dom_clear()
    @mode.update()
  pulsate: (a) ->
    a.classList.remove "pulsate"
    a.classList.add "pulsate"
    a.addEventListener "animationend", (-> a.classList.remove "pulsate"), once: true
  update_font_size: -> dom.grid.style.fontSize = "#{@font_size / 10}em"
  cell_data: (a) -> @data[parseInt a.id.substring(1), 10]
  cell_data_index: (a) -> parseInt a.id.substring(1), 10
  add_cell_states: (cell) ->
    return unless @cell_states
    state = @cell_states[cell.id]
    return unless state
    if state.class
      cell.classList.add b for b in state.class
    cell.setAttribute name, value for name, value of state when name isnt "class"
  get_cell_states: ->
    states = {}
    for cell in @dom_main.querySelectorAll ".cell, .group"
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
    @emit "update"
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
      @active_pointer_id = event.pointerId
      @mode.pointerdown cell if event.pointerType == "mouse"
      @longtap_detector.detect "start"
    pointerup = (event) =>
      return unless @pointerdown_selection && event.pointerId == @active_pointer_id
      selection = @pointerdown_selection
      @pointerdown_selection = null
      cell = @get_cell_from_event_target event.target
      return unless cell
      if @longtap_detector.detect "end"
        if event.pointerType == "mouse" then @mode.pointerup_long cell
        else if event.pointerType == "touch" && selection == cell
          @mode.pointerdown_long cell
          @mode.pointerup_long cell
      else
        if event.pointerType == "mouse" then @mode.pointerup cell
        else if event.pointerType == "touch" && selection == cell
          @mode.pointerdown cell
          @mode.pointerup cell
    pointercancel = (event) =>
      return unless event.pointerId == @active_pointer_id
      @pointerdown_selection = null
    dom.grid.addEventListener "pointerdown", pointerdown
    document.body.addEventListener "pointerup", pointerup
    document.body.addEventListener "pointercancel", pointercancel
  constructor: ->
    super()
    @longtap_detector = new longtap_detector_class 400
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

class dropdown_class extends emitter_class
  # a custom dropdown that works like a button in a classic menubar.
  constructor: (container, label) ->
    super()
    @container = container
    @container.classList.add "dropdown"
    @button = crel "button", label
    @options_container = crel "div", {"class": "options"}
    @button.addEventListener "click", =>
      @container.classList.toggle "open"
      @emit "click"
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
          o.emit "change", a[1]
      @options_container.appendChild b

class file_select_class extends emitter_class
  # select, load, and persist files. this has its own storage separate from the main app.
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
        @emit "add"
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
    @emit "delete", id
  reset: ->
    localStorage.removeItem "files"
    ids = object_integer_keys @files
    @files = {}
    @file_data = {}
    @selection = null
    @update_options()
    for id in ids
      localStorage.removeItem "file_data_#{id}"
    @emit "reset"
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
    @dropdown.on "click", => dom.file.click() unless @selection?
    @dropdown.on "change", (a) =>
      if -1 == a then dom.file.click()
      else if -2 == a then @edit()
      else if -3 == a then @create()
      else if -4 == a then @delete()
      else
        @selection = a
        @load_file_data a
        @emit "change", a
  constructor: ->
    super()
    @load()
    @load_file_data(@selection) if @selection?
    @update_options()
    @add_events()
  set_selection_by_file_name: (name) ->
    for id, meta of @files
      if name == meta.name
        @set_selection id
        return
  set_selection: (id) ->
    @selection = id
    @load_file_data id
    @dropdown.set_selection id
    @emit "change", id
  get_file: -> @files[@selection]
  get_file_data: ->
    @load_file_data @selection
    @file_data[@selection]

class mode_select_class extends emitter_class
  # display a drowdown for selecting the grid mode as well as a form for the mode-specific options.
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
          @emit "set_grid_option", name
      else if type == "integer"
        a = crel "input", {type: "number", value, placeholder: name, min: 0, step: 1}
        a.addEventListener "change", (event) =>
          mode.set_option name, parseInt(event.target.value)
          @emit "set_grid_option", name
      crel "li", crel("label", name, a)
  set_mode: (name, trigger_events) ->
    @hide_selected_option_fields()
    @selection = @mode_names.indexOf name
    dom.modes.value = @selection
    @emit "change" if trigger_events
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
    super()
    @modes = modes
    @mode_names = Object.keys modes
    for name, i in @mode_names
      dom.modes.appendChild new Option name.replace(/_/g, " "), i
    dom.modes.addEventListener "change", (event) =>
      @hide_selected_option_fields()
      @selection = parseInt event.target.value
      @emit "change"
      @show_selected_option_fields()
    dom.options_button.addEventListener "click", (event) -> dom.menu_content.classList.toggle "show_options"

class app_class
  store: null
  last_selection: null
  save_state_for: (id) ->
    return unless id?
    @store.commit (s) =>
      s.configs[id] ?= {}
      cfg = @grid.get_config()
      mode = @grid.mode.name
      s.configs[id][mode] = cfg
      s.configs[id]._last = mode
      s
  load_state: (mode_name) ->
    id = @file_select.selection
    cfg = @store.state.configs[id]?[mode_name]
    @mode_select.set_mode mode_name, false
    @grid.set_mode @grid.modes[mode_name]
    @grid.set_config cfg if cfg?
  reset: ->
    localStorage.removeItem "app"
    @file_select.reset()
  choose_initial_file: ->
    if @url_query.file
      @file_select.set_selection_by_file_name @url_query.file
      return @file_select.selection if @file_select.selection?
    if @store.state.selection? and @file_select.files[@store.state.selection]?
      return @store.state.selection
    ids = object_integer_keys @file_select.files
    return ids[0] if ids.length
    null
  choose_initial_mode: (fid) ->
    m = @url_query.mode or @store.state.configs[fid]?._last
    if @grid.modes[m]? then m else "flip"
  save_current: ->
    current = @file_select.selection
    mode = @mode_select.get_mode()
    @store.commit (s) ->
      s.configs[current]?._last = mode
      s
    @save_state_for current
    @store.persist()
  save: debounce (-> !@initializing && @file_select.selection? && @save_current()), 800
  constructor: (preset) ->
    @initializing = true
    unless localStorage.hasOwnProperty "app"
      console.log preset
      localStorageSetJsonItem a, b for a, b of preset if preset?
    @store = new store_class
    @store.load()
    @file_select = new file_select_class
    @grid = new grid_class
    @longtap_detector = new longtap_detector_class 2000
    @mode_select = new mode_select_class @grid.modes
    @url_query = Object.fromEntries new URLSearchParams window.location.search
    fid = @choose_initial_file()
    if fid?
      @file_select.set_selection fid
      @grid.data = @file_select.get_file_data()
      mode = @choose_initial_mode fid
      @mode_select.set_mode mode, false
      @load_state mode
      @store.commit (s) -> s.selection = fid; s
      @last_selection = fid
    else
      @mode_select.set_mode "flip", false
    @grid.update()
    @mode_select.update_options()
    @add_events()
    @initializing = false
  add_events: ->
    dom.reset.addEventListener "pointerdown", =>
      @longtap_detector.detect "start"
    dom.reset.addEventListener "pointerup", =>
      if @longtap_detector.detect "end" then confirm("reset all?") && @reset() else @grid.reset()
    dom.font_increase.addEventListener "click", => @grid.modify_font_size 2
    dom.font_decrease.addEventListener "click", => @grid.modify_font_size -2
    @mode_select.on "change", =>
      return unless @file_select.selection?
      new_mode = @mode_select.get_mode()
      @store.commit (s) =>
        s.configs[@file_select.selection]?._last = new_mode
        s
      @load_state new_mode
      @grid.update()
      @save()
    @mode_select.on "set_grid_option", => @store.persist()
    @file_select.on "add", =>
      @save_state_for @last_selection
      @last_selection = @file_select.selection
      @grid.data = @file_select.get_file_data()
      @load_state @mode_select.get_mode()
      @grid.update()
      @save()
    @file_select.on "change", =>
      @save_state_for @last_selection
      @last_selection = @file_select.selection
      @store.commit (s) =>
        s.selection = @last_selection
        s
      @store.persist()
      id = @last_selection
      @grid.data = @file_select.get_file_data()
      mode = @store.state.configs[id]?._last or "flip"
      @load_state mode
      @grid.update()
      @save()
    @file_select.on "delete", (old_id) =>
      @store.commit (s) ->
        delete s.configs[old_id]
        s
      if @file_select.selection?
        @grid.data = @file_select.get_file_data()
        @load_state @mode_select.get_mode()
      else
        @grid.data = []
      @grid.update()
      @save()
    @file_select.on "reset", => location.reload()
    @grid.on "update", => @save()

new app_class(__data__)
