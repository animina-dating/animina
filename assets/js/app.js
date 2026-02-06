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
import {hooks as colocatedHooks} from "phoenix-colocated/animina"
import topbar from "../vendor/topbar"
// TOAST UI Markdown WYSIWYG Editor
import Editor from "@toast-ui/editor"
import "@toast-ui/editor/dist/toastui-editor.css"
// SortableJS for touch-friendly drag-and-drop
import Sortable from "sortablejs"
// Cropper.js for image cropping
import Cropper from "cropperjs"
import "cropperjs/dist/cropper.css"

const AutoDismissFlash = {
  mounted() {
    this.timer = setTimeout(() => {
      this.el.style.transition = "opacity 0.3s ease-out"
      this.el.style.opacity = "0"
      setTimeout(() => {
        this.pushEvent("lv:clear-flash", {key: this.el.id.replace("flash-", "")})
        this.el.remove()
      }, 300)
    }, 5000)
  },
  destroyed() {
    clearTimeout(this.timer)
  }
}

// ShiftSelect hook for range selection when shift-clicking checkboxes
const ShiftSelect = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      const checkbox = e.target.closest("[data-appeal-checkbox]")
      if (!checkbox) return

      if (e.shiftKey) {
        e.preventDefault()
        const lastClickedId = checkbox.dataset.lastClickedId
        const currentId = checkbox.dataset.appealCheckbox

        if (lastClickedId && lastClickedId !== currentId) {
          this.pushEvent("select-range", {
            id: currentId,
            last_id: lastClickedId
          })
        } else {
          this.pushEvent("toggle-select", { id: currentId })
        }
      }
    })
  }
}

// SortableList hook for drag-and-drop reordering using SortableJS (touch-friendly)
// Supports both single-container and multi-column modes
const SortableList = {
  mounted() {
    const isMultiColumn = this.el.dataset.multiColumn === "true"
    const columnCount = parseInt(this.el.dataset.columnCount || "1", 10)
    const columnIndex = parseInt(this.el.dataset.columnIndex || "0", 10)

    const options = {
      animation: 150,
      handle: ".drag-handle",
      ghostClass: "opacity-50",
      dragClass: "shadow-lg",
      delay: 150,        // Long-press delay for touch
      delayOnTouchOnly: true,
      touchStartThreshold: 5,
      // Exclude pinned items from dragging
      filter: "[data-pinned='true']",
    }

    if (isMultiColumn) {
      // Multi-column mode: enable cross-column dragging via shared group
      options.group = this.el.dataset.groupId || "gallery"
      options.onEnd = (evt) => {
        const id = evt.item.dataset.id
        const fromCol = parseInt(evt.from.dataset.columnIndex, 10)
        const toCol = parseInt(evt.to.dataset.columnIndex, 10)
        const localOld = evt.oldIndex
        const localNew = evt.newIndex
        const numCols = columnCount

        // Calculate global indices from local column positions
        // Items are distributed round-robin: item at local index L in column C
        // has global index = L * numCols + C
        const globalOld = localOld * numCols + fromCol
        const globalNew = localNew * numCols + toCol

        this.pushEvent("reposition", {
          id: id,
          old: globalOld,
          new: globalNew
        })
      }
    } else {
      // Single-column mode: simple reordering
      options.onEnd = (evt) => {
        const id = evt.item.dataset.id
        this.pushEvent("reposition", {
          id: id,
          old: evt.oldIndex,
          new: evt.newIndex
        })
      }
    }

    this.sortable = Sortable.create(this.el, options)
  },

  updated() {
    // SortableJS handles DOM changes automatically
  },

  destroyed() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  }
}

