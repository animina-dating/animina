import Cropper from "cropperjs"

// ImageCropper hook for Cropper.js integration
// Used for cropping avatar (mandatory square) and gallery photos with various aspect ratios
const ImageCropper = {
  mounted() {
    this.cropper = null
    this.mandatory = this.el.dataset.mandatory === "true"

    // Wire up button click handlers
    this.el.addEventListener("click", (e) => {
      const target = e.target.closest("[data-cropper-action]")
      if (!target) return

      const action = target.dataset.cropperAction
      switch (action) {
        case "apply":
          this.applyCrop()
          break
        case "cancel":
          this.cancelCrop()
          break
        case "skip":
          this.skipCrop()
          break
      }
    })

    // Watch for data attribute changes (when user changes aspect ratio)
    this.attributeObserver = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.type === "attributes" &&
            (mutation.attributeName === "data-aspect-ratio" ||
             mutation.attributeName === "data-orientation")) {
          this.updateAspectRatio()
        }
      }
    })
    this.attributeObserver.observe(this.el, { attributes: true })

    // Watch for LiveView's preview image to appear and read dimensions from it
    // This works because live_img_preview creates a blob URL we can analyze
    this.observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        for (const node of mutation.addedNodes) {
          if (node.nodeType === Node.ELEMENT_NODE) {
            // Look for img elements with blob: src (LiveView preview)
            const imgs = node.matches?.('img[src^="blob:"]') ? [node] :
                         node.querySelectorAll?.('img[src^="blob:"]') || []
            for (const img of imgs) {
              this.handlePreviewImage(img)
            }
          }
        }
      }
    })
    this.observer.observe(this.el, { childList: true, subtree: true })

    // Listen for modal close request from server
    this.handleEvent("hide-cropper", () => {
      this.hideCropper()
    })

    // Initialize aspect ratio
    this.updateAspectRatio()
  },

  updateAspectRatio() {
    const ratioStr = this.el.dataset.aspectRatio || "original"
    const orientation = this.el.dataset.orientation || "landscape"
    this.aspectRatioStr = ratioStr
    this.orientation = orientation
    this.numericRatio = this.calculateNumericRatio(ratioStr, orientation)
    console.log("ImageCropper: aspect ratio updated to", ratioStr, orientation, "numeric:", this.numericRatio)
  },

  calculateNumericRatio(ratioStr, orientation) {
    let ratio
    switch (ratioStr) {
      case "16:9":
        ratio = 16 / 9
        break
      case "4:3":
        ratio = 4 / 3
        break
      case "1:1":
        ratio = 1
        break
      case "original":
      default:
        return null // null means use original/no fixed ratio
    }
    // For portrait, invert the ratio
    if (orientation === "portrait" && ratio !== 1) {
      ratio = 1 / ratio
    }
    return ratio
  },

  imageMatchesRatio(width, height) {
    // If no fixed ratio (original), always matches
    if (this.numericRatio === null) {
      return true
    }

    const imageRatio = width / height
    const tolerance = 0.02 // 2% tolerance
    return Math.abs(imageRatio - this.numericRatio) / this.numericRatio < tolerance
  },

  handlePreviewImage(previewImg) {
    // Skip if already processed
    if (previewImg.dataset.cropperProcessed) return
    previewImg.dataset.cropperProcessed = "true"

    const checkDimensions = () => {
      const width = previewImg.naturalWidth
      const height = previewImg.naturalHeight

      if (width === 0 || height === 0) {
        // Image not loaded yet, wait
        return
      }

      // Refresh aspect ratio in case it changed
      this.updateAspectRatio()

      const matchesRatio = this.imageMatchesRatio(width, height)
      console.log("ImageCropper: preview dimensions", width, "x", height, "matchesRatio:", matchesRatio, "target:", this.aspectRatioStr)

      if (matchesRatio) {
        console.log("ImageCropper: image matches selected ratio, auto-approving")
        // Image already matches the selected ratio - auto-approve without cropper
        this.pushEvent("crop-applied", {
          x: 0,
          y: 0,
          width: width,
          height: height
        })

        // Generate preview thumbnail (maintaining aspect ratio)
        const previewSize = 200
        let previewWidth, previewHeight
        if (this.numericRatio === null || this.numericRatio === 1) {
          previewWidth = previewSize
          previewHeight = previewSize
        } else if (this.numericRatio > 1) {
          previewWidth = previewSize
          previewHeight = Math.round(previewSize / this.numericRatio)
        } else {
          previewWidth = Math.round(previewSize * this.numericRatio)
          previewHeight = previewSize
        }

        const canvas = document.createElement("canvas")
        canvas.width = previewWidth
        canvas.height = previewHeight
        const ctx = canvas.getContext("2d")
        ctx.drawImage(previewImg, 0, 0, previewWidth, previewHeight)
        const previewUrl = canvas.toDataURL("image/jpeg", 0.8)
        this.pushEvent("crop-preview", { previewUrl })
      } else {
        // Image doesn't match ratio - show cropper modal
        // Fetch the blob and convert to data URL for cropper
        fetch(previewImg.src)
          .then(r => r.blob())
          .then(blob => {
            const reader = new FileReader()
            reader.onload = () => this.showCropper(reader.result)
            reader.readAsDataURL(blob)
          })
      }
    }

    if (previewImg.complete && previewImg.naturalWidth > 0) {
      checkDimensions()
    } else {
      previewImg.onload = checkDimensions
    }
  },

  handleFileSelect(file) {
    // Read file as data URL and check dimensions
    const reader = new FileReader()
    reader.onload = (e) => {
      const dataUrl = e.target.result

      // Create a temporary image to check dimensions
      const img = new window.Image()
      img.onload = () => {
        const width = img.naturalWidth
        const height = img.naturalHeight

        // Refresh aspect ratio
        this.updateAspectRatio()
        const matchesRatio = this.imageMatchesRatio(width, height)

        if (matchesRatio) {
          // Image already matches the selected ratio - auto-approve without cropper
          this.pushEvent("crop-applied", {
            x: 0,
            y: 0,
            width: width,
            height: height
          })

          // Generate preview (maintaining aspect ratio)
          const previewSize = 200
          let previewWidth, previewHeight
          if (this.numericRatio === null || this.numericRatio === 1) {
            previewWidth = previewSize
            previewHeight = previewSize
          } else if (this.numericRatio > 1) {
            previewWidth = previewSize
            previewHeight = Math.round(previewSize / this.numericRatio)
          } else {
            previewWidth = Math.round(previewSize * this.numericRatio)
            previewHeight = previewSize
          }

          const canvas = document.createElement("canvas")
          canvas.width = previewWidth
          canvas.height = previewHeight
          const ctx = canvas.getContext("2d")
          ctx.drawImage(img, 0, 0, previewWidth, previewHeight)
          const previewUrl = canvas.toDataURL("image/jpeg", 0.8)
          this.pushEvent("crop-preview", { previewUrl })
        } else {
          // Image doesn't match ratio - show cropper
          this.showCropper(dataUrl)
        }
      }
      img.src = dataUrl
    }
    reader.readAsDataURL(file)
  },

  showCropper(dataUrl) {
    const modal = this.el.querySelector("[data-cropper-modal]")
    const image = this.el.querySelector("[data-cropper-image]")

    if (!modal || !image) {
      console.error("ImageCropper: modal or image element not found")
      return
    }

    // Refresh aspect ratio
    this.updateAspectRatio()

    // Set image source and show modal
    image.src = dataUrl
    modal.showModal()

    // Wait for image to load before initializing cropper
    image.onload = () => {
      // Destroy existing cropper if any
      if (this.cropper) {
        this.cropper.destroy()
      }

      // Determine aspect ratio for cropper
      // For "original", use NaN to allow free cropping
      const cropperAspectRatio = this.numericRatio === null ? NaN : this.numericRatio

      // Initialize Cropper.js with mobile-friendly options
      this.cropper = new Cropper(image, {
        aspectRatio: cropperAspectRatio,
        viewMode: 1,     // Restrict crop box to canvas
        dragMode: "move", // Move the image
        autoCropArea: 0.9, // 90% of image as initial crop
        responsive: true,
        restore: false,
        guides: true,
        center: true,
        highlight: false,
        cropBoxMovable: true,
        cropBoxResizable: true,
        toggleDragModeOnDblclick: false,
        // Mobile-friendly touch options
        background: true,
        modal: true,
        minContainerWidth: 200,
        minContainerHeight: 200,
      })
    }
  },

  hideCropper() {
    const modal = this.el.querySelector("[data-cropper-modal]")
    if (modal && modal.open) {
      modal.close()
    }
    if (this.cropper) {
      this.cropper.destroy()
      this.cropper = null
    }
  },

  applyCrop() {
    if (!this.cropper) return

    const data = this.cropper.getData(true) // Get rounded integer values

    // Send crop coordinates to LiveView
    this.pushEvent("crop-applied", {
      x: data.x,
      y: data.y,
      width: data.width,
      height: data.height
    })

    // Calculate preview dimensions maintaining aspect ratio
    const previewSize = 200
    let previewWidth, previewHeight
    const cropRatio = data.width / data.height

    if (cropRatio > 1) {
      previewWidth = previewSize
      previewHeight = Math.round(previewSize / cropRatio)
    } else if (cropRatio < 1) {
      previewWidth = Math.round(previewSize * cropRatio)
      previewHeight = previewSize
    } else {
      previewWidth = previewSize
      previewHeight = previewSize
    }

    // Get cropped preview as data URL for display
    const canvas = this.cropper.getCroppedCanvas({
      width: previewWidth,
      height: previewHeight,
      imageSmoothingEnabled: true,
      imageSmoothingQuality: "high"
    })

    if (canvas) {
      const previewUrl = canvas.toDataURL("image/jpeg", 0.8)
      this.pushEvent("crop-preview", { previewUrl })
    }

    this.hideCropper()
  },

  cancelCrop() {
    this.pushEvent("crop-cancelled", {})
    this.hideCropper()
  },

  skipCrop() {
    // Only for non-mandatory (gallery) uploads
    if (!this.mandatory) {
      this.pushEvent("crop-skipped", {})
      this.hideCropper()
    }
  },

  destroyed() {
    if (this.cropper) {
      this.cropper.destroy()
      this.cropper = null
    }
    if (this.observer) {
      this.observer.disconnect()
    }
    if (this.attributeObserver) {
      this.attributeObserver.disconnect()
    }
  }
}

export default ImageCropper
