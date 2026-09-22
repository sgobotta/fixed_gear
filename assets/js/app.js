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
    this.anims = []
    this.inflight = null
    this.seekMs = 0
    this.playGen = 0
    this.markState = {}
    this.sampleFrame = null
    this.timer = null
    this.patchesKey = this.el.getAttribute("data-patches") || ""
    this.gearsKey = this.gearKey()
    this.ambiKey = this.el.getAttribute("data-ambidextrous") || ""
    this.startCycle()
  },

  updated() {
    const patches = this.el.getAttribute("data-patches") || ""
    const gears = this.gearKey()
    const ambi = this.el.getAttribute("data-ambidextrous") || ""

    if (patches !== this.patchesKey) {
      this.patchesKey = patches
      this.gearsKey = gears
      this.ambiKey = ambi
      this.stopCycle()
      this.running = true
      this.rotation = 0
      this.markState = {}
      this.startCycle()
      return
    }

    if (gears !== this.gearsKey || ambi !== this.ambiKey) {
      this.gearsKey = gears
      this.ambiKey = ambi
      this.syncDrive()
    }
  },

  destroyed() {
    this.stopCycle()
  },

  startCycle() {
    this.queryParts()
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
    this.seekMs = 0
    this.pinPose(0)
    this.runCycle(0)
  },

  stopCycle() {
    this.running = false
    this.inflight = null
    this.playGen = this.playGen + 1
    this.cancelAnims()
    if (this.timer) {
      window.clearTimeout(this.timer)
      this.timer = null
    }
  },

  syncDrive() {
    const seek = this.seekMs || 0
    const inflight = this.inflight
    this.playGen = this.playGen + 1
    this.cancelAnims()
    this.queryParts()
    this.n = this.patchCount()
    this.trimMarks()
    this.restoreMarks()

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.pinPose(0)
      this.markAll("is-marked")
      return
    }

    if (!this.running || !inflight || !this.rotor) {
      this.pinPose(this.rotation)
      return
    }

    if (seek >= inflight.ms - 20) {
      this.rotation = inflight.endDeg
      this.seekMs = 0
      this.pinPose(inflight.endDeg)
      const done = inflight.done
      this.inflight = null
      done()
      return
    }

    this.play(inflight.frames, inflight.ms, inflight.endDeg, inflight.done, seek)
  },

  queryParts() {
    this.rotor = this.el.querySelector(".skid-wheel-rotor")
    this.cog = this.el.querySelector(".skid-wheel-cog")
    this.ring = this.el.querySelector(".skid-wheel-ring")
    this.chain = this.el.querySelector(".skid-wheel-chain")
    this.svg = this.el.querySelector("svg")
  },

  patchCount() {
    return this.el.querySelectorAll(".skid-patch").length
  },

  gearKey() {
    return (
      (this.el.getAttribute("data-chain-ring") || "") +
      ":" +
      (this.el.getAttribute("data-rear-sprocket") || "")
    )
  },

  ratio() {
    const ring = parseFloat(this.el.getAttribute("data-chain-ring"))
    const cog = parseFloat(this.el.getAttribute("data-rear-sprocket"))
    if (!ring || !cog) {
      return 0
    }
    return cog / ring
  },

  cogPitch() {
    const n = parseFloat(this.el.getAttribute("data-cog-pitch"))
    if (!n) {
      return 0
    }
    return n
  },

  pxPerUnit() {
    const svg = this.svg
    if (!svg || !svg.viewBox || !svg.viewBox.baseVal) {
      return 1
    }
    const h = svg.viewBox.baseVal.height
    const rect = svg.getBoundingClientRect()
    if (!h || !rect.height) {
      return 1
    }
    return rect.height / h
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
    const markIndex = stepIndex % this.n

    if (stepIndex > 0 && stepIndex % this.n === 0) {
      this.clearMarks()
    }

    this.rollTo(target, this.spinMs(delta), function () {
      hook.setSkidding(markIndex)
      hook.skidFight(target, function () {
        hook.setMarked(markIndex)
        hook.runCycle(stepIndex + 1)
      })
    })
  },

  rollTo(deg, ms, done) {
    const from = this.rotation
    const slam = from + (deg - from) * 0.96
    this.seekMs = 0
    this.play(
      [
        { deg: from, offset: 0, easing: "cubic-bezier(0.42, 0, 1, 1)" },
        { deg: slam, offset: 0.9, easing: "cubic-bezier(0.15, 0, 0, 1)" },
        { deg: deg, offset: 1 }
      ],
      ms,
      deg,
      done,
      0
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
    }, 210)

    this.seekMs = 0
    this.play(
      [
        { deg: contact, offset: 0, easing: "cubic-bezier(0.2, 0.85, 0.3, 1)" },
        { deg: reverse, offset: 0.14, easing: "cubic-bezier(0.45, 0.05, 0.6, 1)" },
        { deg: stuck, offset: 0.34, easing: "linear" },
        { deg: stuck, offset: 0.58, easing: "cubic-bezier(0.4, 0.1, 0.7, 1)" },
        { deg: creep, offset: 0.8, easing: "cubic-bezier(0.55, 0, 0.7, 1)" },
        { deg: contact, offset: 1 }
      ],
      720,
      contact,
      done,
      0
    )
  },

  play(frames, ms, endDeg, done, seekMs) {
    const hook = this
    const seek = seekMs || 0
    this.playGen = this.playGen + 1
    const gen = this.playGen
    this.cancelAnims()

    const ratio = this.ratio()
    const pitch = this.cogPitch()
    const scale = this.pxPerUnit()
    this.paintChainDash(pitch, scale)

    const rotorFrames = frames.map(function (frame) {
      return hook.rotateFrame(frame, frame.deg)
    })
    const ringFrames = frames.map(function (frame) {
      return hook.rotateFrame(frame, frame.deg * ratio)
    })
    const chainFrames = frames.map(function (frame) {
      const travel = pitch * frame.deg * Math.PI / 180 * scale
      const next = { strokeDashoffset: (-travel) + "px" }
      if (frame.easing) {
        next.easing = frame.easing
      }
      if (frame.offset != null) {
        next.offset = frame.offset
      }
      return next
    })

    const opts = { duration: ms, fill: "forwards" }
    const anims = []
    if (this.rotor) {
      anims.push(this.rotor.animate(rotorFrames, opts))
    }
    if (this.cog) {
      anims.push(this.cog.animate(rotorFrames, opts))
    }
    if (this.ring) {
      anims.push(this.ring.animate(ringFrames, opts))
    }
    if (this.chain) {
      anims.push(this.chain.animate(chainFrames, opts))
    }
    this.anims = anims

    let i
    for (i = 0; i < anims.length; i++) {
      if (seek > 0) {
        anims[i].currentTime = seek
      }
    }
    if (anims.length > 1 && anims[0].startTime != null) {
      for (i = 1; i < anims.length; i++) {
        anims[i].startTime = anims[0].startTime
      }
    }

    this.inflight = { frames: frames, ms: ms, endDeg: endDeg, done: done }
    this.watchClock(gen)

    if (!anims.length) {
      return
    }

    anims[0].onfinish = function () {
      if (gen !== hook.playGen || !hook.running) {
        return
      }
      hook.rotation = endDeg
      hook.seekMs = 0
      hook.pinPose(endDeg)
      hook.inflight = null
      hook.cancelAnims()
      done()
    }
  },

  rotateFrame(frame, deg) {
    const next = { transform: "rotate(" + deg + "deg)" }
    if (frame.easing) {
      next.easing = frame.easing
    }
    if (frame.offset != null) {
      next.offset = frame.offset
    }
    return next
  },

  paintChainDash(pitch, scale) {
    if (!this.chain || !pitch || !scale) {
      return
    }
    const teeth = parseFloat(this.el.getAttribute("data-rear-sprocket"))
    if (!teeth) {
      return
    }
    const link = 2 * Math.PI * pitch / teeth * scale
    this.chain.style.strokeDasharray = (link * 0.58) + "px " + (link * 0.42) + "px"
  },

  pinPose(deg) {
    const ratio = this.ratio()
    const pitch = this.cogPitch()
    const scale = this.pxPerUnit()
    if (this.rotor) {
      this.rotor.style.transform = "rotate(" + deg + "deg)"
    }
    if (this.cog) {
      this.cog.style.transform = "rotate(" + deg + "deg)"
    }
    if (this.ring) {
      this.ring.style.transform = "rotate(" + (deg * ratio) + "deg)"
    }
    if (this.chain) {
      this.paintChainDash(pitch, scale)
      const travel = pitch * deg * Math.PI / 180 * scale
      this.chain.style.strokeDashoffset = (-travel) + "px"
    }
  },

  watchClock(gen) {
    const hook = this
    function tick() {
      hook.sampleFrame = null
      if (gen !== hook.playGen) {
        return
      }
      if (!hook.anims || !hook.anims[0]) {
        return
      }
      const current = hook.anims[0].currentTime
      if (current != null) {
        hook.seekMs = current
      }
      if (hook.anims[0].playState === "running") {
        hook.sampleFrame = window.requestAnimationFrame(tick)
      }
    }
    this.sampleFrame = window.requestAnimationFrame(tick)
  },

  cancelAnims() {
    const anims = this.anims || []
    this.anims = []
    anims.forEach(function (anim) {
      anim.onfinish = null
      anim.cancel()
    })
    if (this.sampleFrame) {
      window.cancelAnimationFrame(this.sampleFrame)
      this.sampleFrame = null
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

  markStateAt(index) {
    if (!this.markState[index]) {
      this.markState[index] = { skidding: false, marked: false }
    }
    return this.markState[index]
  },

  setSkidding(index) {
    const hook = this
    Object.keys(this.markState).forEach(function (key) {
      hook.markState[key].skidding = false
    })
    this.markStateAt(index).skidding = true
    this.patches().forEach(function (patch, i) {
      if (i === index) {
        patch.classList.add("is-skidding")
      } else {
        patch.classList.remove("is-skidding")
      }
    })
  },

  setMarked(index) {
    const state = this.markStateAt(index)
    state.skidding = false
    state.marked = true
    const patch = this.patchAt(index)
    if (patch) {
      patch.classList.remove("is-skidding")
      patch.classList.add("is-marked")
    }
  },

  trimMarks() {
    const n = this.patches().length
    const next = {}
    let i
    for (i = 0; i < n; i++) {
      if (this.markState[i]) {
        next[i] = this.markState[i]
      }
    }
    this.markState = next
  },

  restoreMarks() {
    const hook = this
    this.patches().forEach(function (patch, index) {
      const state = hook.markState[index]
      if (!state) {
        return
      }
      if (state.skidding) {
        patch.classList.add("is-skidding")
      }
      if (state.marked) {
        patch.classList.add("is-marked")
      }
    })
  },

  markAll(className) {
    const hook = this
    this.patches().forEach(function (patch, index) {
      patch.classList.add(className)
      if (className === "is-marked") {
        hook.markStateAt(index).marked = true
      }
    })
  },

  clearMarks() {
    this.markState = {}
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
    this.inputs = []
    this._onChange = (event) => this.handleChange(event)
    this.bindInputs()
  },

  updated() {
    this.bindInputs()
  },

  destroyed() {
    this.unbindInputs()
  },

  bindInputs() {
    const inputs = Array.prototype.slice.call(
      this.el.querySelectorAll("input[type=\"file\"]")
    )
    if (this.sameInputs(inputs)) {
      return
    }
    this.unbindInputs()
    this.inputs = inputs
    const onChange = this._onChange
    this.inputs.forEach(function (input) {
      input.addEventListener("change", onChange, true)
    })
  },

  sameInputs(inputs) {
    if (this.inputs.length !== inputs.length) {
      return false
    }
    for (let i = 0; i < inputs.length; i++) {
      if (this.inputs[i] !== inputs[i]) {
        return false
      }
    }
    return true
  },

  unbindInputs() {
    const onChange = this._onChange
    this.inputs.forEach(function (input) {
      input.removeEventListener("change", onChange, true)
    })
    this.inputs = []
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
    this.input = null
    this.valueEl = null
    this.onInput = this.syncFromInput.bind(this)
    this.bindInput()
    this.syncFromInput()
  },

  updated() {
    this.bindInput()
    this.syncFromInput()
  },

  destroyed() {
    this.unbindInput()
  },

  bindInput() {
    const input = this.el.querySelector("input[type='range']")
    const valueEl = this.el.querySelector("[data-cadence-value]")
    if (input === this.input && valueEl === this.valueEl) {
      return
    }
    this.unbindInput()
    this.input = input
    this.valueEl = valueEl
    if (this.input) {
      this.input.addEventListener("input", this.onInput)
    }
  },

  unbindInput() {
    if (this.input && this.onInput) {
      this.input.removeEventListener("input", this.onInput)
    }
    this.input = null
  },

  syncFromInput() {
    if (!this.input) {
      return
    }
    const rpm = parseInt(this.input.value, 10) || 0
    const min = parseFloat(this.input.min)
    const max = parseFloat(this.input.max)
    const span = max - min
    const progress = !span ? 0 : ((rpm - min) / span) * 100
    const color = cadenceCss(rpm)
    this.el.style.setProperty("--cadence-color", color)
    this.el.style.setProperty("--cadence-progress", progress + "%")
    if (this.valueEl) {
      this.valueEl.textContent = rpm + " rpm"
      this.valueEl.style.color = color
    }
  }
}

const SliderValue = {
  mounted() {
    this.input = null
    this.valueEl = null
    this.onInput = this.syncFromInput.bind(this)
    this.bindInput()
    this.syncFromInput()
  },

  updated() {
    this.bindInput()
    this.syncFromInput()
  },

  destroyed() {
    this.unbindInput()
  },

  bindInput() {
    const input = this.el.querySelector("input[type='range']")
    const valueEl = this.el.querySelector("[data-slider-value]")
    this.suffix = this.el.getAttribute("data-suffix") || ""
    if (input === this.input && valueEl === this.valueEl) {
      return
    }
    this.unbindInput()
    this.input = input
    this.valueEl = valueEl
    if (this.input) {
      this.input.addEventListener("input", this.onInput)
    }
  },

  unbindInput() {
    if (this.input && this.onInput) {
      this.input.removeEventListener("input", this.onInput)
    }
    this.input = null
  },

  syncFromInput() {
    if (!this.input || !this.valueEl) {
      return
    }
    this.valueEl.textContent = this.input.value + this.suffix
  }
}

const BottomNav = {
  mounted() {
    const hook = this
    this.nav = this.el.closest("#app-bottom-nav")
    this.pill = this.el.querySelector("#app-bottom-nav-pill")
    this.onClick = function (event) {
      const link = event.target.closest("a")
      if (!link || !hook.nav || !hook.nav.contains(link)) {
        return
      }
      hook.pop(link)
      const current = hook.activeLink()
      if (current) {
        hook.storePill(current)
      }
    }
    this.onResize = function () {
      hook.layoutActive(false)
    }
    if (this.nav) {
      this.nav.addEventListener("click", this.onClick)
    }
    window.addEventListener("resize", this.onResize)
    this.restoreAndMove()
  },

  updated() {
    this.layoutActive(true)
  },

  destroyed() {
    if (this.nav) {
      this.nav.removeEventListener("click", this.onClick)
    }
    window.removeEventListener("resize", this.onResize)
  },

  reduce() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
  },

  activeLink() {
    return this.nav && this.nav.querySelector("[aria-current='page']")
  },

  restoreAndMove() {
    const active = this.activeLink()
    if (!active) {
      return
    }
    const saved = this.readStore()
    const dest = this.rectOf(active)
    const hook = this
    if (saved && dest && !this.reduce() && this.moved(saved, dest)) {
      this.applyPill(saved.x, saved.y, saved.w, saved.h, false)
      requestAnimationFrame(function () {
        requestAnimationFrame(function () {
          hook.applyPill(dest.x, dest.y, dest.w, dest.h, true)
          hook.pop(active)
          hook.storePill(active)
        })
      })
    } else {
      this.movePill(active, false)
      this.storePill(active)
    }
  },

  layoutActive(animate) {
    const active = this.activeLink()
    if (active) {
      this.movePill(active, animate)
      this.storePill(active)
    }
  },

  rectOf(link) {
    if (!this.pill || !this.pill.parentElement) {
      return null
    }
    const trackRect = this.pill.parentElement.getBoundingClientRect()
    const rect = link.getBoundingClientRect()
    return {
      x: rect.left - trackRect.left,
      y: rect.top - trackRect.top,
      w: rect.width,
      h: rect.height
    }
  },

  moved(from, to) {
    return Math.abs(from.x - to.x) > 1 || Math.abs(from.y - to.y) > 1
  },

  movePill(link, animate) {
    const rect = this.rectOf(link)
    if (!rect) {
      return
    }
    this.applyPill(rect.x, rect.y, rect.w, rect.h, animate)
  },

  applyPill(x, y, width, height, animate) {
    if (!this.pill) {
      return
    }
    if (!animate || this.reduce()) {
      this.pill.style.transition = "none"
    }
    this.pill.style.width = width + "px"
    this.pill.style.height = height + "px"
    this.pill.style.transform = "translate(" + x + "px, " + y + "px)"
    this.pill.classList.add("is-ready")
    if (!animate || this.reduce()) {
      this.pill.offsetWidth
      this.pill.style.transition = ""
    }
  },

  pop(link) {
    if (this.reduce()) {
      return
    }
    link.classList.remove("nav-tab-pop")
    link.offsetWidth
    link.classList.add("nav-tab-pop")
    const clear = function () {
      link.classList.remove("nav-tab-pop")
      link.removeEventListener("animationend", clear)
    }
    link.addEventListener("animationend", clear)
  },

  storePill(link) {
    const track = this.pill && this.pill.parentElement
    if (!track) {
      return
    }
    const trackRect = track.getBoundingClientRect()
    const rect = link.getBoundingClientRect()
    try {
      sessionStorage.setItem(
        "fixed-gear-bottom-nav",
        JSON.stringify({
          x: rect.left - trackRect.left,
          y: rect.top - trackRect.top,
          w: rect.width,
          h: rect.height
        })
      )
    } catch (_error) {}
  },

  readStore() {
    try {
      const raw = sessionStorage.getItem("fixed-gear-bottom-nav")
      if (!raw) {
        return null
      }
      const data = JSON.parse(raw)
      if (
        typeof data.x !== "number" ||
        typeof data.y !== "number" ||
        typeof data.w !== "number" ||
        typeof data.h !== "number"
      ) {
        return null
      }
      return data
    } catch (_error) {
      return null
    }
  }
}