// DeviceType hook for detecting device type (mobile/tablet/desktop) based on viewport width
const DeviceType = {
  mounted() {
    this.reportDeviceType()
    this.handleResize = this.handleResize.bind(this)
    window.addEventListener("resize", this.handleResize)
  },

  handleResize() {
    clearTimeout(this.resizeTimer)
    this.resizeTimer = setTimeout(() => this.reportDeviceType(), 250)
  },

  reportDeviceType() {
    const width = window.innerWidth
    let deviceType
    if (width < 768) {
      deviceType = "mobile"
    } else if (width < 1024) {
      deviceType = "tablet"
    } else {
      deviceType = "desktop"
    }

    // Only report if device type changed
    if (this.currentDeviceType !== deviceType) {
      this.currentDeviceType = deviceType
      this.pushEvent("device_type_detected", { device_type: deviceType })
    }
  },

  destroyed() {
    clearTimeout(this.resizeTimer)
    window.removeEventListener("resize", this.handleResize)
  }
}

// MarkdownEditor hook for TOAST UI WYSIWYG Markdown editor
const MarkdownEditor = {
  mounted() {
    const initialValue = this.el.dataset.initialValue || ""
    const maxLength = parseInt(this.el.dataset.maxLength || "2000", 10)
    const inputName = this.el.dataset.inputName || "story_content"
    const hiddenInput = this.el.querySelector(`input[name="${inputName}"]`)

    // Create editor container (insert before the counter element if present)
    const editorContainer = document.createElement("div")
    editorContainer.id = `${this.el.id}-editor`

    // Insert editor container after the hidden input
    if (hiddenInput) {
      hiddenInput.after(editorContainer)
    } else {
      this.el.prepend(editorContainer)
    }

    // Initialize TOAST UI Editor
    this.editor = new Editor({
      el: editorContainer,
      height: "300px",
      initialEditType: "wysiwyg",
      previewStyle: "tab",
      initialValue: initialValue,
      usageStatistics: false,
      hideModeSwitch: false,
      toolbarItems: [
        ["heading", "bold", "italic", "strike"],
        ["hr", "quote"],
        ["ul", "ol"],
        ["link"]
      ],
      placeholder: this.el.dataset.placeholder || "Write your story here..."
    })

    // Character counter element (inside hook container or sibling)
    this.counterEl = this.el.querySelector("[data-char-counter]") ||
                     this.el.parentElement?.querySelector("[data-char-counter]")
    this.hiddenInput = hiddenInput
    this.maxLength = maxLength

    // Update hidden input and character counter on change
    this.editor.on("change", () => {
      const markdown = this.editor.getMarkdown()

      // Enforce max length
      if (markdown.length > maxLength) {
        const truncated = markdown.slice(0, maxLength)
        this.editor.setMarkdown(truncated)
        if (this.hiddenInput) {
          this.hiddenInput.value = truncated
          this.hiddenInput.dispatchEvent(new Event("input", { bubbles: true }))
        }
        if (this.counterEl) this.counterEl.textContent = `${maxLength}/${maxLength}`
      } else {
        if (this.hiddenInput) {
          this.hiddenInput.value = markdown
          this.hiddenInput.dispatchEvent(new Event("input", { bubbles: true }))
        }
        if (this.counterEl) this.counterEl.textContent = `${markdown.length}/${maxLength}`
      }
    })

    // Set initial counter value
    if (this.counterEl) {
      this.counterEl.textContent = `${initialValue.length}/${maxLength}`
    }
  },

  updated() {
    // If the modal is re-opened with new initial value, reset the editor
    const newValue = this.el.dataset.initialValue || ""
    if (this.editor && this.editor.getMarkdown() !== newValue) {
      this.editor.setMarkdown(newValue)
      if (this.counterEl) {
        this.counterEl.textContent = `${newValue.length}/${this.maxLength}`
      }
    }
  },

  destroyed() {
    if (this.editor) {
      this.editor.destroy()
      this.editor = null
    }
  }
}

