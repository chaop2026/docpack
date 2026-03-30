import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["slider", "display", "hint"]

  connect() {
    this.update()
  }

  update() {
    const val = parseInt(this.sliderTarget.value)
    this.displayTarget.textContent = val

    const lang = document.documentElement.lang || "en"
    const hints = {
      en: {
        5: "Maximum compression",
        10: "Recommended",
        15: "Strong compression",
        20: "Strong compression",
        25: "Moderate",
        30: "Moderate",
        35: "Light compression",
        40: "Light compression",
        45: "Minimal",
        50: "Minimal"
      },
      ko: {
        5: "최대 압축",
        10: "추천",
        15: "강한 압축",
        20: "강한 압축",
        25: "보통",
        30: "보통",
        35: "가벼운 압축",
        40: "가벼운 압축",
        45: "최소 압축",
        50: "최소 압축"
      }
    }
    const h = (hints[lang] || hints.en)
    this.hintTarget.textContent = h[val] || ""
  }
}
