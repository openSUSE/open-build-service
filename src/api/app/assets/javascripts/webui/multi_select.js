function collectMultiSelects() { // jshint ignore:line
  document.querySelectorAll('.form-multi-select').forEach(( multiSelect ) => {
    multiSelect.addEventListener("change", function(e) {
      var multiSelect = e.target.closest(".form-multi-select");
      setMultiSelectFormDisplay(multiSelect);
     });
     setMultiSelectFormDisplay(multiSelect);
  });
} 

function setMultiSelectFormDisplay(multiSelect) {
  var options = multiSelect.querySelectorAll('input');
  var button = multiSelect.querySelectorAll('button')[0];
  var selectedOptions = Array.from(options).filter(option => option.checked);
  button.innerHTML = `Select the ${multiSelect.dataset.name}`;
  if (selectedOptions.length > 0) {
    button.innerHTML = selectedOptions.map((option) => {
      var label = multiSelect.querySelectorAll(`[for="${option.id}"]`)[0];
      return label.innerHTML;
    }).join(', ');
  }
}
