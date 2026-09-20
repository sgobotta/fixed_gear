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

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {RankingList, ...colocatedHooks},
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

