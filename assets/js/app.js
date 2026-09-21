// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/fixed_gear"
import topbar from "../vendor/topbar"

const RankingList = {
  mounted() {
    this.positions = {}
    this.expandedIds = []
  },

  beforeUpdate() {
    this.positions = {}
    this.expandedIds = []
    this.rows().forEach((row) => {
      this.positions[row.id] = row.getBoundingClientRect()
      if (row.querySelector("[aria-expanded='true']")) {
        this.expandedIds.push(row.id)
      }
    })
  },

  updated() {
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    const durationMs = reduce ? 0 : 450

    this.rows().forEach((row) => {
      const first = this.positions[row.id]
      if (!first) {
        return
      }

      const last = row.getBoundingClientRect()
      const dx = first.left - last.left
      const dy = first.top - last.top
      if (Math.abs(dx) < 1 && Math.abs(dy) < 1) {
        return
      }

      row.style.transform = "translate(" + dx + "px, " + dy + "px)"
      row.style.transition = "none"
      row.style.zIndex = this.expandedIds.indexOf(row.id) >= 0 ? "5" : "1"

      requestAnimationFrame(function () {
        requestAnimationFrame(function () {
          row.style.transition = reduce
            ? "none"
            : "transform 450ms cubic-bezier(0.22, 1, 0.36, 1)"
          row.style.transform = "translate(0, 0)"
        })
      })

      const clear = function () {
        row.style.transform = ""
        row.style.transition = ""
        row.style.zIndex = ""
        row.removeEventListener("transitionend", clear)
      }
      row.addEventListener("transitionend", clear)
    })

    this.followExpanded(durationMs)
  },

  rows() {
    return Array.prototype.slice.call(
      this.el.querySelectorAll(":scope > [id^='bike-']")
    )
  },

  followExpanded(delay) {
    if (this.expandedIds.length === 0) {
      return
    }

    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    const hook = this

    window.setTimeout(function () {
      const toolbar = document.getElementById("ranking-toolbar")
      const topPad = toolbar ? toolbar.getBoundingClientRect().bottom : 0
      const ids = hook.expandedIds

      let target = null
      for (let i = 0; i < ids.length; i++) {
        const el = document.getElementById(ids[i])
        if (!el) {
          continue
        }
        const r = el.getBoundingClientRect()
        if (r.bottom < topPad + 8 || r.top > window.innerHeight - 8) {
          target = el
          break
        }
      }
      if (!target) {
        target = document.getElementById(ids[0])
      }
      if (!target) {
        return
      }

      target.classList.add("ranking-followed")
      const r = target.getBoundingClientRect()
      const hidden = r.bottom < topPad + 8 || r.top > window.innerHeight - 8
      if (hidden) {
        target.scrollIntoView({
          behavior: reduce ? "auto" : "smooth",
          block: "center"
        })
      }
      window.setTimeout(function () {
        target.classList.remove("ranking-followed")
      }, 900)
    }, delay)
  }
}

const RatioMotion = {
  mounted() {
    this.anims = []
    this.startSpins()
    this.syncRate()
  },

  updated() {
    if (!this.anims || this.anims.length === 0) {
      this.startSpins()
    }
    this.syncRate()
  },

  destroyed() {
    this.stopSpins()
  },

  startSpins() {
    this.stopSpins()
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.anims = []
      return
    }

    const pedal = this.el.querySelector("[data-spin='pedal']")
    const wheel = this.el.querySelector("[data-spin='wheel']")
    this.anims = [
      this.spin(pedal, this.msAttr("data-pedal-ms", 667)),
      this.spin(wheel, this.msAttr("data-wheel-ms", 250))
    ]
  },

  stopSpins() {
    if (!this.anims) {
      return
    }
    this.anims.forEach(function (anim) {
      if (anim) {
        anim.cancel()
      }
    })
    this.anims = []
  },

  spin(node, ms) {
    if (!node) {
      return null
    }
    return node.animate(
      [{ transform: "rotate(0deg)" }, { transform: "rotate(360deg)" }],
      { duration: ms, iterations: Infinity, easing: "linear" }
    )
  },

  syncRate() {
    const rpm = parseInt(this.el.getAttribute("data-cadence"), 10)
    const rate = !rpm || rpm < 1 ? 0 : rpm / 90
    this.anims.forEach(function (anim) {
      if (anim) {
        anim.playbackRate = rate
      }
    })
  },

  msAttr(name, fallback) {
    const n = parseInt(this.el.getAttribute(name), 10)
    if (!n || n < 1) {
      return fallback
    }
    return n
  }
}

