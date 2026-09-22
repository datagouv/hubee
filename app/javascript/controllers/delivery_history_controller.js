import { Controller } from "@hotwired/stimulus"

// La trace est écrite par le portail avant que le fichier ne parte vers l'agent : on n'attend pas
// son téléchargement, seulement la récupération amont. D'où des délais courts, et bornés.
const DELAYS = [2000, 5000, 10000]

// Le lien de téléchargement vit hors du cadre : une action Stimulus ne l'atteindrait pas, d'où
// l'écoute sur le document.
const DOWNLOAD_LINK = "a[data-refreshes-history]"

// Posé avant la mise en cache de la page, relu à la restauration : une visite arrière rend
// l'instantané sans requête, donc avec un historique d'avant le téléchargement.
const RESTORED = "data-restored"

export default class extends Controller {
  static values = { src: String }

  connect() {
    this.timers = []
    this.awaiting = false

    this.onClick = (event) => {
      if (event.target.closest(DOWNLOAD_LINK)) this.schedule()
    }
    this.onVisible = () => {
      if (this.awaiting && document.visibilityState === "visible") this.reload()
    }
    this.onBeforeCache = () => this.element.setAttribute(RESTORED, "")

    document.addEventListener("click", this.onClick)
    document.addEventListener("visibilitychange", this.onVisible)
    document.addEventListener("turbo:before-cache", this.onBeforeCache)

    if (this.element.hasAttribute(RESTORED)) {
      this.element.removeAttribute(RESTORED)
      this.reload()
    }
  }

  // Les écouteurs vivent sur `document` : sans ce retrait, chaque visite en laisserait un de plus,
  // retenant le cadre détaché de la précédente. Les minuteurs, eux, tireraient à vide.
  disconnect() {
    this.cancel()
    document.removeEventListener("click", this.onClick)
    document.removeEventListener("visibilitychange", this.onVisible)
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
  }

  schedule() {
    this.cancel()
    this.awaiting = true
    this.timers = DELAYS.map((delay, index) =>
      setTimeout(() => {
        if (index === DELAYS.length - 1) this.awaiting = false
        this.reload()
      }, delay)
    )
  }

  cancel() {
    this.timers.forEach(clearTimeout)
    this.timers = []
    this.awaiting = false
  }

  // Poser `src` déclenche le premier chargement ; ensuite seul `reload()` le rejoue.
  reload() {
    if (this.element.src) this.element.reload()
    else this.element.src = this.srcValue
  }
}
