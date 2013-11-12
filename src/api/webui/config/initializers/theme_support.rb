if CONFIG['theme']
  theme_path = Rails.root.join('webui', 'app', 'views', 'webui', 'vendor', CONFIG['theme'])
  ActionController::Base.prepend_view_path(theme_path)
end

