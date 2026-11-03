/* exported setTemplateData */

/* global setupDropdownFilters */

// Remove this after PackageController#rdiff moves to DiffListComponent
$(function ($) {
  $('body').on('click', '.expand-diffs', function () {
    var forPackage = $(this).data('package');
    var details = $('details.card[data-package="' + forPackage + '"]');
    details.attr('open', 'open');
  });

  $('body').on('click', '.collapse-diffs', function () {
    var forPackage = $(this).data('package');
    var details = $('details.card[data-package="' + forPackage + '"]');
    details.attr('open', null);
  });
});

$(document).ready(function() {
  setupDropdownFilters();
  $('.btn-more').click(function() {
    var moreInfo = $('.more_info');
    moreInfo.toggleClass('d-none');
    $(this).text(moreInfo.hasClass('d-none') ? 'more info' : 'less info');
  });
});

async function setTemplateData(url) {
  try {
    var templateDescriptions = document.getElementsByClassName("template-description");
    Array.from(templateDescriptions).forEach((desc) => {
      desc.innerHTML = '';
    });
    var templateOptions = document.getElementById("package-template-options");
    templateOptions.innerHTML = '';
    var templateOption = document.getElementById("package-template-option");
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Response failed with status: ${response.status}`);
    }

    const result = await response.json();
    result.forEach((object) => {
      if (['name', 'title', 'description', 'url'].includes(object.name)) {
        var field = document.getElementById(`description-${object.name}`);
        field.innerHTML = object.description;
      } else {
        const extraOption = document.importNode(templateOption.content, true);
        var label = extraOption.querySelector(".template-name");
        label.textContent = object.title;
        label.setAttribute("for", `template_data_${object.name}`);
        var input = extraOption.querySelector("input");
        input.id = `template_data_${object.name}`;
        input.setAttribute("name", `template_data[${object.name}]`);
        var desc = extraOption.querySelector(".template-description");
        desc.innerHTML = object.description;
        templateOptions.appendChild(extraOption);
      }
    });
  } catch (error) {
    console.error(error.message);
  }
}