// ImageCropper hook for Cropper.js integration
// Used for cropping avatar (mandatory square) and gallery photos with various aspect ratios
const ImageCropper = {
  mounted() {
    this.cropper = null
    this.mandatory = this.el.dataset.mandatory === "true"

    // Wire up button click handlers
    this.el.addEventListener("click", (e) => {
      const target = e.target.closest("[data-cropper-action]")
      if (!target) return

      const action = target.dataset.cropperAction
      switch (action) {
        case "apply":
          this.applyCrop()
          break
        case "cancel":
          this.cancelCrop()
          break
        case "skip":
          this.skipCrop()
          break
      }
    })

    // Watch for data attribute changes (when user changes aspect ratio)
    this.attributeObserver = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.type === "attributes" &&
            (mutation.attributeName === "data-aspect-ratio" ||
             mutation.attributeName === "data-orientation")) {
          this.updateAspectRatio()
        }
      }
    })
    this.attributeObserver.observe(this.el, { attributes: true })

    // Watch for LiveView's preview image to appear and read dimensions from it
    // This works because live_img_preview creates a blob URL we can analyze
    this.observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        for (const node of mutation.addedNodes) {
          if (node.nodeType === Node.ELEMENT_NODE) {
            // Look for img elements with blob: src (LiveView preview)
            const imgs = node.matches?.('img[src^="blob:"]') ? [node] :
                         node.querySelectorAll?.('img[src^="blob:"]') || []
            for (const img of imgs) {
              this.handlePreviewImage(img)
            }
          }
        }
      }
    })
    this.observer.observe(this.el, { childList: true, subtree: true })

    // Listen for modal close request from server
    this.handleEvent("hide-cropper", () => {
      this.hideCropper()
    })

    // Initialize aspect ratio
    this.updateAspectRatio()
  },

  updateAspectRatio() {
    const ratioStr = this.el.dataset.aspectRatio || "original"
    const orientation = this.el.dataset.orientation || "landscape"
    this.aspectRatioStr = ratioStr
    this.orientation = orientation
    this.numericRatio = this.calculateNumericRatio(ratioStr, orientation)
    console.log("ImageCropper: aspect ratio updated to", ratioStr, orientation, "numeric:", this.numericRatio)
  },

  calculateNumericRatio(ratioStr, orientation) {
    let ratio
    switch (ratioStr) {
      case "16:9":
        ratio = 16 / 9
        break
      case "4:3":
        ratio = 4 / 3
        break
      case "1:1":
        ratio = 1
        break
      case "original":
      default:
        return null // null means use original/no fixed ratio
    }
    // For portrait, invert the ratio
    if (orientation === "portrait" && ratio !== 1) {
      ratio = 1 / ratio
    }
    return ratio
  },

  imageMatchesRatio(width, height) {
    // If no fixed ratio (original), always matches
    if (this.numericRatio === null) {
      return true
    }

    const imageRatio = width / height
    const tolerance = 0.02 // 2% tolerance
    return Math.abs(imageRatio - this.numericRatio) / this.numericRatio < tolerance
  },

  handlePreviewImage(previewImg) {
    // Skip if already processed
    if (previewImg.dataset.cropperProcessed) return
    previewImg.dataset.cropperProcessed = "true"

    const checkDimensions = () => {
      const width = previewImg.naturalWidth
      const height = previewImg.naturalHeight

      if (width === 0 || height === 0) {
        // Image not loaded yet, wait
        return
      }

      // Refresh aspect ratio in case it changed
      this.updateAspectRatio()

      const matchesRatio = this.imageMatchesRatio(width, height)
      console.log("ImageCropper: preview dimensions", width, "x", height, "matchesRatio:", matchesRatio, "target:", this.aspectRatioStr)

      if (matchesRatio) {
        console.log("ImageCropper: image matches selected ratio, auto-approving")
        // Image already matches the selected ratio - auto-approve without cropper
        this.pushEvent("crop-applied", {
          x: 0,
          y: 0,
          width: width,
          height: height
        })

        // Generate preview thumbnail (maintaining aspect ratio)
        const previewSize = 200
        let previewWidth, previewHeight
        if (this.numericRatio === null || this.numericRatio === 1) {
          previewWidth = previewSize
          previewHeight = previewSize
        } else if (this.numericRatio > 1) {
          previewWidth = previewSize
          previewHeight = Math.round(previewSize / this.numericRatio)
        } else {
          previewWidth = Math.round(previewSize * this.numericRatio)
          previewHeight = previewSize
        }

        const canvas = document.createElement("canvas")
        canvas.width = previewWidth
        canvas.height = previewHeight
        const ctx = canvas.getContext("2d")
        ctx.drawImage(previewImg, 0, 0, previewWidth, previewHeight)
        const previewUrl = canvas.toDataURL("image/jpeg", 0.8)
        this.pushEvent("crop-preview", { previewUrl })
      } else {
        // Image doesn't match ratio - show cropper modal
        // Fetch the blob and convert to data URL for cropper
        fetch(previewImg.src)
          .then(r => r.blob())
          .then(blob => {
            const reader = new FileReader()
            reader.onload = () => this.showCropper(reader.result)
            reader.readAsDataURL(blob)
          })
      }
    }

    if (previewImg.complete && previewImg.naturalWidth > 0) {
      checkDimensions()
    } else {
      previewImg.onload = checkDimensions
    }
  },

  handleFileSelect(file) {
    // Read file as data URL and check dimensions
    const reader = new FileReader()
    reader.onload = (e) => {
      const dataUrl = e.target.result

      // Create a temporary image to check dimensions
      const img = new window.Image()
      img.onload = () => {
        const width = img.naturalWidth
        const height = img.naturalHeight

        // Refresh aspect ratio
        this.updateAspectRatio()
        const matchesRatio = this.imageMatchesRatio(width, height)

        if (matchesRatio) {
          // Image already matches the selected ratio - auto-approve without cropper
          this.pushEvent("crop-applied", {
            x: 0,
            y: 0,
            width: width,
            height: height
          })

          // Generate preview (maintaining aspect ratio)
          const previewSize = 200
          let previewWidth, previewHeight
          if (this.numericRatio === null || this.numericRatio === 1) {
            previewWidth = previewSize
            previewHeight = previewSize
          } else if (this.numericRatio > 1) {
            previewWidth = previewSize
            previewHeight = Math.round(previewSize / this.numericRatio)
          } else {
            previewWidth = Math.round(previewSize * this.numericRatio)
            previewHeight = previewSize
          }

          const canvas = document.createElement("canvas")
          canvas.width = previewWidth
          canvas.height = previewHeight
          const ctx = canvas.getContext("2d")
          ctx.drawImage(img, 0, 0, previewWidth, previewHeight)
          const previewUrl = canvas.toDataURL("image/jpeg", 0.8)
          this.pushEvent("crop-preview", { previewUrl })
        } else {
          // Image doesn't match ratio - show cropper
          this.showCropper(dataUrl)
        }
      }
      img.src = dataUrl
    }
    reader.readAsDataURL(file)
  },

  showCropper(dataUrl) {
    const modal = this.el.querySelector("[data-cropper-modal]")
    const image = this.el.querySelector("[data-cropper-image]")

    if (!modal || !image) {
      console.error("ImageCropper: modal or image element not found")
      return
    }

    // Refresh aspect ratio
    this.updateAspectRatio()

    // Set image source and show modal
    image.src = dataUrl
    modal.showModal()

    // Wait for image to load before initializing cropper
    image.onload = () => {
      // Destroy existing cropper if any
      if (this.cropper) {
        this.cropper.destroy()
      }

      // Determine aspect ratio for cropper
      // For "original", use NaN to allow free cropping
      const cropperAspectRatio = this.numericRatio === null ? NaN : this.numericRatio

      // Initialize Cropper.js with mobile-friendly options
      this.cropper = new Cropper(image, {
        aspectRatio: cropperAspectRatio,
        viewMode: 1,     // Restrict crop box to canvas
        dragMode: "move", // Move the image
        autoCropArea: 0.9, // 90% of image as initial crop
        responsive: true,
        restore: false,
        guides: true,
        center: true,
        highlight: false,
        cropBoxMovable: true,
        cropBoxResizable: true,
        toggleDragModeOnDblclick: false,
        // Mobile-friendly touch options
        background: true,
        modal: true,
        minContainerWidth: 200,
        minContainerHeight: 200,
      })
    }
  },

  hideCropper() {
    const modal = this.el.querySelector("[data-cropper-modal]")
    if (modal && modal.open) {
      modal.close()
    }
    if (this.cropper) {
      this.cropper.destroy()
      this.cropper = null
    }
  },

  applyCrop() {
    if (!this.cropper) return

    const data = this.cropper.getData(true) // Get rounded integer values

    // Send crop coordinates to LiveView
    this.pushEvent("crop-applied", {
      x: data.x,
      y: data.y,
      width: data.width,
      height: data.height
    })

    // Calculate preview dimensions maintaining aspect ratio
    const previewSize = 200
    let previewWidth, previewHeight
    const cropRatio = data.width / data.height

    if (cropRatio > 1) {
      previewWidth = previewSize
      previewHeight = Math.round(previewSize / cropRatio)
    } else if (cropRatio < 1) {
      previewWidth = Math.round(previewSize * cropRatio)
      previewHeight = previewSize
    } else {
      previewWidth = previewSize
      previewHeight = previewSize
    }

    // Get cropped preview as data URL for display
    const canvas = this.cropper.getCroppedCanvas({
      width: previewWidth,
      height: previewHeight,
      imageSmoothingEnabled: true,
      imageSmoothingQuality: "high"
    })

    if (canvas) {
      const previewUrl = canvas.toDataURL("image/jpeg", 0.8)
      this.pushEvent("crop-preview", { previewUrl })
    }

    this.hideCropper()
  },

  cancelCrop() {
    this.pushEvent("crop-cancelled", {})
    this.hideCropper()
  },

  skipCrop() {
    // Only for non-mandatory (gallery) uploads
    if (!this.mandatory) {
      this.pushEvent("crop-skipped", {})
      this.hideCropper()
    }
  },

  destroyed() {
    if (this.cropper) {
      this.cropper.destroy()
      this.cropper = null
    }
    if (this.observer) {
      this.observer.disconnect()
    }
    if (this.attributeObserver) {
      this.attributeObserver.disconnect()
    }
  }
}

