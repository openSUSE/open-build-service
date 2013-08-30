function changeSubscription(eventObject) {
    var url = $(".subscriptions_form").data("ajax-url");
    var eventtype = $(this).attr("id").replace(/^receive-/, '');
    $.ajax(
        {
            url: url,
            method: 'post',
            data: {
                event: eventtype,
                receive: $(this).val() }
        });
}

function setupSubscriptions() {
    $(".receive_select").change(changeSubscription);
}
