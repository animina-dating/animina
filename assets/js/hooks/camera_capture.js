// CameraCapture hook — opens the device camera for selfie capture.
// Only shown on mobile devices where the HTML capture attribute works.
export default {
  mounted() {
    const isMobile = /Android|iPhone|iPod/i.test(navigator.userAgent) ||
      (/Macintosh/i.test(navigator.userAgent) && navigator.maxTouchPoints > 1);

    if (!isMobile) {
      this.el.classList.add("hidden");
      return;
    }

    this.el.addEventListener("click", (e) => {
      e.preventDefault();
      const inputName = this.el.dataset.inputName;
      const input = this.el.closest("form").querySelector(`input[type="file"][name="${inputName}"]`);
      if (input) {
        input.setAttribute("capture", this.el.dataset.capture || "environment");
        input.click();
        setTimeout(() => input.removeAttribute("capture"), 500);
      }
    });
  }
}
