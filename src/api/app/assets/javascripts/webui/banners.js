/* exported dismissBanner */

function dismissBanner(bannerId, cookieId) {
  const btn = document.getElementById(bannerId);
  if (btn) {
    btn.addEventListener("click", function () {
      // Expires in one year
      document.cookie = cookieId + "=true; path=/; max-age=" + 60 * 60 * 24 * 180;
    });
  }
}