const AppHeader = {
  mounted() {
    const header = this
    this.sync = function () {
      header.measure()
    }
    this.measure()
    this.observer = new ResizeObserver(this.sync)
    this.observer.observe(this.el)
  },

  updated() {
    this.measure()
  },

  destroyed() {
    this.observer.disconnect()
  },

  measure() {
    document.documentElement.style.setProperty(
      "--app-header-height",
      this.el.offsetHeight + "px"
    )
  }
}

const ShareLink = {
  mounted() {
    const hook = this
    this.onClick = function (event) {
      event.preventDefault()
      const path = hook.el.getAttribute("data-url")
      const title = hook.el.getAttribute("data-title")
      const copiedLabel = hook.el.getAttribute("data-copied-label")
      const url = new URL(path, window.location.href).href

      shareOrCopy(url, title).then(function (result) {
        if (result === "copied") {
          hook.showCopied(copiedLabel)
        }
      })
    }
    this.el.addEventListener("click", this.onClick)
  },

  showCopied(label) {
    const shareIcon = this.el.querySelector("[data-share-icon]")
    const copiedIcon = this.el.querySelector("[data-copied-icon]")
    const status = document.getElementById(this.el.id + "-status")

    if (shareIcon) {
      shareIcon.style.display = "none"
    }
    if (copiedIcon) {
      copiedIcon.style.display = "inline-flex"
    }
    if (status) {
      status.textContent = label
    }

    if (this.copiedTimer) {
      window.clearTimeout(this.copiedTimer)
    }

    const hook = this
    this.copiedTimer = window.setTimeout(function () {
      if (shareIcon) {
        shareIcon.style.display = ""
      }
      if (copiedIcon) {
        copiedIcon.style.display = ""
      }
      if (status) {
        status.textContent = ""
      }
    }, 2000)
  },

  destroyed() {
    this.el.removeEventListener("click", this.onClick)
    if (this.copiedTimer) {
      window.clearTimeout(this.copiedTimer)
    }
  }
}

