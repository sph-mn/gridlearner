const dom = {}
document.querySelectorAll("[id]").forEach(a => dom[a.id] = a)

const grid = {
  key: {
    space: 32
  },
  selection: [],
  font_size: 0,
  mode: null,
  data: null,
  load(a) {
    grid.set_font_size(a.font_size)
    // [[string:column, ...], ...]
    const data = a.data
    grid.data = a
    dom.grid.innerHTML = ""
    grid.mode.load(a)
  },
  get_state() {
    const a = grid
    return {
      selection: a.selection,
      mode: a.mode.name,
      data: a.data
    }
  },
  reset() {
    grid.load(grid.unload())
  },
  set_font_size(a) {
    grid.font_size = a
    dom.grid.style.fontSize = a + "px"
  },
  modify_font_size(difference) {
    grid.set_font_size(grid.font_size + difference)
  },
  set_events: () => {
    const mode = grid.mode
    dom.grid.addEventListener("mousedown", event => {
      const cell = event.target.closest("div[data-index]")
      mode.mousedown && mode.mousedown(cell)
    })
    dom.grid.addEventListener("mouseup", event => {
      const cell = event.target.closest("div[data-index]");
      mode.mouseup && mode.mouseup(cell)
    })
  },
  set_mode(a) {
    grid.mode = grid.modes[a]
  },
  modes: {},
  setup() {
    grid.set_events()
  }
}

grid.modes.single = {
  name: "single",
  options: {
    hold_to_flip: false
  },
  option_fields: [
    ["hold_to_flip", "boolean"]
  ],
  set_option(name) {
    console.log("set option " + name)
  },
  mousedown() {
    cell.classList.add("selected")
  },
  mouseup() {
    grid.modes.single.options.hold_to_flip && cell.classList.remove("selected")
  },
  load(data) {
    data.forEach(function(a, index) {
      const cell = document.createElement("div")
      const question = document.createElement("div")
      const answer = document.createElement("div")
      question.innerHTML = a[0]
      answer.innerHTML = a.slice(1).join(" ")
      cell.appendChild(question)
      cell.appendChild(answer)
      cell.setAttribute("data-index", index)
      dom.grid.appendChild(cell)
    })
  },
  play() {},
}

grid.modes.pair = {}
grid.modes.synonym = {}
grid.modes.which = {
  options: {
    alternatives: 5
  },
  option_fields: [
    ["alternatives", "integer"]
  ]
}

const files = {
  hooks: {
    open: null,
    select: null
  },
  file: 0,
  files: [],
  files_data: [],
  open(index, file) {
    Papa.parse(file, {
      delimiter: " ",
      complete: data => {
        data.errors.forEach(error => console.error(error))
        files.files.push({name: file.name})
        files.files_data.push(data)
        files.file = files.files.length - 1
        files.hooks.open && files.hooks.open()
        files.render_options()
      }
    })
  },
  delete(index) {
    if (!files.files.length) return
    const a = files.files[index]
    if (confirm("delete file " + a.name + "?")) {
      files.files.splice(index, 1)
      files.files_data.splice(index, 1)
      files.render_options()
    }
  },
  render_options() {
    dom.files.innerHTML = ""
    a = new Option("open", "")
    a.addEventListener("click", event => dom.file.click())
    dom.files.appendChild(a)
    files.files.forEach((a, i) => {
      const b = new Option(a.name, i)
      if (i == files.file) b.selected = true
      dom.files.appendChild(b)
    })
    if (files.files.length) {
      a = new Option("delete", "")
      a.addEventListener("click", event => files.delete(files.file))
      dom.files.appendChild(a)
    }
  },
  add_events() {
    dom.file.addEventListener("change", event => {
      if (!event.target.files.length) return
      files.open(files.file, event.target.files[0])
    })
    dom.files.addEventListener("change", event => {
      if (event.target.value) {
        files.file = parseInt(event.target.value, 10)
        files.hooks.select && files.hooks.select()
      }
    })
  },
  set_file(index) {
    dom.files.values = index
    files.file = index
    files.hooks.select && files.hooks.select()
  },
  setup() {
    files.render_options()
    files.add_events()
  },
  save_files() {
    localStorage.setItem("files", JSON.stringify(files.files))
  },
  load_files() {
    let a = localStorage.getItem("files")
    if (!a) return
    a = JSON.parse(a)
    files.files = a
    files.render_options()
  },
  save_file_data(index) {
    localStorage.setItem("files_data_" + index, JSON.stringify(files.files_data[index]))
  },
  load_file_data(index) {
    let a = localStorage.getItem("files_data_" + index)
    if (!a) return
    a = JSON.parse(a)
    files.files_data[index] = a
  }
}

const modes = {
  hooks: {
    select: null
  },
  mode: 0,
  modes: Object.keys(grid.modes),
  make_option_fields(name) {
    const mode = grid.modes[name]
    if (!mode || !mode.option_fields) return []
    return mode.option_fields.map(field => {
      const [name, type] = field
      const value = mode.options[name]
      const a = document.createElement("input")
      if (type === "boolean") {
        a.type = "checkbox"
        a.checked = value
        a.addEventListener("change", event => mode.set_option(name, event.target.checked))
      } else if (type === "integer") {
        a.type = "number";
        a.value = value
        a.placeholder = name
        a.setAttribute("min", "0")
        a.addEventListener("change", event => mode.set_option(name, parseInt(event.target.value)))
      }
      const b = document.createElement("label")
      b.textContent = name
      b.appendChild(a)
      return b
    })
  },
  set_mode(index) {
    dom.options_form.children[this.mode].classList.remove("show")
    dom.options_form.children[index].classList.add("show")
    this.mode = index
    dom.mode.value = index
    modes.hooks.select && modes.hooks.select()
  },
  setup() {
    modes.modes.forEach((a, i) => {
      dom.mode.appendChild(new Option(a, i))
      const fields = modes.make_option_fields(a)
      const b = document.createElement("div")
      fields.forEach(c => b.appendChild(c))
      dom.options_form.appendChild(b)
    })
    dom.mode.addEventListener("change", event => modes.set_mode(parseInt(event.target.value)))
    dom.options.addEventListener("click", event => dom.options_form.classList.toggle("hidden"))
    modes.set_mode(this.mode)
  }
}

const app = {
  add_events() {
    dom.save.addEventListener("click", event => app.save_grid())
    dom.reset.addEventListener("click", event => {
      grid.reset()
      app.save_grid()
    })
    dom.font_increase.addEventListener("click", event => {
      grid.modify_font_size(3)
      app.save_config()
    })
    dom.font_decrease.addEventListener("click", event => {
      grid.modify_font_size(-3)
      app.save_config()
    })
  },
  save() {
    console.log("save", app.file_modes)
    localStorage.setItem("app", JSON.stringify({
      file_modes: app.file_modes,
      file: files.file
    }))
  },
  load() {
    let a = localStorage.getItem("app")
    if (!a) return
    a = JSON.parse(a)
    console.log("loaded", a)
    app.file_modes = a.file_modes
    files.set_file(a.file)
    modes.mode = modes.modes.indexOf(app.file_modes[files.file])
  },
  file_modes: [],
  setup() {
    app.load()
    files.hooks.open = () => {
      app.file_modes[files.file] = modes.modes[modes.mode]
    }
    files.hooks.select = () => {
      modes.set_mode(modes.modes.indexOf(app.file_modes[files.file]))
    }
    files.load_files()
    files.setup()
    modes.hooks.select = () => {
      app.file_modes[files.file] = modes.modes[modes.mode]
      app.save()
    }
    modes.setup()
    app.add_events()
  }
}

app.setup()
