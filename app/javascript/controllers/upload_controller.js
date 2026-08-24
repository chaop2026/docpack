import { Controller } from "@hotwired/stimulus"

// Extensions accepted per MIME type. HEIC/HEIF often arrive with an empty
// `file.type` (Safari, some Android pickers), so extension is the reliable
// signal and MIME is only a fallback.
const EXT_BY_MIME = {
  "image/jpeg": ["jpg", "jpeg"],
  "image/png": ["png"],
  "image/webp": ["webp"],
  "image/heic": ["heic", "heif"],
  "image/heif": ["heic", "heif"]
}

// Characters of the filename kept pinned on the right so the extension is
// never the part that gets cut. See splitName().
const TAIL_CHARS = 10

export default class extends Controller {
  static targets = ["input", "preview", "zone"]

  connect() {
    // The controller wraps both the drop zone and the preview list, so drag
    // events bind to the zone rather than to this.element.
    this.zone = this.hasZoneTarget ? this.zoneTarget : this.element

    this.entries = []
    this.duplicateCount = 0
    this.dropError = false

    this.maxFiles = parseInt(this.meta("upload-max-files") || "20", 10)
    this.maxSize = parseInt(this.meta("upload-max-size") || String(10 * 1024 * 1024), 10)
    this.allowedExts = this.parseAccept(this.inputTarget.accept)

    // Everything below the picker — accumulating, removing, filtering invalid
    // files — depends on being able to write back to input.files. Where that
    // is impossible we degrade to a plain read-only listing instead of
    // throwing, and the click-to-select path keeps working untouched.
    this.canWriteFiles = this.detectFileWrite()

    if (this.canWriteFiles) {
      this.onDragOver = (e) => {
        e.preventDefault()
        this.zone.classList.add("upload-zone--over")
      }
      this.onDragLeave = (e) => {
        if (e.target === this.zone || !this.zone.contains(e.relatedTarget)) {
          this.zone.classList.remove("upload-zone--over")
        }
      }
      this.onDrop = (e) => this.handleDrop(e)

      this.zone.addEventListener("dragover", this.onDragOver)
      this.zone.addEventListener("dragleave", this.onDragLeave)
      this.zone.addEventListener("drop", this.onDrop)
    }

    this.render()
  }

  disconnect() {
    if (!this.canWriteFiles) return
    this.zone.removeEventListener("dragover", this.onDragOver)
    this.zone.removeEventListener("dragleave", this.onDragLeave)
    this.zone.removeEventListener("drop", this.onDrop)
  }

  // DataTransfer may be missing entirely, or present while input.files stays
  // read-only. Probe both on a throwaway input rather than trusting either.
  detectFileWrite() {
    try {
      const dt = new DataTransfer()
      const probe = document.createElement("input")
      probe.type = "file"
      probe.files = dt.files
      return probe.files !== null && probe.files.length === 0
    } catch {
      return false
    }
  }

  // --- i18n -----------------------------------------------------------------

  meta(name) {
    return document.querySelector(`meta[name="${name}"]`)?.content
  }

  i18n(key, vars = {}) {
    let str = this.meta(`i18n-${key}`) || key
    for (const [k, v] of Object.entries(vars)) {
      str = str.replaceAll(`%{${k}}`, v)
    }
    return str
  }

  // --- input handling -------------------------------------------------------

  // Wired from the views as `change->upload#preview`.
  preview() {
    this.addFiles(this.inputTarget.files)
  }

  // Every drop anywhere inside the zone is handled here, including drops that
  // land on the native input. Previously only a drop landing exactly on the
  // input did anything, so most of the visible dashed area silently ignored
  // files. The visual drop target and the real one must be the same rectangle.
  handleDrop(e) {
    this.zone.classList.remove("upload-zone--over")
    e.preventDefault()

    const dropped = e.dataTransfer?.files
    if (!dropped || dropped.length === 0) {
      // Requirement: never fail silently here. A folder drag, a drag from
      // another browser window, or a blocked source all land in this branch.
      this.dropError = true
      this.render()
      return
    }

    this.addFiles(dropped)
  }

  addFiles(fileList) {
    const incoming = Array.from(fileList || [])
    if (incoming.length === 0) return

    this.dropError = false

    // Degraded mode: input.files can't be rewritten, so the list can only
    // mirror what the browser already put there. Accumulating would show rows
    // that are not actually queued for upload.
    if (!this.canWriteFiles) {
      this.entries = incoming.map((file) => ({
        file,
        key: `${file.name}|${file.size}|${file.lastModified}`,
        error: null
      }))
      this.duplicateCount = 0
      this.render()
      return
    }

    let duplicates = 0

    for (const file of incoming) {
      const key = `${file.name}|${file.size}|${file.lastModified}`
      if (this.entries.some((entry) => entry.key === key)) {
        duplicates++
        continue
      }
      this.entries.push({ file, key, error: null })
    }

    this.duplicateCount = duplicates
    this.render()
  }

  remove(index) {
    this.entries.splice(index, 1)
    this.duplicateCount = 0
    this.dropError = false
    this.render()
  }

  // --- validation -----------------------------------------------------------

  parseAccept(accept) {
    const exts = new Set()
    for (const token of (accept || "").split(",")) {
      const mime = token.trim().toLowerCase()
      for (const ext of EXT_BY_MIME[mime] || []) exts.add(ext)
    }
    // No usable accept attribute → accept everything and let the server decide.
    return exts.size > 0 ? Array.from(exts) : null
  }

