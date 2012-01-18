require "cgi"


# ==============================================================================
# The HtmlReport object can store results from executed tests and format them
# into a nice html table with colored status and detailed traces for the fails
#
class HtmlReport


  def initialize
    @html = HEADER
  end
  
  
  # ============================================================================
  # Adds a completed test to the html report.
  # @param [TestCase] test
  #
  def add test
    onclick = if test.status ==:fail then "onclick='toggle(this)'" else "" end
    hover = "onmouseover='select(this)' onmouseout='unselect(this)'"
    report_row  = "<tr>"
    report_row +=   "<td class='name' #{onclick} #{hover}>#{test.name}</td>"
    report_row +=   "<td class='time' #{onclick} #{hover}>#{test.time_started.strftime('%m\%d\%Y %H:%M:%S')}</td>"
    report_row +=   "<td class='time' #{onclick} #{hover}>#{test.time_completed.strftime('%m\%d\%Y %H:%M:%S')}</td>"
    report_row +=   "<td class='#{test.status}' #{onclick} #{hover}>#{test.status}</td></tr>"
    report_row += "</tr>"
    @html += report_row
    
    if test.status == :fail then
      report_row  = "<tr class='details'>"
      report_row +=   "<td colspan='4'>"
      report_row +=     "<div state='ready' style='height: 0px'>#{CGI.escapeHTML test.message.strip}</div>"
      report_row +=   "</td>"
      report_row += "</tr>"
      @html += report_row
    end
  end

  
  # ============================================================================
  # Saves the html report to the given path.
  # @param [String] path the path of the new report
  #
  def save path
    @html += FOOTER
    path += ".html" unless path.end_with? ".html"
    report = File.new path, "w"
    report.write @html
    report.close
  end


HEADER = <<HTML
<html>
  <head>
    <script type="text/javascript">
      function toggle(element) {
        var row = element.parentNode.nextSibling;
        var div = row.childNodes[0].childNodes[0];
        if(div.getAttribute('state') != 'moving') {
          div.setAttribute('state', 'moving');
          div.style.overflow = 'hidden';
          if(row.style.display == 'table-row') {
            hide(div); 
          } 
          else { 
            row.style.display = 'table-row'; 
            show(div); 
          }  
        }
      }
      function show(div) {
        var diff = div.scrollHeight - div.clientHeight;
        if(diff > 0) {
          if(diff < 26) { resize(div, diff); }
          else          { resize(div, 26);   }
          window.setTimeout( function() { show(div); } ,  15 ); 
        }
        else {
          div.style.overflow = 'auto';
          if(div.clientHeight < div.scrollHeight) { 
            show(div); 
          }
          else {
            div.setAttribute('state', 'ready');
          }
        }
      }
      function hide(div) {
        if(div.clientHeight >= 45) {
          resize(div, -45);
          window.setTimeout( function() { hide(div); } ,  15 );
        }
        else {
          div.style.height = 0;
          div.parentNode.parentNode.style.display = 'none'; 
          div.setAttribute('state', 'ready'); 
        }
      }
      function resize(object, delta) {
        object.style.height = (parseInt(object.style.height) + delta);
      }
      function select(element) {
        var row = element.parentNode;
        row.childNodes[0].className = "name name_highlight";
        row.childNodes[1].className = "time time_highlight";
        row.childNodes[2].className = "time time_highlight"; 
        row.childNodes[3].className = row.childNodes[3].className + " " + row.childNodes[3].className + "_highlight";
      }
      function unselect(element) {
        var row = element.parentNode;
        row.childNodes[0].className = "name";
        row.childNodes[1].className = "time";
        row.childNodes[2].className = "time";
        row.childNodes[3].className = row.childNodes[3].className.substr(0,4); 
      }
    </script>
    <title>OBS Automated Test Results</title>
    <style type='text/css'>
      table      { border-width: 2px; font-family: "monospace";
                   border-style: solid; width: 800px;
                   border-collapse: collapse; 
                   border-color: black; margin: auto; }
      th         { border-width: 1px; 
                   padding: 5px;
                   border-style: solid;
                   background-color: #EFEDFC; }
      tr.details { display: none; }
      td         { border-color: black; }
      td.name    { border-width: 1px; 
                   padding: 2px;
                   padding-left: 5px;
                   padding-right: 20px;
                   border-style: solid;
                   background-color: #F7F5FE; 
                   font-size: 13px;
                   font-style: italic;
                   text-align:left; }
      td.time    { border-width: 1px; 
                   padding: 2px;
                   padding-left: 5px;
                   border-style: solid;
                   background-color: #F7F5FE; 
                   font-size: 12px;
                   text-align:left; }
      td.pass    { border-width: 1px; 
                   padding: 2px; 
                   border-style: solid;
                   background-color: #4CC552; 
                   font-size: 12px;
                   font-weight: bold;
                   text-align:center; }
      td.fail    { border-width: 1px;
                   padding: 2px;
                   border-style: solid;
                   background-color: #F62817; 
                   font-size: 12px;
                   font-weight: bold;
                   text-align:center; }
      td.skip    { border-width: 1px;
                   padding: 2px;
                   border-style: solid;
                   background-color: #2E64FE;
                   font-size: 12px;
                   font-weight: bold;
                   text-align:center; }
      div        { white-space: pre; font-size: 11px;
                   color:red; background-color: #FDF2F4;
                   overflow:hidden; width:794px; height:0px; }
      td.name_highlight { background-color: #D8D8D8; }
      td.time_highlight { background-color: #D8D8D8; }
      td.pass_highlight { background-color: #04B404; }
      td.fail_highlight { background-color: #B40404; }
      td.skip_highlight { background-color: #0040FF; }
    </style>
  <head>
  <body>
    <table>
      <tr>
        <th>Test</th>
        <th>Started at</th>
        <th>Completed at</th>
        <th>Result</th>
      </tr>
HTML

FOOTER = <<HTML
    </table>
  </body>
</html>
HTML

  
end
