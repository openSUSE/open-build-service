import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "readonly", "button" ]

  connect() {
    const tooltip = new bootstrap.Tooltip(this.buttonTarget, { title: 'Copy to clipboard' })
  }

  copy(event) {
    this.readonlyTarget.select();
    document.execCommand('copy');

    const tooltip = bootstrap.Tooltip.getInstance(this.buttonTarget);
    tooltip.setContent({ '.tooltip-inner': 'Copied!' });
    this.buttonTarget.addEventListener('hidden.bs.tooltip', () => {
      tooltip.setContent({ '.tooltip-inner': 'Copy to clipboard' });
    })
  }
}
