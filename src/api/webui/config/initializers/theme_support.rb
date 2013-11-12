if CONFIG['theme']
  theme_path = Rails.root.join('webui', 'app', 'views', 'webui', 'vendor', CONFIG['theme'])
  Rails.logger.info "Using theme view path: #{theme_path} -> #{ActionController::Base.view_paths.inspect}"
  ActionController::Base.prepend_view_path(theme_path)
end

