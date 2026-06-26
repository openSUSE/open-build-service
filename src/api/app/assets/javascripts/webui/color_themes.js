(() => {
  'use strict';

  const setTheme = theme => {
    document.documentElement.dataset.bsTheme = theme;
  };

  const getTheme = () => {
    const userTheme = document.documentElement.dataset.bsThemeFromUser;
    if (userTheme === "system") {
      return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    }
    return userTheme;
  };

  setTheme(getTheme());

  window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => {
    setTheme(getTheme());
  });
})();
