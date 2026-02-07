import Editor from "@toast-ui/editor"

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

export default MarkdownEditor
