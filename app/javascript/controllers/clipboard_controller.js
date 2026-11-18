import { Controller } from "@hotwired/stimulus"

// Le temps de lire la confirmation sur le bouton, avant qu'il ne reprenne son libellé.
const CONFIRMATION_DELAY = 2000

// Copie une valeur que l'écran ne montre pas en entier ; les messages viennent du serveur
// (<template>). La valeur n'est jamais journalisée, ni dans la console, ni avec l'erreur.
export default class extends Controller {
  static values = { text: String, doneLabel: String }
  static targets = ["button", "label", "messages", "copied", "failed"]

  connect() {
    this.idleLabel = this.labelTarget.textContent
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  async copy() {
    // Chaque champ efface d'abord son issue, celui-ci compris : un seul message à la fois, celui de
    // la dernière copie, sans quoi on ne saurait plus lequel est dans le presse-papiers.
    this.dispatch("copy", { target: window })
    try {
      // Absent hors HTTPS ou refusé par le navigateur : les deux mènent au message d'échec.
      await navigator.clipboard.writeText(this.textValue)
      this.show(this.copiedTarget)
      this.confirm()
    } catch {
      this.show(this.failedTarget)
    }
  }

  reset() {
    this.messagesTarget.replaceChildren()
    this.restore()
  }

  show(template) {
    this.messagesTarget.replaceChildren(template.content.cloneNode(true))
  }

  confirm() {
    this.labelTarget.textContent = this.doneLabelValue
    this.buttonTarget.classList.replace("fr-icon-clipboard-line", "fr-icon-check-line")
    this.timer = setTimeout(() => this.restore(), CONFIRMATION_DELAY)
  }

  restore() {
    clearTimeout(this.timer)
    this.labelTarget.textContent = this.idleLabel
    this.buttonTarget.classList.replace("fr-icon-check-line", "fr-icon-clipboard-line")
  }
}
