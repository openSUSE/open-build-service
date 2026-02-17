/* jshint browser: true */
/* global $ */
(function () {
    const homeProject = $('body').data('home-project');
    if (!homeProject || !("Notification" in window)) return;

    const storageKey = `obs_notify_${homeProject}`;
    let lastResults = JSON.parse(localStorage.getItem(storageKey) || '{}');

    const poll = () => {
        $.getJSON(`/project/build_status_summary/${encodeURIComponent(homeProject)}`, (data) => {
            Object.entries(data).forEach(([pkg, status]) => {
                const terminal = ['succeeded', 'failed', 'broken', 'unresolvable'].includes(status);
                if (terminal && status !== lastResults[pkg] && lastResults[pkg] !== undefined) {
                    new Notification(`OBS: ${pkg}`, { body: `Build ${status}`, icon: '/favicon.ico' });
                }
            });
            lastResults = data;
            localStorage.setItem(storageKey, JSON.stringify(data));
        }).fail(() => console.debug("OBS Notifications: poll failed"));
    };

    if (Notification.permission === "default") Notification.requestPermission();
    poll();
    setInterval(poll, 60000);
})();
