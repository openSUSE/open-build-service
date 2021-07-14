function toggleDistribution() { // jshint ignore:line
  $('.distribution-input').on('change', function (){
    var distributionId = $( this ).attr('data-distribution');
    $('#distribution-' + distributionId + '-checkbox').prop( 'disabled', true );
    $('#distribution-' + distributionId + '-spinner').removeClass('d-none');
    $('#distribution-' + distributionId + '-form').submit();
  });
}
