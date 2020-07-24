const langs = require("./data/langs");
const sections = require("./data/sites");
const localize = require("./util/localize");

document.addEventListener("DOMContentLoaded", function () {
  const megamenu = document.getElementById("megamenu");
  if (!megamenu) {
    return;
  }
  const content = sections
    .map(function (section) {
      const links = section.links
        .map(function (link) {
          return `<li>${link.icon} <a class="l10n" href="${link.url}" data-msg-id="${link.id}" data-url-id="${link.id}-url">${link.title}</a></li>`;
        })
        .join("");

      return `
        <div class="col-6 col-md-4 col-lg-2">
          <h5 class="megamenu-heading l10n" data-msg-id="${section.id}">${section.title}</h5>
          <ul class="megamenu-list">
            ${links}
          </ul>
        </div>
      `;
    })
    .join("");

  megamenu.innerHTML = `
    <div class="container-fluid">
      <div class="row">
        ${content}
      </div>
    </div>
  `;

  localize(".l10n", langs);
});
