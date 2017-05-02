$( document ).ready(function() {
  $('.requests-datatable').each(function(index){
    // 1. Create DataTable
    var dataTableId = $(this).attr('id');
    var type_dropdown = $('select[name=request_type_select][data-table=' + dataTableId + ']');
    var state_dropdown = $('select[name=request_state_select][data-table=' + dataTableId + ']');
    var url = $(this).data('source');

    var table = $(this).dataTable({
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
        data: function(d) {
          d.dataTableId = dataTableId;
          d.type = type_dropdown.val();
          d.state = state_dropdown.val();
        }
      }
    });

    // 2. Reload button (if it exists)
    var reload_button = $('.result_reload[data-table=' + dataTableId + ']');
    var loading_spinner = $(reload_button).siblings('.result_spinner');

    reload_button.click(function(){
      reload_button.hide();
      loading_spinner.show();

      table.api().ajax.reload(function(){
        reload_button.show();
        loading_spinner.hide();
      }, false);
    });

    // 3. Type dropdown (if it exists)
    var loading_spinner = $('#spinner');

    type_dropdown.change(function(){
      loading_spinner.show();

      table.api().ajax.reload(function(){
        loading_spinner.hide();
      }, false);
    });

    // 4. State dropdown (if it exists)
    state_dropdown.change(function(){
      loading_spinner.show();

      table.api().ajax.reload(function(){
        loading_spinner.hide();
      }, false);
    });
  });
});
