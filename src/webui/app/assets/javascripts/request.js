function updateSupersedeAndDevelPackageDisplay() {
  if ($('#targetproject').length > 0 && $('#targetproject')[0].value.length > 0) {
    if ($('#targetproject')[0].value == $('#sourceproject')[0].value) {
      console.log("hide sourceupdate");
      $('#sourceupdate_display').hide();
      $('#sourceupdate').disable(); // hide 'sourceupdate' from Ruby
    } else {
      console.log("show sourceupdate"); 
      $('#sourceupdate_display').show();
      $('#sourceupdate').enable();
    }
    $.ajax({
      url: '<%= url_for(:controller => "request", :action => "list_small") %>',
      data: {
        project: $('#targetproject').attr('value'),
        package: $('#package').attr('value'),
        types: 'submit',
        states: 'new,review,declined',
      },
      success: function(data) {
        if (data.indexOf('No requests') == -1) {
          $('#supersede_display').show();
          $('#supersede').attr('checked', true);
          $('#pending_requests').html(data);
        } else {
          $('#supersede_display').hide();
          $('#supersede').attr('checked', false);
        }
      }
    })
    $.ajax({
      url: '<%= url_for(:controller => "package", :action => "devel_project") %>',
      data: {
        project: $('#targetproject')[0].value,
        package: $('#package')[0].value,
      },
      success: function(data) {
        if (data.length > 0 && data != '<%= @project.to_s %>') {
          $('#devel_project_warning').show();
          $('#devel_project_name').html(data);
        } else {
          $('#devel_project_warning').hide();
        }
      }
    })
  }
};

$('#devel_project_name').click(function() { $('#targetproject').attr('value', $('#devel_project_name').html()); });

updateSupersedeAndDevelPackageDisplay();

$('#targetproject').autocomplete({
  source: '<%= url_for :controller => :project, :action => :autocomplete_projects %>',
  minLength: 2,
  select: updateSupersedeAndDevelPackageDisplay,
  change: updateSupersedeAndDevelPackageDisplay,
});

/*$("#targetpackage").autocomplete('<%= url_for :controller => :project, :action => :autocomplete_packages %>', {
  minChars: 0, matchCase: true, max: 50, extraParams: {project: function() { return $("#target_project").val(); }}
});*/