import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "projectInput", "packageInput" ]

  emptyPackage(event) {
    this.packageInputTarget.value = '';
    this.packageInputTarget.setAttribute('disabled', '')
  }

  setProject(event) {
    let urlAttr = this.packageInputTarget.closest('[data-autocomplete-url-value]');
    let url = new URL(urlAttr.dataset.autocompleteUrlValue, window.location.origin);
    url.searchParams.set('project', event.detail);
    urlAttr.dataset.autocompleteUrlValue = url;
    this.packageInputTarget.removeAttribute('disabled');
  }
}