  validate() {
    let accepted = 0

    for (const entry of this.entries) {
      const ext = (entry.file.name.split(".").pop() || "").toLowerCase()
      const typeOk =
        this.allowedExts === null ||
        this.allowedExts.includes(ext) ||
        (EXT_BY_MIME[entry.file.type] || []).some((e) => this.allowedExts.includes(e))

      if (!typeOk) {
        entry.error = this.i18n("upload-reason-invalid-type")
      } else if (entry.file.size > this.maxSize) {
        entry.error = this.i18n("upload-reason-too-large")
      } else if (accepted >= this.maxFiles) {
        entry.error = this.i18n("upload-reason-too-many")
      } else {
        entry.error = null
        accepted++
      }
    }
  }

  // Rewrite the native input so the existing submit path in
  // progress_controller keeps reading `input.files` as its single source of
  // truth — rejected files are simply absent from it.
  syncInput() {
    if (!this.canWriteFiles) return false
    try {
      const dt = new DataTransfer()
      for (const entry of this.entries) {
        if (!entry.error) dt.items.add(entry.file)
      }
      this.inputTarget.files = dt.files
      return true
    } catch {
      // Constructor probe passed but a real write failed — fall back for the
      // rest of the page rather than leaving the list and the input disagreeing.
      this.canWriteFiles = false
      return false
    }
  }

  // --- rendering ------------------------------------------------------------

  // Split so the tail (always including the extension) sits in a
  // non-shrinking span. CSS text-overflow alone would eat the extension.
  splitName(name) {
    const dot = name.lastIndexOf(".")
    const ext = dot > 0 ? name.slice(dot) : ""
    const tailLen = Math.max(TAIL_CHARS, ext.length + 2)
    if (name.length <= tailLen + 4) return [name, ""]
    return [name.slice(0, name.length - tailLen), name.slice(name.length - tailLen)]
  }

  formatSize(bytes) {
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(0)} KB`
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  }

  render() {
    this.validate()
    this.syncInput()

    const host = this.previewTarget
    host.replaceChildren()

    if (!this.canWriteFiles) {
      host.appendChild(this.buildNotice(this.i18n("upload-dnd-unsupported"), "upload-notice--warn"))
    }

    if (this.dropError) {
      host.appendChild(this.buildNotice(this.i18n("upload-drop-failed"), "upload-notice--error"))
    }

    if (this.entries.length === 0) return

    const totalBytes = this.entries.reduce((sum, e) => sum + e.file.size, 0)
    const wrap = document.createElement("div")
    wrap.className = "file-list"

    const head = document.createElement("div")
    head.className = "file-list-head"

    const summary = document.createElement("span")
    summary.className = "file-list-summary"
    summary.textContent = this.i18n("upload-summary", {
      count: this.entries.length,
      size: this.formatSize(totalBytes)
    })
    head.appendChild(summary)

    if (this.duplicateCount > 0) {
      const dup = document.createElement("span")
      dup.className = "file-list-dup"
      dup.textContent = this.i18n("upload-duplicates", { count: this.duplicateCount })
      head.appendChild(dup)
    }

    wrap.appendChild(head)

    const items = document.createElement("ul")
    items.className = "file-list-items"
    if (this.entries.length > 5) items.classList.add("is-scrollable")

    this.entries.forEach((entry, index) => {
      items.appendChild(this.buildItem(entry, index))
    })

    wrap.appendChild(items)

    if (this.entries.some((e) => e.error)) {
      wrap.appendChild(this.buildNotice(this.i18n("upload-excluded-note"), "upload-notice--warn"))
    }

    host.appendChild(wrap)
  }

  buildItem(entry, index) {
    const li = document.createElement("li")
    li.className = entry.error ? "file-item file-item--error" : "file-item"

    const nameWrap = document.createElement("span")
    nameWrap.className = "file-name"
    nameWrap.title = entry.file.name

    const [head, tail] = this.splitName(entry.file.name)

    const headSpan = document.createElement("span")
    headSpan.className = "file-name-head"
    headSpan.textContent = head
    nameWrap.appendChild(headSpan)

    if (tail) {
      const tailSpan = document.createElement("span")
      tailSpan.className = "file-name-tail"
      tailSpan.textContent = tail
      nameWrap.appendChild(tailSpan)
    }

    li.appendChild(nameWrap)

    if (entry.error) {
      const reason = document.createElement("span")
      reason.className = "file-reason"
      reason.textContent = entry.error
      li.appendChild(reason)
    }

    const size = document.createElement("span")
    size.className = "file-size"
    size.textContent = this.formatSize(entry.file.size)
    li.appendChild(size)

    // Without file writing, removing a row could not actually dequeue the
    // file — so the control is omitted rather than shown and lying.
    if (this.canWriteFiles) {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "file-remove"
      btn.textContent = "×"
      btn.setAttribute("aria-label", this.i18n("upload-remove", { name: entry.file.name }))
      btn.addEventListener("click", (e) => {
        e.preventDefault()
        e.stopPropagation()
        this.remove(index)
      })
      li.appendChild(btn)
    }

    return li
  }

  buildNotice(text, modifier) {
    const el = document.createElement("p")
    el.className = `upload-notice ${modifier}`
    el.textContent = text
    return el
  }
}
