const LABELS = {
  en: {
    days: ["day", "days"],
    hours: ["hour", "hours"],
    minutes: ["minute", "minutes"]
  },
  de: {
    days: ["Tag", "Tage"],
    hours: ["Stunde", "Stunden"],
    minutes: ["Minute", "Minuten"]
  }
}

function getLabels(locale) {
  return LABELS[locale] || LABELS["en"]
}

function pluralize(count, [singular, plural]) {
  return `${count} ${count === 1 ? singular : plural}`
}

function formatCountdown(endAt, locale) {
  const now = Date.now()
  const diff = endAt - now

  if (diff <= 0) return null

  const totalMinutes = Math.floor(diff / 60000)
  const totalDays = Math.floor(totalMinutes / (24 * 60))
  const hours = Math.floor((totalMinutes % (24 * 60)) / 60)
  const minutes = totalMinutes % 60

  const labels = getLabels(locale)

  if (totalDays > 0) return pluralize(totalDays, labels.days)
  if (hours > 0) return pluralize(hours, labels.hours)
  return pluralize(minutes, labels.minutes)
}

const WaitlistCountdown = {
  mounted() {
    this._update()
    this._timer = setInterval(() => this._update(), 60000)
  },

  updated() {
    this._update()
  },

  destroyed() {
    if (this._timer) clearInterval(this._timer)
  },

  _update() {
    const endStr = this.el.dataset.endWaitlistAt
    const locale = this.el.dataset.locale || "en"
    const expiredText = this.el.dataset.expiredText

    if (!endStr) return

    const endAt = new Date(endStr).getTime()
    const text = formatCountdown(endAt, locale)

    if (text) {
      this.el.textContent = text
    } else if (expiredText) {
      this.el.textContent = expiredText
      const subtext = document.getElementById("waitlist-subtext")
      if (subtext) subtext.style.display = "none"
      if (this._timer) clearInterval(this._timer)
    }
  }
}

export default WaitlistCountdown
