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
  var host = container.data('host');
  var el_text = container.find(".monitorpb_text");
  var ctrl = container.find(".progress-bar");

  var logfileinfo = $("#worker-display option:selected").val();

  if (delta) {
    container.removeClass('d-none');
    el_text.text(item[logfileinfo]);
    ctrl.css("width", delta + "%").attr("aria-valuenow", delta);
    var url = $('#workers').data('buildLogPath');
    url = url.replace('ARCH', item["arch"]);
    url = url.replace('PROJECT', item["project"]);
    url = url.replace('PACKAGE', item["package"]);
    url = url.replace('REPOSITORY', item["repository"]);

    el_text.attr("href", url);

    if (delta <= 50) {
      ctrl.addClass("text-bg-success");
      ctrl.removeClass('text-bg-warning text-bg-danger');
    } else if (delta >= 50 && delta < 80) {
      ctrl.addClass("text-bg-warning");
      ctrl.removeClass('text-bg-success text-bg-danger');
    } else {
      ctrl.addClass("text-bg-danger");
      ctrl.removeClass('text-bg-success text-bg-warning');
    }
    return null;
  }
  else {
    container.addClass('d-none');
    return { host: host, status: item["state"] || "idle" };
  }
}

function updateProgressBar()
{
  $("#workers-updating").fadeIn(1200);

  var monitorPath=$('#workers').data('monitorPath');

  $.getJSON(monitorPath, function(json) {
    var hostStates = {};
    $.each(json, function(i,item) {
            var state = processProgressBar(i, item);
            if (state && state.host && state.status) {
              if (!hostStates[state.host]) {
                hostStates[state.host] = { idle: 0, away: 0, dead: 0, down: 0 };
              }
              if (hostStates[state.host][state.status] !== undefined) {
                hostStates[state.host][state.status]++;
              }
            }
    });

    $('.builderbox').each(function() {
      var host = $(this).data('host');
      var states = hostStates[host] || { idle: 0, away: 0, dead: 0, down: 0 };
      
      $.each(['idle', 'away', 'dead', 'down'], function(index, state) {
        var badge = $(this).find('.' + state + '-badge');
        var count = states[state] || 0;
        badge.text(state + ': ' + count);
        if (count > 0) {
          badge.removeClass('d-none');
        } else {
          badge.addClass('d-none');
        }
      }.bind(this));
    });

    $("#workers-updating").fadeOut(1200);
  });
}
