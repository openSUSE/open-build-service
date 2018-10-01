$(function ($) {
  // There are three input fields on the package add file view: filename, url and choose file
  // and only one of them is required.
  // We just set HTML5 required tags on all of them and set to false with JS
  // when one of them is set.
  var $inputs = $('.package-add-file input');
  $inputs.on('change', function () {
    $inputs.not(this).prop('required', !$(this).val().length);
  });
});
