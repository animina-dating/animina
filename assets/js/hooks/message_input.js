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
        // Clear textarea immediately after submit captures the value.
        // This prevents the debounced phx-change from restoring old content.
        this.el.value = ""
        this.autoGrow()
        // Sync empty value with LiveView's form tracking
        this.el.dispatchEvent(new Event("input", { bubbles: true }))
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
      this.el.value = ""
      this.autoGrow()
    })

    // Handle spellcheck result — set corrected text
    this.handleEvent("spellcheck_result", ({input_id, text}) => {
      if (input_id === this.el.id) {
        this.el.value = text
        this.saveDraft()
        this.autoGrow()
        this.el.dispatchEvent(new Event("input", { bubbles: true }))
      }
    })

    // Handle undo spellcheck — restore original text
    this.handleEvent("undo_spellcheck", ({input_id, text}) => {
      if (input_id === this.el.id) {
        this.el.value = text
        this.saveDraft()
        this.autoGrow()
        this.el.dispatchEvent(new Event("input", { bubbles: true }))
      }
    })

    // Handle greeting guard edit — restore text and focus
    this.handleEvent("greeting_guard_restore", ({input_id, text}) => {
      if (input_id === this.el.id) {
        this.el.value = text
        this.saveDraft()
        this.autoGrow()
        this.el.dispatchEvent(new Event("input", { bubbles: true }))
        this.el.focus()
        this.el.setSelectionRange(text.length, text.length)
      }
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

export default MessageInput
