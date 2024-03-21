$(window).scroll(function() {
  if (this.scrollY > 100) {
    $('.flash-and-announcement').addClass('sticking');
  } else {
    $('.flash-and-announcement').removeClass('sticking');
  }
});

// function to toggle visibility to the additional flash message information
function toggleMoreInfo(element, collapsibleContent) {
  collapsibleContent.classList.toggle("d-none");
  element.textContent = collapsibleContent.classList.contains('d-none') ? 'more info' : 'less info';
}

// Create a flash error message on the fly receiving
// a generic error message and the detailed response of an ajax call
function generateFlashError(xhdr, message) {
  var row = document.createElement("div");
  row.className = "row";

  var col = document.createElement("div");
  col.className = "col-12";
  row.appendChild(col);

  var alert = document.createElement("div");
  alert.className = "alert alert-dismissible fade show alert-error";
  alert.textContent = message;
  col.appendChild(alert);

  var icon = document.createElement("i");
  icon.className = "fas";
  alert.appendChild(icon);

  var moreInfoLink = document.createElement("button");
  moreInfoLink.className = "btn btn-link alert-link";
  moreInfoLink.textContent = "more info";
  alert.appendChild(moreInfoLink);

  var moreInfo = document.createElement("div");
  moreInfo.className = "moreInfo d-none";
  moreInfoLink.onclick = () => toggleMoreInfo(moreInfoLink, moreInfo);
  alert.appendChild(moreInfo);

  var moreInfoContent = document.createElement("div");
  moreInfoContent.className = "more-info-content";
  moreInfoContent.textContent = xhdr.responseText;
  moreInfo.appendChild(moreInfoContent);

  var closeButton = document.createElement("button");
  closeButton.className = "btn btn-close float-end";
  closeButton.setAttribute("type", "button");
  closeButton.setAttribute("data-bs-dismiss", "alert");
  closeButton.setAttribute("aria-label", "Close");
  alert.appendChild(closeButton);

  return row;
}
