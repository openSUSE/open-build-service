// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults


function toggle_display(element_id) {
  if (document.getElementById) {
    element = document.getElementById(element_id);
    if (element.style.display == "none") {
      element.style.display = "block";
    } else {
      element.style.display = "none";
    }
  }
}

