# -----------------------------------------------------------------------------
# CE Image — single download
#
# Downloads the CE VHD image once and makes it available to both CE modules
# as a local file path. Each module then only needs to upload to its
# respective cloud (S3 for AWS, Blob for Azure).
# -----------------------------------------------------------------------------

locals {
  # Whether we need to download an image at all
  _need_image = (
    (var.aws_ce != null && var.aws_ce.ami_id == null) ||
    (var.azure_ce != null && var.azure_ce.image_id == null)
  )

  _image_basename = local._need_image ? basename(var.ce_image_url) : null
  _image_stripped = local._image_basename != null ? replace(replace(local._image_basename, ".gz", ""), ".tar", "") : null
  ce_image_dir    = "${path.root}/.ce-image-cache"
  ce_image_file   = local._need_image ? "${local.ce_image_dir}/${local._image_stripped}" : null
}

resource "terraform_data" "ce_image_download" {
  count = local._need_image ? 1 : 0

  triggers_replace = [var.ce_image_url]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-SCRIPT
      set -euo pipefail

      CACHE_DIR="${local.ce_image_dir}"
      IMAGE_FILE="${local.ce_image_file}"
      DOWNLOAD_URL="${var.ce_image_url}"

      mkdir -p "$CACHE_DIR"

      # Skip if image already cached
      if [[ -f "$IMAGE_FILE" ]]; then
        echo "CE image already cached: $IMAGE_FILE ($(du -h "$IMAGE_FILE" | cut -f1))"
        exit 0
      fi

      WORK_DIR=$(mktemp -d)
      trap 'rm -rf "$WORK_DIR"' EXIT

      echo "Downloading CE image..."
      curl -fL --progress-bar \
        -o "$WORK_DIR/$(basename "$DOWNLOAD_URL")" \
        "$DOWNLOAD_URL"

      # Decompress / extract
      if ls "$WORK_DIR"/*.gz 1>/dev/null 2>&1; then
        echo "Decompressing .gz ..."
        gunzip "$WORK_DIR/"*.gz
      fi
      if ls "$WORK_DIR"/*.tar 1>/dev/null 2>&1; then
        echo "Extracting .tar ..."
        cd "$WORK_DIR" && tar xf *.tar && rm -f *.tar && cd -
      fi

      # Find the image file
      RAW_FILE=$(find "$WORK_DIR" -type f \( -name "*.vhd" -o -name "*.vmdk" -o -name "*.raw" -o -name "*.img" -o -name "*.ova" \) | head -1)
      if [[ -z "$RAW_FILE" ]]; then
        RAW_FILE=$(find "$WORK_DIR" -type f -printf '%s %p\n' | sort -rn | head -1 | awk '{print $2}')
      fi

      echo "Moving image to cache: $IMAGE_FILE ($(du -h "$RAW_FILE" | cut -f1))"
      mv "$RAW_FILE" "$IMAGE_FILE"
    SCRIPT
  }
}