const SkidWheel = {
  mounted() {
    this.running = true
    this.rotation = 0
    this.anim = null
    this.timer = null
    this.startCycle()
  },

  updated() {
    const next = this.patchCount()
    if (next !== this.n) {
      this.stopCycle()
      this.running = true
      this.rotation = 0
      this.startCycle()
    }
  },

  destroyed() {
    this.stopCycle()
  },

  startCycle() {
    this.rotor = this.el.querySelector(".skid-wheel-rotor")
    this.n = this.patchCount()
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches

    if (!this.rotor || this.n < 1) {
      return
    }

    if (reduce) {
      this.markAll("is-marked")
      return
    }

    this.clearMarks()
    this.rotation = 0
    this.rotor.style.transform = "rotate(0deg)"
    this.runCycle(0)
  },

  stopCycle() {
    this.running = false
    if (this.anim) {
      this.anim.cancel()
      this.anim = null
    }
    if (this.timer) {
      window.clearTimeout(this.timer)
      this.timer = null
    }
  },

  patchCount() {
    return this.el.querySelectorAll(".skid-patch").length
  },

  patches() {
    return Array.prototype.slice.call(this.el.querySelectorAll(".skid-patch"))
  },

  runCycle(stepIndex) {
    if (!this.running || !this.rotor) {
      return
    }

    const step = 360 / this.n
    const target = 540 + stepIndex * (360 + step)
    const delta = target - this.rotation
    const hook = this

    if (stepIndex > 0 && stepIndex % this.n === 0) {
      this.clearMarks()
    }

    this.rollTo(target, this.spinMs(delta), function () {
      const patch = hook.patchAt(stepIndex % hook.n)
      if (patch) {
        patch.classList.add("is-skidding")
      }
      hook.skidFight(target, function () {
        if (patch) {
          patch.classList.remove("is-skidding")
          patch.classList.add("is-marked")
        }
        hook.runCycle(stepIndex + 1)
      })
    })
  },

  rollTo(deg, ms, done) {
    const from = this.rotation
    const slam = from + (deg - from) * 0.96
    this.play(
      [
        { transform: "rotate(" + from + "deg)", easing: "cubic-bezier(0.42, 0, 1, 1)" },
        { transform: "rotate(" + slam + "deg)", offset: 0.9, easing: "cubic-bezier(0.15, 0, 0, 1)" },
        { transform: "rotate(" + deg + "deg)" }
      ],
      ms,
      deg,
      done
    )
  },

  skidFight(contact, done) {
    const reverse = contact - 8
    const stuck = contact - 11
    const creep = contact - 5
    const hook = this

    this.burstSparks()
    this.timer = window.setTimeout(function () {
      hook.burstSparks()
    }, 160)

    this.play(
      [
        { transform: "rotate(" + contact + "deg)", easing: "cubic-bezier(0.2, 0.85, 0.3, 1)" },
        { transform: "rotate(" + reverse + "deg)", offset: 0.18, easing: "cubic-bezier(0.45, 0.05, 0.6, 1)" },
        { transform: "rotate(" + stuck + "deg)", offset: 0.48, easing: "cubic-bezier(0.4, 0.1, 0.7, 1)" },
        { transform: "rotate(" + creep + "deg)", offset: 0.78, easing: "cubic-bezier(0.55, 0, 0.7, 1)" },
        { transform: "rotate(" + contact + "deg)" }
      ],
      560,
      contact,
      done
    )
  },

  play(keyframes, ms, endDeg, done) {
    const rotor = this.rotor
    const hook = this

    if (this.anim) {
      this.anim.cancel()
    }

    this.anim = rotor.animate(keyframes, {
      duration: ms,
      fill: "forwards"
    })

    this.anim.onfinish = function () {
      if (!hook.running) {
        return
      }
      hook.rotation = endDeg
      rotor.style.transform = "rotate(" + endDeg + "deg)"
      if (hook.anim) {
        hook.anim.cancel()
        hook.anim = null
      }
      done()
    }
  },

  spinMs(deltaDeg) {
    const ms = Math.abs(deltaDeg) / 360 * 720
    if (ms < 280) {
      return 280
    }
    return ms
  },

  burstSparks() {
    const layer = this.el.querySelector(".skid-sparks")
    if (!layer) {
      return
    }
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      return
    }

    let i
    for (i = 0; i < 8; i++) {
      const spark = document.createElement("span")
      const dust = i % 3 === 0
      spark.className = dust ? "skid-spark is-dust" : "skid-spark"
      spark.style.setProperty("--dx", (Math.random() - 0.5) * 22 + "px")
      spark.style.setProperty("--dy", 5 + Math.random() * 12 + "px")
      spark.style.setProperty("--rot", (Math.random() - 0.5) * 90 + "deg")
      spark.style.setProperty("--delay", i * 16 + "ms")
      layer.appendChild(spark)
      spark.addEventListener("animationend", function () {
        if (spark.parentNode) {
          spark.parentNode.removeChild(spark)
        }
      })
    }
  },

  patchAt(index) {
    const nodes = this.patches()
    return nodes[index] || null
  },

  markAll(className) {
    this.patches().forEach(function (patch) {
      patch.classList.add(className)
    })
  },

  clearMarks() {
    this.patches().forEach(function (patch) {
      patch.classList.remove("is-skidding")
      patch.classList.remove("is-marked")
    })
  }
}

