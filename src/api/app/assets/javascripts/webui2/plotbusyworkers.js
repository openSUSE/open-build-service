function plotbusyworkers(data) { // jshint ignore:line
  $.plot($("#overallgraph"), [
    { data: data, label: "Busy workers", color: 3}
  ],
  {
    series: { stack: true, lines: { show: true, steps: false, fill: true } },
    xaxis: { mode: 'time' },
    yaxis: { min: 0, position: "left" },
  });
}
