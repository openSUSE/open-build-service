/* exported applySmartOverflow */
function applySmartOverflow() {
    $(".smart-overflow").each(function(_, el) {
        $(el).find(".ellipsis-link").remove();

        if (el.offsetWidth < el.scrollWidth) {
            var link = document.createElement('a');
            link.href = '#'; link.className = 'ellipsis-link';

            link.addEventListener('click', function (e) {
                e.preventDefault();
                el.classList.remove('smart-overflow');
            });
            el.appendChild(link);
        }
    });
}
