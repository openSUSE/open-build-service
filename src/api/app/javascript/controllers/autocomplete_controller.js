import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "results", "icon" ]
  static values = { url: String }

  connect() {
    // Creating the autocomplete dropdown menu
    const results = document.createElement("div");
    results.setAttribute("data-autocomplete-target", "results");
    results.classList.add("autocomplete");
    this.inputTarget.insertAdjacentElement("afterend", results);
  }

  setEmpty() {
    this.resultsTarget.innerHTML = '';
    const emptyText = document.createElement('span');
    emptyText.classList.add("autocomplete-item-text");
    emptyText.textContent = "Nothing found.";
    this.resultsTarget.appendChild(emptyText);
  }

  urlValueChanged() {
    if (this.hasResultsTarget)
      this.setEmpty();
  }

  setResults(results) {
    if (results.length < 1)
      return this.setEmpty()
    this.resultsTarget.innerHTML = '';
    results.forEach((result) => {
      let resultLink = document.createElement('a');
      resultLink.setAttribute("data-action", "autocomplete#setInput");
      resultLink.setAttribute("href", "#")
      resultLink.classList.add('autocomplete-item');
      resultLink.textContent = result;
      this.resultsTarget.appendChild(resultLink);
    });
  }

  setInput(event) {
    this.input(event.target.textContent);
    event.preventDefault();
  }

  input(value) {
    this.dispatch("setInput", { detail: value })
    this.inputTarget.value = value;
    this.hideResults();
  }

  iconLoad() {
    this.iconTarget.classList = 'fas fa-spinner fa-spin';
  }

  iconSearch() {
    this.iconTarget.classList = 'fas fa-search';
  }

  showResults() {
    this.resultsTarget.classList.add('show')
  }

  hideResults() {
    // We need a small delay to allow for clicking on the dropdown
    setTimeout(() => {
      this.resultsTarget.classList.remove('show')
    }, 200)
  }

  async search() {
    this.iconLoad();
    let query = this.inputTarget.value;
    this.dispatch("search", { detail: query })
    let url = new URL(this.urlValue, window.location.origin);
    url.searchParams.set('term', query);

    if (query.length >= 3) {
      try {
        const response = await fetch(url, {
          method: "GET",
          headers: {
            "Content-Type": "application/json",
          },
        });
        const raw_data = await response.text();
        const data = JSON.parse(raw_data);
        if (data.includes(query)) {
          this.input(query);
        } else {
          this.setResults(data);
          this.showResults();
        }
      } catch {
        console.error("Failed to return results");
      }
    } else {
      this.hideResults();
    }
    this.iconSearch();
  }
}
