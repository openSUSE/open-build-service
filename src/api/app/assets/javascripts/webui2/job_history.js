$(document).ready(function() {
  $('#jobhistory-table').dataTable({
    responsive: true,
    columnDefs: [
      { orderable: false, targets: [0, 8] },
      { visible: false, searchable: false, targets: [1, 5] },
      { orderData: 1, targets: 2 },
      { orderData: 5, targets: 6 },
    ],
    order: [[2, 'desc']]
  });
});
