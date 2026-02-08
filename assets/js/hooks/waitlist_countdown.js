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

  // Show only the two most significant units
  if (weeks > 0) {
    return days > 0
      ? pluralize(weeks, labels.weeks) + " " + labels.and + " " + pluralize(days, labels.days)
      : pluralize(weeks, labels.weeks)
  }
  if (days > 0) {
    return hours > 0
      ? pluralize(days, labels.days) + " " + labels.and + " " + pluralize(hours, labels.hours)
      : pluralize(days, labels.days)
  }
  return hours > 0
    ? pluralize(hours, labels.hours) + " " + labels.and + " " + pluralize(minutes, labels.minutes)
    : pluralize(minutes, labels.minutes)
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
    const prefix = this.el.dataset.prefix || ""
    const expiredText = this.el.dataset.expiredText

    if (!endStr) return

    const endAt = new Date(endStr).getTime()
    const text = formatCountdown(endAt, locale)

    if (text) {
      this.el.textContent = prefix ? prefix + " " + text : text
    } else if (expiredText) {
      this.el.textContent = expiredText
      if (this._timer) clearInterval(this._timer)
    }
  }
}

export default WaitlistCountdown
