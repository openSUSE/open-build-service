// BASE_BADGE_URL and BASE_PACKAGE_URL are set in the view
function buildBadge() {
  var badgeImageUrl = new URL(BASE_BADGE_URL); // jshint ignore:line
  badgeImageUrl.searchParams.set('type', $('#badge-style-selector').val());
  $('#badge-preview').attr("src", badgeImageUrl);
  if ($('#badge-format-selector').val() === 'markdown') {
    return '[![build result](' + badgeImageUrl + ')](' + BASE_PACKAGE_URL + ')'; // jshint ignore:line
  } else if ($('#badge-format-selector').val() === 'html') {
    return '<a href="' + BASE_PACKAGE_URL + '"><img src="' + badgeImageUrl + '" alt="build result"/></a>'; // jshint ignore:line
  }
  return badgeImageUrl;
}

function badgeTextCopy() { // jshint ignore:line
  $('#copy-to-clipboard-readonly').val(buildBadge());
}
