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

export default ScrollToBottom
