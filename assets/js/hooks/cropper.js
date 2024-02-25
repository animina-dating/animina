import LiveUploader from "../../../deps/phoenix_live_view/assets/js/phoenix_live_view/live_uploader";

export default ImageCropper = {
  mounted() {
    this.maxWidth = 300;
    this.maxHeight = 300;
    this.uploadTarget = this.el.dataset.uploadTarget;
    let inputId = this.el.dataset.input;
    let photoInput = document.getElementById(inputId);

    photoInput?.addEventListener("change", (e) => {
      e.preventDefault();
      e.stopImmediatePropagation();

      let file = e.target.files[0];
      if (file) {
        let image = new Image();
        image.src = this.createObjectURL(file);
        image.onload = (event) => {
          this.crop(event.target, 300, 300).toBlob(async (blob) => {
            const newFile = new File([blob], file.name, { type: file.type });

            const dataTransfer = new DataTransfer();
            dataTransfer.items.add(newFile);

            LiveUploader.trackFiles(
              photoInput,
              dataTransfer.files,
              dataTransfer
            );
            photoInput.dispatchEvent(new Event("input", { bubbles: true }));
          });
        };
      }
    });
  },

  /**
   *
   * Crops the image using a HTMLCanvas
   * @param {Event} src
   * @param {number} width
   * @param {number} height
   * @returns {HTMLCanvasElement}
   */

  crop(src, width, height) {
    let crop = width == 0 || height == 0;
    if (src.width <= width && height == 0) {
      width = src.width;
      height = src.height;
    }

    if (src.width > width && height == 0) {
      height = src.height * (width / src.width);
    }

    let xScale = width / src.width;
    let yScale = height / src.height;

    let scale = crop ? Math.min(xScale, yScale) : Math.max(xScale, yScale);

    //Create an empty canvas
    let canvas = document.createElement("canvas");
    canvas.width = width ? width : Math.round(src.width * scale);
    canvas.height = height ? height : Math.round(src.height * scale);
    canvas.getContext("2d").scale(scale, scale);

    //Crop to top center
    canvas
      .getContext("2d")
      .drawImage(
        src,
        (src.width * scale - canvas.width) * -0.5,
        (src.height * scale - canvas.height) * -0.5
      );

    return canvas;
  },

  /**
   *
   * @param {Blob | MediaSource} image
   * @returns {string}
   */

  createObjectURL(image) {
    var URL = window.URL || window.webkitURL || window.mozURL || window.msURL;
    return URL.createObjectURL(image);
  },
};
