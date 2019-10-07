function initializePlots() {
  /* plot an empty set */
  plotValues({ 'building': [],
               'idle': [],
               'waiting': [],
               'blocked': [],
               'squeue_low': [],
               'squeue_med': [],
               'squeue_high': []
               });

  updatePlots();
  setInterval("updatePlots();", 80000);

  $("#architecture_display, #time_display").change(function() {
    $selector = $(this);
    $selector.find("option:selected").each(function() {
      option = ($selector.attr('id') == "architecture_display") ? 'archToShow' : 'timeToShow'
      $('#graphs').data(option, $(this).attr("value"));
    });
    updatePlots();
  });
}

function updatePlots() {
  var archToShow = $('#graphs').data('archToShow');
  var monitorPath= $('#graphs').data('monitorPath');
  var timeToShow = $('#graphs').data('timeToShow');

  $('#graphs i.fas.fa-spin').removeClass('d-none');
  $.ajax({ url: monitorPath,
    dataType: 'json',
    data: { "range": timeToShow,
            "arch": archToShow },
    success: function(json) {
      plotValues(json);
      $('#graphs i.fas.fa-spin').addClass('d-none');
      /* fade out now */
    }
  });
}

function plotValues(data) {
  eventsPlot(data);
  buildingPlot(data);
  jobPlot(data);
}

function eventsPlot(data) {
  $.plot($("#events"), [ { data: data.squeue_high, label: "High", color: "red" },
                         { data: data.squeue_med, label: "Medium", color: 1 },
                         { data: data.squeue_low, label: "Low Priority", color: 2 } ],
    {
      series: {
        lines: { show: true, fill: true },
        stack: true
      },
      legend: { noColumns: 3, position: "ne", container: "#legend-events" },
      xaxis: { mode: 'time' },
      yaxis: { min: 0, max: data.events_max, position: "left" }
    });
}

function buildingPlot(data) {
  $.plot($("#building"), [ { data: data.building, label: "building", color: 3},
                           { data: data.idle, label: "idle", color: 4 },
                           { data: data.away, label: "away", color: 6 },
                           { data: data.down, label: "down", color: 5 },
                           { data: data.dead, label: "dead", color: 7 } ],
    {
      series: {
        stack: true,
        lines: { show: true, steps: false, fill: true }
      },
      xaxis: { mode: 'time' },
      yaxis: { min: 0, position: "left" },
      legend: { noColumns: 3, position: "ne", container: "#legend-building" }
    });
}

function jobPlot(data) {
  $.plot($("#jobs"), [ { data: data.waiting, label: "Ready to build", color: 5},
                       {  data: data.blocked, label: "Blocked build job", color: 6 } ],
    {
      series: {
        stack: true,
        lines: { show: true, steps: false, fill: true },
      },
      xaxis: { mode: 'time' },
      yaxis: { max: data.jobs_max, position: "left" },
      legend: { noColumns: 3, position: "ne", container: "#legend-jobs" }
    });
}

function processProgressBar(id, item)
{
  var delta = item["delta"];

  var container = $('#p' + id);
  var el_text = container.find(".monitorpb_text");
  var ctrl = container.find(".progress-bar");

  var logfileinfo = $("#worker-display option:selected").val();

  if (delta) {
    el_text.text(item[logfileinfo]);
    ctrl.css("width", delta + "%").attr("aria-valuenow", delta);
    var url = $('#workers').data('buildLogPath');
    url = url.replace('ARCH', item["arch"]);
    url = url.replace('PROJECT', item["project"]);
    url = url.replace('PACKAGE', item["package"]);
    url = url.replace('REPOSITORY', item["repository"]);

    el_text.attr("href", url);

    if (delta <= 50) {
      ctrl.addClass("bg-success");
      ctrl.removeClass('bg-warning bg-danger');
    } else if (delta >= 50 && delta < 80) {
      ctrl.addClass("bg-warning");
      ctrl.removeClass('bg-success bg-danger');
    } else {
      ctrl.addClass("bg-danger");
      ctrl.removeClass('bg-success bg-warning');
    }
  }
  else {
    el_text.html("idle");
    ctrl.css("width", "0%");
    ctrl.css("aria-valuenow", 0)
    el_text.attr("href", "#");
  }
}

function updateProgressBar()
{
  $("#workers-updating").fadeIn(1200);

  var monitorPath=$('#workers').data('monitorPath');

  $.getJSON(monitorPath, function(json) {
    $.each(json, function(i,item) {
            processProgressBar(i, item);
    });
    $("#workers-updating").fadeOut(1200);
  });
}
