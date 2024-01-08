import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "select" ]
  static values = { url: String }

  connect() {
    this.selectTarget.options.length = 0;
    this.disableSelect();
  }

  disableSelect() {
    this.selectTarget.setAttribute('disabled', '')
  }

  enableSelect() {
    this.selectTarget.removeAttribute('disabled')
  }

  emptySelect() {
    this.setSelect([]);
  }

  setSelect(results) {
    this.selectTarget.options.length = 0;
    if (results.length < 1)
      return this.disableSelect();
    results.forEach((result, key) => {
      this.selectTarget[key] = new Option(result, result)
    });
    this.enableSelect();
  }

  async setRepositories(event) {
    let url = new URL(this.urlValue, window.location.origin);
    url.searchParams.set('project', event.detail);

    try {
      const response = await fetch(url, {
        method: "GET",
        headers: {
          "Content-Type": "application/json",
        },
      });
      const data = await response.text();
      this.setSelect(JSON.parse(data));
    } catch {
      console.error("Failed to return results");
    }
  }
}
