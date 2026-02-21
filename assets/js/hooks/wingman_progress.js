/**
 * WingmanProgress hook — client-side progress bar for LiveComponents.
 *
 * Reads `data-estimated-ms` and `data-started-at` from the element,
 * then updates the progress bar value and remaining-time label every second.
 * Progress is capped at 95% until the server removes the loading state.
 */
const WingmanProgress = {
  mounted() {
    this.estimatedMs = parseInt(this.el.dataset.estimatedMs, 10)
    this.startedAt = new Date(this.el.dataset.startedAt).getTime()
    this.bar = this.el.querySelector("[data-role='bar']")
    this.remaining = this.el.querySelector("[data-role='remaining']")

    this.tick()
    this.interval = setInterval(() => this.tick(), 1000)
  },

  tick() {
    const elapsed = Date.now() - this.startedAt
    const progress = Math.min(elapsed / this.estimatedMs, 0.95)
    const percent = Math.round(progress * 100)

    if (this.bar) {
      this.bar.value = percent
    }

    if (this.remaining) {
      const remainingMs = this.estimatedMs * (1 - progress)
      const remainingSec = Math.max(Math.round(remainingMs / 1000), 1)
      this.remaining.textContent = `~${remainingSec}s`
    }
  },

  destroyed() {
    if (this.interval) {
      clearInterval(this.interval)
    }
  }
}

export default WingmanProgress
