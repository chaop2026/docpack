import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["banner"]

  connect() {
    if (localStorage.getItem("docpack_bookmark_dismissed")) {
      this.bannerTarget.remove()
    } else {
      this.bannerTarget.style.display = "flex"
    }
  }

  dismiss() {
    localStorage.setItem("docpack_bookmark_dismissed", "1")
    this.bannerTarget.style.display = "none"
  }
}
