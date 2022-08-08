function handleReviewerCollapsibleForm() { // jshint ignore:line
  $('#add-review-dropdown-component .dropdown-item').on('click', function() {
    var review = $(this);

    $('#review-form-collapse h5 i').html(review.html());
    $('#review_id').val(review.data('review'));
  });

  $('#add-review-dropdown-component').on('shown.bs.dropdown', function () {
    $('#review-form-collapse').collapse('hide');
  });

  $('.toggle-review-form').on('click', function() {
    $('#review-form-collapse h5 i').html(this.dataset.reviewerIcon);
    $('#review_id').val(this.dataset.review);
  });

  $(document).click(function(e) {
    var reviewCollapsible = document.getElementById('review-form-collapse');
    if (!reviewCollapsible.contains(e.target)) {
      $('#review-form-collapse').collapse('hide');
    }
  });
}
