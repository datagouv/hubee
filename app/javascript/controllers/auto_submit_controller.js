import { Controller } from "@hotwired/stimulus"

// Envoie le formulaire dès son affichage, comme si l'agent avait cliqué : l'action qu'il a demandée
// avant une réauthentification part d'elle-même au retour. Le formulaire reste un POST ordinaire,
// avec son jeton CSRF ; sans JavaScript, il attend le clic.
export default class extends Controller {
  connect() {
    this.element.requestSubmit()
  }
}