const CompressPhoto = {
  mounted() {
    this.passthrough = false
    this.busy = false
    this.input = null
    this._onChange = (event) => this.handleChange(event)
    this.bindInput()
  },

  updated() {
    this.bindInput()
  },

  destroyed() {
    this.unbindInput()
  },

  bindInput() {
    const input = this.el.querySelector("input[type=\"file\"]")
    if (input === this.input) {
      return
    }
    this.unbindInput()
    this.input = input
    if (this.input) {
      this.input.addEventListener("change", this._onChange, true)
    }
  },

  unbindInput() {
    if (this.input) {
      this.input.removeEventListener("change", this._onChange, true)
    }
    this.input = null
  },

  handleChange(event) {
    if (this.passthrough) {
      this.passthrough = false
      return
    }
    if (this.busy) {
      event.stopPropagation()
      event.stopImmediatePropagation()
      return
    }
    const input = event.target
    if (input == null || input.files == null || input.files.length === 0) {
      return
    }
    const file = input.files[0]
    if (file == null) {
      return
    }
    event.stopPropagation()
    event.stopImmediatePropagation()
    this.busy = true
    this.prepare(file).then((next) => {
      this.replaceFile(input, next)
      this.busy = false
      this.passthrough = true
      input.dispatchEvent(new Event("change", {bubbles: true}))
    })
  },

  replaceFile(input, file) {
    try {
      const transfer = new DataTransfer()
      transfer.items.add(file)
      input.files = transfer.files
    } catch (_err) {
      // Some mobile browsers refuse to assign input.files; keep the original.
    }
  },

  prepare(file) {
    const maxEdge = 1600
    const quality = 0.82
    if (typeof createImageBitmap !== "function") {
      return Promise.resolve(file)
    }
    return createImageBitmap(file, {imageOrientation: "from-image"}).then((bitmap) => {
      let width = bitmap.width
      let height = bitmap.height
      if (width > maxEdge || height > maxEdge) {
        const scale = Math.min(maxEdge / width, maxEdge / height)
        width = Math.round(width * scale)
        height = Math.round(height * scale)
      }
      const canvas = document.createElement("canvas")
      canvas.width = width
      canvas.height = height
      const ctx = canvas.getContext("2d")
      if (ctx == null) {
        bitmap.close()
        return file
      }
      ctx.drawImage(bitmap, 0, 0, width, height)
      bitmap.close()
      return new Promise((resolve) => {
        canvas.toBlob(function (blob) {
          if (blob == null) {
            resolve(file)
            return
          }
          const name = file.name.replace(/\.[^.]+$/, "") + ".jpg"
          resolve(new File([blob], name, {type: "image/jpeg", lastModified: Date.now()}))
        }, "image/jpeg", quality)
      })
    }).catch(function () {
      return file
    })
  }
}

