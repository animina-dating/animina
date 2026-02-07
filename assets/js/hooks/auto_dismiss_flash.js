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

export default AutoDismissFlash
