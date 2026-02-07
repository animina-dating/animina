import Sortable from "sortablejs"

// SortableList hook for drag-and-drop reordering using SortableJS (touch-friendly)
// Supports both single-container and multi-column modes
const SortableList = {
  mounted() {
    const isMultiColumn = this.el.dataset.multiColumn === "true"
    const columnCount = parseInt(this.el.dataset.columnCount || "1", 10)

    const options = {
      animation: 150,
      handle: ".drag-handle",
      ghostClass: "opacity-50",
      dragClass: "shadow-lg",
      delay: 150,        // Long-press delay for touch
      delayOnTouchOnly: true,
      touchStartThreshold: 5,
      // Exclude pinned items from dragging
      filter: "[data-pinned='true']",
    }

    if (isMultiColumn) {
      // Multi-column mode: enable cross-column dragging via shared group
      options.group = this.el.dataset.groupId || "gallery"
      options.onEnd = (evt) => {
        const id = evt.item.dataset.id
        const fromCol = parseInt(evt.from.dataset.columnIndex, 10)
        const toCol = parseInt(evt.to.dataset.columnIndex, 10)
        const localOld = evt.oldIndex
        const localNew = evt.newIndex
        const numCols = columnCount

        // Calculate global indices from local column positions
        // Items are distributed round-robin: item at local index L in column C
        // has global index = L * numCols + C
        const globalOld = localOld * numCols + fromCol
        const globalNew = localNew * numCols + toCol

        this.pushEvent("reposition", {
          id: id,
          old: globalOld,
          new: globalNew
        })
      }
    } else {
      // Single-column mode: simple reordering
      options.onEnd = (evt) => {
        const id = evt.item.dataset.id
        this.pushEvent("reposition", {
          id: id,
          old: evt.oldIndex,
          new: evt.newIndex
        })
      }
    }

    this.sortable = Sortable.create(this.el, options)
  },

  updated() {
    // SortableJS handles DOM changes automatically
  },

  destroyed() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  }
}

export default SortableList
