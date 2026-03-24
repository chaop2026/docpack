import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]

  toggle(event) {
    const item = event.currentTarget.closest("[data-accordion-target='item']")
    const isOpen = item.classList.contains("accordion-item--open")

    // Close all
    this.itemTargets.forEach(el => el.classList.remove("accordion-item--open"))

    // Toggle clicked
    if (!isOpen) item.classList.add("accordion-item--open")
  }
}