function shareOrCopy(url, title) {
  if (typeof navigator.share === "function") {
    return navigator.share({title: title, url: url}).then(
      function () {
        return "shared"
      },
      function (error) {
        if (error && error.name === "AbortError") {
          return "aborted"
        }
        return copyText(url)
      }
    )
  }
  return copyText(url)
}

function copyText(url) {
  if (
    navigator.clipboard &&
    typeof navigator.clipboard.writeText === "function"
  ) {
    return navigator.clipboard.writeText(url).then(
      function () {
        return "copied"
      },
      function () {
        return copyWithInput(url)
      }
    )
  }
  return Promise.resolve(copyWithInput(url))
}

function copyWithInput(url) {
  const input = document.createElement("input")
  input.value = url
  input.setAttribute("readonly", "readonly")
  input.style.position = "fixed"
  input.style.left = "-9999px"
  document.body.appendChild(input)
  input.select()
  let copied = false
  try {
    copied = document.execCommand("copy")
  } catch (_error) {
    copied = false
  }
  document.body.removeChild(input)
  if (copied) {
    return "copied"
  }
  return "failed"
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {RankingList, RatioMotion, SkidWheel, CompressPhoto, CadenceSlider, SliderValue, BottomNav, AppHeader, ShareLink, ...colocatedHooks},
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

