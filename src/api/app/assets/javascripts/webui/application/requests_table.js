$( document ).ready(function() {
  $('.requests-datatable').each(function(index){
    // 1. Create DataTable
    var url = $(this).data('source');
    var dataTableId = $(this).attr('id');
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
        data: { dataTableId: dataTableId }
      }
    };
    var table = $(this).dataTable(options);

    // 2. Reload button
    var reload_button = $('.result_reload[data-table=' + dataTableId + ']')
    var loading_spinner = $(reload_button).siblings('.result_spinner');

    reload_button.click(function(){
      reload_button.hide();
      loading_spinner.show();

      table.api().ajax.reload(function(){
        reload_button.show();
        loading_spinner.hide();
      }, false);
    });
  });
});