// Keep stops in sync with FixedGearWeb.CadenceColor
const CADENCE_STOPS = [
  [0, 0.86, 0.07, 230],
  [60, 0.78, 0.14, 230],
  [80, 0.75, 0.18, 145],
  [100, 0.85, 0.16, 95],
  [120, 0.75, 0.18, 55],
  [160, 0.65, 0.22, 25],
  [180, 0.60, 0.24, 310]
]

function cadenceLerp(a, b, t) {
  return a + (b - a) * t
}

function cadenceLerpHue(from, to, t) {
  let delta = to - from
  if (delta > 180) {
    delta = delta - 360
  } else if (delta < -180) {
    delta = delta + 360
  }
  let hue = from + delta * t
  hue = hue - 360 * Math.floor(hue / 360)
  if (hue < 0) {
    hue = hue + 360
  }
  return hue
}

function cadenceOklch(rpm) {
  let value = rpm
  if (value < 0) {
    value = 0
  } else if (value > 180) {
    value = 180
  }

  let i = 0
  while (i < CADENCE_STOPS.length - 1 && value > CADENCE_STOPS[i + 1][0]) {
    i = i + 1
  }

  const from = CADENCE_STOPS[i]
  const to = CADENCE_STOPS[Math.min(i + 1, CADENCE_STOPS.length - 1)]
  if (from[0] === to[0]) {
    return {l: from[1], c: from[2], h: from[3]}
  }

  const t = (value - from[0]) / (to[0] - from[0])
  return {
    l: cadenceLerp(from[1], to[1], t),
    c: cadenceLerp(from[2], to[2], t),
    h: cadenceLerpHue(from[3], to[3], t)
  }
}

function cadenceCss(rpm) {
  const color = cadenceOklch(rpm)
  return "oklch(" + color.l.toFixed(4) + " " + color.c.toFixed(4) + " " + color.h.toFixed(4) + ")"
}

const CadenceSlider = {
  mounted() {
    this.input = this.el.querySelector("input[type='range']")
    this.valueEl = this.el.querySelector("[data-cadence-value]")
    this.onInput = this.syncFromInput.bind(this)
    if (this.input) {
      this.input.addEventListener("input", this.onInput)
    }
    this.syncFromInput()
  },

  updated() {
    this.syncFromInput()
  },

  destroyed() {
    if (this.input && this.onInput) {
      this.input.removeEventListener("input", this.onInput)
    }
  },

  syncFromInput() {
    if (!this.input) {
      return
    }
    const rpm = parseInt(this.input.value, 10) || 0
    const color = cadenceCss(rpm)
    this.el.style.setProperty("--cadence-color", color)
    if (this.valueEl) {
      this.valueEl.textContent = rpm + " rpm"
      this.valueEl.style.color = color
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {RankingList, RatioMotion, SkidWheel, CompressPhoto, CadenceSlider, ...colocatedHooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

