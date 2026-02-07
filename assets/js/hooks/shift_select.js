// ShiftSelect hook for range selection when shift-clicking checkboxes
const ShiftSelect = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      const checkbox = e.target.closest("[data-appeal-checkbox]")
      if (!checkbox) return

      if (e.shiftKey) {
        e.preventDefault()
        const lastClickedId = checkbox.dataset.lastClickedId
        const currentId = checkbox.dataset.appealCheckbox

        if (lastClickedId && lastClickedId !== currentId) {
          this.pushEvent("select-range", {
            id: currentId,
            last_id: lastClickedId
          })
        } else {
          this.pushEvent("toggle-select", { id: currentId })
        }
      }
    })
  }
}

export default ShiftSelect
