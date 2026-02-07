// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/animina"
import topbar from "../vendor/topbar"
// CSS imports for editor and cropper (needed by hook modules)
import "@toast-ui/editor/dist/toastui-editor.css"
import "cropperjs/dist/cropper.css"

// Import all hooks from modular hook files
import {
  AutoDismissFlash,
  ShiftSelect,
  SortableList,
  DeviceType,
  MarkdownEditor,
  ImageCropper,
  ScrollToBottom,
  MessageInput,
  ChatPanel
} from "./hooks"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, AutoDismissFlash, ShiftSelect, SortableList, MarkdownEditor, DeviceType, ImageCropper, ScrollToBottom, MessageInput, ChatPanel},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// Copy text to clipboard when phx:copy event is dispatched
window.addEventListener("phx:copy", (event) => {
  const text = event.target.innerText.trim()
  navigator.clipboard.writeText(text)
})

// Deployment notification: show friendly message during cold deploys
window.addEventListener("phx:deployment-starting", (event) => {
  document.body.classList.add("deploying")
  const version = event.detail && event.detail.version
  if (version) {
    const titleEl = document.querySelector("#deployment-notice .font-semibold")
    if (titleEl) titleEl.textContent = `Updating ANIMINA to v${version}`
  }
})

// Clean up deploying state on reconnect
window.addEventListener("phx:page-loading-stop", () => {
  document.body.classList.remove("deploying")
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// Open user dropdown menu if ?menu=open is in the URL (used after role switch)
// We need to wait for LiveView to fully mount before manipulating the DOM
function openMenuIfRequested() {
  const urlParams = new URLSearchParams(window.location.search)
  if (urlParams.get("menu") === "open") {
    const dropdown = document.getElementById("user-dropdown")
    if (dropdown) {
      dropdown.classList.remove("hidden")
    }
    // Clean up the URL parameter
    urlParams.delete("menu")
    const newUrl = urlParams.toString()
      ? `${window.location.pathname}?${urlParams.toString()}`
      : window.location.pathname
    window.history.replaceState({}, "", newUrl)
  }
}

// Run after LiveView finishes loading (fires after initial mount and navigation)
window.addEventListener("phx:page-loading-stop", openMenuIfRequested, { once: true })

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
