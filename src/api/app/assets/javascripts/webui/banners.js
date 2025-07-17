function dismissBanner(bannerId, cookieId) { // jshint ignore:line
  const btn = document.getElementById(bannerId);
  if (btn) {
    btn.addEventListener("click", function () {
      // Expires in one year
      document.cookie = cookieId + "=true; path=/; max-age=" + 60 * 60 * 24 * 180;
    });
  }
}
