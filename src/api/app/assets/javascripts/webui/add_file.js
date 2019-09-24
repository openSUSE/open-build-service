function createInputs(item) {
  var filelist = $(item.list);
  var li = document.createElement('li');
  li.setAttribute('class', 'd-flex list-group-item align-items-center');
  var i = document.createElement('i');
  i.setAttribute('class', 'fa fa-fw mr-3 fa-' + item.icon);
  li.appendChild(i);
  item.inputs.forEach(function(input) {
    var field = document.createElement('input');
    field.value = input.value;
    field.name = input.name;
    field.setAttribute('class', 'form-control mr-3');
    field.setAttribute('required', 'true');
    field.setAttribute('placeholder', input.placeholder);
    li.appendChild(field);
  });
  if(item.remove) {
    var remove = document.createElement('i');
    remove.setAttribute('class', 'fa fa-times text-danger');
    remove.id = 'remove-row';
    li.appendChild(remove);
  }
  filelist.append(li);
}

function toggleUpload(value) {
  $('#submit_button').prop('disabled', value === 0);
}

$(document).ready(function() {
  $('#files').on('change', function(event) {
    $('#filelist').empty();
    var files = event.target.files;
    for (var i = 0; i < files.length; i++) {
      var f = files[i];
      createInputs({list: '#filelist', icon: 'file-alt', remove: false, inputs: [{value: f.name, name: 'filenames[' + f.name + ']', placeholder: 'Filename'}]});
    }
    toggleUpload($('#filelist > li').length);
  });
  $('#add-empty-file').on('click', function(event) { // jshint ignore:line
    createInputs({list: '#namelist', icon: 'file', remove: true, inputs: [{name: 'files_new[]', placeholder: 'Filename', value: ''}]});
    toggleUpload($('#namelist > li').length);
  });
  $('#add-remote-file').on('click', function(event) { // jshint ignore:line
    createInputs({list: '#linklist', icon: 'link', remove: true, inputs: [{name: 'file_urls[]', placeholder: 'Name', value: ''}, {name: 'file_urls[]', placeholder: 'URL', value: ''}]});
    toggleUpload($('#linklist > li').length);
  });
});

$(document).on('click', '#remove-row', function() {
  $(this).parent().remove();
  toggleUpload($('#linklist > li').length + $('#namelist > li').length + $('#filelist > li').length);
});
