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
        pageLength: 25,
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

    options.ajax.data.dataTableId = 'reviews_in_table';
    $('#reviews_in_table').dataTable(options);

    $('.result_reload').click(function() {
      var that = this;
      $(this).hide();
      $(this).siblings('.result_spinner').show();
      var table = $(this).data('table');

      $('#' + table).DataTable().ajax.reload(function(){
        $(that).show();
        $(that).siblings('.result_spinner').hide();
      }, false);
    });

    $('#requests li a').click(function (event) {
      $(this).parent().parent().find('.result_reload').hide();
      $(this).siblings('.result_reload').show();
    });
});
