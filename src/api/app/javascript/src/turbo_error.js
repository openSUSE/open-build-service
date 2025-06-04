function renderTurboError(text) {
  const flash = document.getElementById('flash');
  const container = flash.querySelector('.col-12');
  const alert = document.createElement('div');
  alert.classList.add('alert', 'alert-danger');
  alert.innerHTML = text;
  container.appendChild(alert);
}

document.addEventListener("turbo:frame-missing", (event) => {
  const { detail: { response, visit } } = event;
  event.preventDefault();
  if (response.status === 200) {
    // Navigate to the page to see the content that didn't contain the frame, but loaded correctly otherwise
    visit(response.url);
  } else {
    const learn = document.createElement('a');
    learn.innerText = 'Learn more';
    learn.setAttribute('href', response.url);
    renderTurboError(`Loading the frame failed with error '${response.status}'. ${learn.outerHTML}`);
  }
});
