const LABELS = {
  en: {
    weeks: ["week", "weeks"],
    days: ["day", "days"],
    hours: ["hour", "hours"],
    minutes: ["minute", "minutes"],
    and: "and"
  },
  de: {
    weeks: ["Woche", "Wochen"],
    days: ["Tag", "Tage"],
    hours: ["Stunde", "Stunden"],
    minutes: ["Minute", "Minuten"],
    and: "und"
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
  const weeks = Math.floor(totalMinutes / (7 * 24 * 60))
  const days = Math.floor((totalMinutes % (7 * 24 * 60)) / (24 * 60))
  const hours = Math.floor((totalMinutes % (24 * 60)) / 60)
  const minutes = totalMinutes % 60

  const labels = getLabels(locale)
  const parts = []

  if (weeks > 0) parts.push(pluralize(weeks, labels.weeks))
  if (days > 0) parts.push(pluralize(days, labels.days))
  if (hours > 0) parts.push(pluralize(hours, labels.hours))
  parts.push(pluralize(minutes, labels.minutes))

  if (parts.length === 1) return parts[0]

  const last = parts.pop()
  return parts.join(", ") + " " + labels.and + " " + last
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
      if (this._timer) clearInterval(this._timer)
    }
  }
}

export default WaitlistCountdown
