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

export default DeviceType
