function initInterconnect() {// jshint ignore:line
  $('.interconnect').click(function(){
    var $form = $('.interconnect-form');
    $.each($(this).data(), function(key, value) {
      $form.find("input[name='project[" + key +"]']").val(value);
    });
  });
}
