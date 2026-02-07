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

export default ChatPanel
