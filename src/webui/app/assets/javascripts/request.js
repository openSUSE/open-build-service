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
                states: ['new','review','declined']
            },
            success: function (data) {
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
            success: function (data) {
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

$('#review_type').change(function () {
    switch ($('#review_type option:selected').attr('value')) {
        case "user":
        {
            $('#review_user_span').show();
            $('#review_group_span').hide();
            $('#review_project_span').hide();
            $('#review_package_span').hide();
        }
            break;
        case "group":
        {
            $('#review_user_span').hide();
            $('#review_group_span').show();
            $('#review_project_span').hide();
            $('#review_package_span').hide();
        }
            break;
        case "project":
        {
            $('#review_user_span').hide();
            $('#review_group_span').hide();
            $('#review_project_span').show();
            $('#review_package_span').hide();
        }
            break;
        case "package":
        {
            $('#review_user_span').hide();
            $('#review_group_span').hide();
            $('#review_project_span').show();
            $('#review_package_span').show();
        }
            break;
    }
});

$('#devel_project_name').click(function () {
    $('#targetproject').attr('value', $('#devel_project_name').html());
});

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

function requestAddAcceptRequestButton() {
    $('#accept_request_button').click(function (data) {
        /* Add some hidden elements to carry HTML form data that is found at other DOM places for design reasons.  */
        if ($('.submitter_is_maintainer_checkbox').size() != 0 &&
            $('.submitter_is_maintainer_checkbox').is(':checked')) {
            additional_element = '<input id="' + $('.submitter_is_maintainer_checkbox').attr('id') +
                '" name="' + $('.submitter_is_maintainer_checkbox').attr('name') +
                '" type="hidden" value="' + $('.submitter_is_maintainer_checkbox').attr('value') + '"/>'
            $('#request_handle_form p:last').append(additional_element);
        }
        if ($('.forward_checkbox').size() != 0 &&
            $('.forward_checkbox').is(':checked')) {
            $('.forward_checkbox').each(function (index) {
                additional_element = '<input id="' + $(this).attr('id') +
                    '" name="' + $(this).attr('name') +
                    '" type="hidden" value="' + $(this).attr('value') + '"/>'
                $('#request_handle_form p:last').append(additional_element);
            });
        }
    });
}

function requestShowReview() {
    $('.review_descision_link').click(function (event) {
        $('#review_descision_select li.selected').attr('class', '');
        $(event.target).parent().attr('class', 'selected')
        $('.review_descision_display').hide();
        index = event.target.id.split('review_descision_link_')[1]
        $('#review_descision_display_' + index).show();
        return false;
    });
}

function requestAddReviewAutocomplete() {
    $("#review_group").autocomplete({source: '<%= url_for :controller => :group, :action => :autocomplete %>',
        minChars: 2, matchCase: true, max: 50});
    $("#review_user").autocomplete({source: '<%= url_for :controller => :user, :action => :autocomplete %>',
        minChars: 2, matchCase: true, max: 50});
    $("#review_project").autocomplete({source: '<%= url_for :controller => :project, :action => :autocomplete_projects %>',
        minChars: 2, matchCase: true, max: 50});
    $("#review_package").autocomplete({source: '<%= url_for :controller => :project, :action => :autocomplete_packages %>',
        minChars: 0, matchCase: true, max: 50, extraParams: {
            project: function () {
                return $("#review_project").val();
            }
        }
    });
}
