import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "preview" ]
  static values = { url: String, packageUrl: String }

  url(event) {
    var badgeImageUrl = new URL(this.urlValue);
    badgeImageUrl.searchParams.set('type', event.target.value);
    this.previewTarget.setAttribute('src', badgeImageUrl);
    this.inputTarget.value = `[![build result](${badgeImageUrl})](${this.packageUrlValue})`;
  }
}
