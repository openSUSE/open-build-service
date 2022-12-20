// BASE_BADGE_URL and BASE_PACKAGE_URL are set in the view
function buildBadge() {
  var badgeImageUrl = new URL(BASE_BADGE_URL); // jshint ignore:line
  badgeImageUrl.searchParams.set('type', $('#badge-style-selector').val());
  $('#badge-preview').attr("src", badgeImageUrl);
  return '[![build result](' + badgeImageUrl + ')](' + BASE_PACKAGE_URL + ')'; // jshint ignore:line
}

function badgeTextCopy() { // jshint ignore:line
  $('#copy-to-clipboard-readonly').val(buildBadge());
}
