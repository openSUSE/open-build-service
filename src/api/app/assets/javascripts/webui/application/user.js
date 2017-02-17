$( document ).ready(function() {
    var url = $('.requests-datatable').first().data('source');
    var options = {
        order: [[0,'desc']],
        info: false,
        columnDefs: [
            // We only allow ordering for created, requester and priority.
            // Columns: created, source, target, requester, type, priority.
            { orderable: false, targets: [1,2,4,6,] }
        ],
        paging: 25,
        pagingType: "full_numbers",
        processing: true,
        serverSide: true,
        ajax: {
            url: url,
            data: { dataTableId: null }
        }
    };

    options.ajax.data.dataTableId = 'requests_in_table';
    $('#requests_in_table').dataTable(options);

    options.ajax.data.dataTableId = 'requests_out_table';
    $('#requests_out_table').dataTable(options);

    options.ajax.data.dataTableId = 'requests_declined_table';
    $('#requests_declined_table').dataTable(options);

    options.ajax.data.dataTableId = 'all_requests_table';
    $('#all_requests_table').dataTable(options);
});
