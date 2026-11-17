import { Controller } from "@hotwired/stimulus"

// Copie une valeur que l'écran ne montre pas en entier (les identifiants d'un abonnement API). Les
// deux issues sont écrites par le serveur, cachées : on ne fait que montrer la bonne. La valeur
// n'est jamais journalisée, ni dans la console, ni avec l'erreur.
export default class extends Controller {
  static values = { text: String }
  static targets = ["copied", "failed"]

  async copy() {
    // fr-hidden et non `hidden` : le display de .fr-message l'emporterait sur l'attribut.
    this.copiedTarget.classList.add("fr-hidden")
    this.failedTarget.classList.add("fr-hidden")
    try {
      // Absent hors HTTPS ou refusé par le navigateur : les deux mènent au message d'échec.
      await navigator.clipboard.writeText(this.textValue)
      this.copiedTarget.classList.remove("fr-hidden")
    } catch {
      this.failedTarget.classList.remove("fr-hidden")
    }
  }
}
