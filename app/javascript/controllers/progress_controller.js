import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "fileInput", "progressArea", "progressBar", "progressText", "processingArea", "submitBtn"]

  connect() {
    this.formTarget.addEventListener("submit", (e) => this.handleSubmit(e))
  }

  i18n(key) {
    return document.querySelector(`meta[name="i18n-${key}"]`)?.content || key
  }

  handleSubmit(e) {
    e.preventDefault()

    const files = this.fileInputTarget.files
    if (!files || files.length === 0) {
      this.showToast(this.i18n("no-files"), "error")
      return
    }

    const formData = new FormData(this.formTarget)

    this.progressAreaTarget.style.display = "block"
    this.submitBtnTarget.disabled = true
    this.submitBtnTarget.classList.add("btn-disabled")

    const xhr = new XMLHttpRequest()

    xhr.upload.addEventListener("progress", (e) => {
      if (e.lengthComputable) {
        const percent = Math.round((e.loaded / e.total) * 100)
        this.progressBarTarget.style.width = `${percent}%`
        this.progressTextTarget.textContent = `${percent}%`
      }
    })

    xhr.upload.addEventListener("load", () => {
      this.progressBarTarget.style.width = "100%"
      this.progressAreaTarget.style.display = "none"
      this.processingAreaTarget.style.display = "flex"
    })

    xhr.addEventListener("load", () => {
      this.processingAreaTarget.style.display = "none"
      this.submitBtnTarget.disabled = false
      this.submitBtnTarget.classList.remove("btn-disabled")

      if (xhr.status >= 200 && xhr.status < 300) {
        const contentType = xhr.getResponseHeader("Content-Type")
        if (contentType && contentType.includes("text/vnd.turbo-stream.html")) {
          Turbo.renderStreamMessage(xhr.responseText)
        } else {
          document.getElementById("conversion_result").innerHTML = xhr.responseText
        }
        this.showToast(this.i18n("success"), "success")
      } else {
        this.showToast(this.i18n("error"), "error")
      }

      this.resetProgress()
    })

    xhr.addEventListener("error", () => {
      this.processingAreaTarget.style.display = "none"
      this.submitBtnTarget.disabled = false
      this.submitBtnTarget.classList.remove("btn-disabled")
      this.showToast(this.i18n("network-error"), "error")
      this.resetProgress()
    })

    xhr.open("POST", this.formTarget.action)
    xhr.setRequestHeader("Accept", "text/vnd.turbo-stream.html, text/html")
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    if (csrfToken) xhr.setRequestHeader("X-CSRF-Token", csrfToken)
    xhr.send(formData)
  }

  resetProgress() {
    this.progressBarTarget.style.width = "0%"
    this.progressTextTarget.textContent = "0%"
    this.progressAreaTarget.style.display = "none"
  }

  showToast(message, type) {
    const existing = document.querySelector(".toast")
    if (existing) existing.remove()

    const toast = document.createElement("div")
    toast.className = `toast toast-${type}`
    toast.innerHTML = `
      <span class="toast-icon">${type === "success" ? "✓" : "✕"}</span>
      <span class="toast-message">${message}</span>
    `
    document.body.appendChild(toast)

    requestAnimationFrame(() => toast.classList.add("toast-visible"))

    setTimeout(() => {
      toast.classList.remove("toast-visible")
      setTimeout(() => toast.remove(), 300)
    }, 4000)
  }
}
