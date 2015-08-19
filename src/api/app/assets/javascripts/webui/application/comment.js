function sz(t) {
    a = t.value.split('\n');
    b = 1;
    for (x = 0; x < a.length; x++) {
        if (a[x].length >= t.cols) b += Math.floor(a[x].length / t.cols);
    }
    b += a.length;
    if (b > t.rows) t.rows = b;
}

function setup_comment_toggles() {
    $('.togglable_comment').click(function () {
        var toggleid = $(this).data("toggle");
        $("#" + toggleid).toggle()
    });
}

