if CONFIG['theme']
  theme_path = Rails.root.join('app', 'views', 'webui', 'theme', CONFIG['theme'])
  ActionController::Base.prepend_view_path(theme_view_path)
end
