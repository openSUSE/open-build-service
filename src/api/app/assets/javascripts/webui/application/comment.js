function sz(t) {
    var a = t.value.split('\n');
    var b = 1;
    for (var x = 0; x < a.length; x++) {
        if (a[x].length >= t.cols) b += Math.floor(a[x].length / t.cols);
    }
    b += a.length;
    if (b > t.rows) t.rows = b;
}

function setup_comment_toggles() {
    $('.togglable_comment').click(function () {
        var toggleid = $(this).data("toggle");
        $("#" + toggleid).toggle();
    });
}

