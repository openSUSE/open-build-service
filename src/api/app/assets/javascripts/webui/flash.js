$(window).scroll(function() {
  if (this.scrollY > 100) {
    $('.flash-and-announcement').addClass('sticking');
  } else {
    $('.flash-and-announcement').removeClass('sticking');
  }
});

// Create a flash error message on the fly receiving
// a generic error message and the detailed response of an ajax call
function generateFlashError(message) { // jshint ignore:line
  var row = document.createElement("div");
  row.className = "row";

  row.innerHTML =
    `
      <div class='col-12'>
        <div class='alert alert-dismissible fade show alert-error'>
          ${message}
          <i class='fas'></i>
          <button class='btn btn-close float-end' type='button' data-bs-dismiss='alert' aria-label='Close' />
        </div>
      </div>
    `;

  return row;
}
