function projectLink(projectName) {
 return $('<a>', { href: '/project/show/' + projectName, class: 'small mb-0', text: projectName });
}

function initInterconnect() {// jshint ignore:line
  $(document).on('ajax:success', 'button.interconnect', function(){
    var $parent = $(this).parents('.list-group-item');
    $parent.find('h5').removeClass('text-muted');
    $parent.find('.connected').removeClass('d-none');
    $parent.find('.interconnect-info i').addClass('text-secondary');
    var linkText = $parent.find('.interconnect-info small').text();
    $parent.find('.interconnect-info small').replaceWith(projectLink(linkText));
    $(this).remove();
  });
}