// ScrollToBottom hook for message containers - scrolls to bottom on mount and updates
// Tracks whether the user has scrolled up to read history; only auto-scrolls if near the bottom
const ScrollToBottom = {
  mounted() {
    this.isNearBottom = true
    this.el.addEventListener("scroll", () => {
      const threshold = 100
      this.isNearBottom =
        this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight < threshold
    })
    this.scrollToBottom()
  },
  updated() {
    if (this.isNearBottom) {
      this.scrollToBottom()
    }
  },
  scrollToBottom() {
    this.el.scrollTop = this.el.scrollHeight
  }
}

// MessageInput hook — Enter sends the form, Shift+Enter inserts a newline,
// and the textarea auto-grows up to ~5 lines then scrolls internally.
// Persists draft text to both localStorage (instant) and server (debounced 2s).
const MessageInput = {
  mounted() {
    this.draftKey = this.el.dataset.draftKey
    this.serverDraftTimer = null

    this.el.addEventListener("keydown", (e) => {
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault()
        this.clearDraft()
        this.clearServerDraftTimer()
        // Find the enclosing form and request submit
        const form = this.el.closest("form")
        if (form) {
          form.dispatchEvent(
            new Event("submit", { bubbles: true, cancelable: true })
          )
        }
      }
    })
    this.el.addEventListener("input", () => {
      this.autoGrow()
      this.saveDraft()
      this.scheduleSaveDraftToServer()
    })

    // Handle server draft pushed on mount (compare timestamps, take newer)
    this.handleEvent("server_draft", ({content, timestamp}) => {
      const localTs = this.getLocalDraftTimestamp()
      if (!localTs || timestamp >= localTs) {
        this.el.value = content
        this.saveDraft()
        this.autoGrow()
        // Sync with LiveView form state
        this.el.dispatchEvent(new Event("input", { bubbles: true }))
      }
    })

    // Handle clear_draft event from server (after successful send)
    this.handleEvent("clear_draft", () => {
      this.clearDraft()
    })

    // Save draft to server before full page unload or LiveView navigation
    this._beforeUnload = () => {
      if (this.el.value) {
        this.clearServerDraftTimer()
        this.pushEvent("save_draft", { content: this.el.value })
      }
    }
    window.addEventListener("beforeunload", this._beforeUnload)
    window.addEventListener("phx:page-loading-start", this._beforeUnload)

    this.restoreDraft()
    this.autoGrow()
  },
  updated() {
    // Server reset textarea to "" after successful send — clear the draft
    if (this.el.value === "") {
      this.clearDraft()
    }
    this.autoGrow()
  },
  restoreDraft() {
    if (!this.draftKey) return
    const saved = localStorage.getItem(this.draftKey)
    if (saved) {
      this.el.value = saved
      // Sync with LiveView form state
      this.el.dispatchEvent(new Event("input", { bubbles: true }))
    }
  },
  saveDraft() {
    if (!this.draftKey) return
    const value = this.el.value
    if (value) {
      localStorage.setItem(this.draftKey, value)
      localStorage.setItem(this.draftKey + ":ts", Math.floor(Date.now() / 1000).toString())
    } else {
      localStorage.removeItem(this.draftKey)
      localStorage.removeItem(this.draftKey + ":ts")
    }
  },
  clearDraft() {
    if (!this.draftKey) return
    localStorage.removeItem(this.draftKey)
    localStorage.removeItem(this.draftKey + ":ts")
  },
  getLocalDraftTimestamp() {
    if (!this.draftKey) return null
    const ts = localStorage.getItem(this.draftKey + ":ts")
    return ts ? parseInt(ts, 10) : null
  },
  scheduleSaveDraftToServer() {
    this.clearServerDraftTimer()
    this.serverDraftTimer = setTimeout(() => {
      this.pushEvent("save_draft", { content: this.el.value })
      this.serverDraftTimer = null
    }, 2000)
  },
  clearServerDraftTimer() {
    if (this.serverDraftTimer) {
      clearTimeout(this.serverDraftTimer)
      this.serverDraftTimer = null
    }
  },
  autoGrow() {
    this.el.style.height = "auto"
    // Cap at roughly 5 lines (~7.5rem = 120px)
    const maxHeight = 120
    this.el.style.height = Math.min(this.el.scrollHeight, maxHeight) + "px"
    this.el.style.overflowY = this.el.scrollHeight > maxHeight ? "auto" : "hidden"
  },
  destroyed() {
    this.clearServerDraftTimer()
    window.removeEventListener("beforeunload", this._beforeUnload)
    window.removeEventListener("phx:page-loading-start", this._beforeUnload)
    // Save draft to server immediately on navigation away
    if (this.el.value) {
      this.pushEvent("save_draft", { content: this.el.value })
    }
  }
}

// ChatPanel hook — Escape to close, body overflow management for mobile drawer
const ChatPanel = {
  mounted() {
    this.handleKeydown = (e) => {
      if (e.key === "Escape") this.pushEvent("close_panel", {})
    }
    document.addEventListener("keydown", this.handleKeydown)
  },
  updated() {
    const open = this.el.dataset.open === "true"
    document.body.style.overflow = (open && window.innerWidth < 1024) ? "hidden" : ""
  },
  destroyed() {
    document.removeEventListener("keydown", this.handleKeydown)
    document.body.style.overflow = ""
  }
}

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

