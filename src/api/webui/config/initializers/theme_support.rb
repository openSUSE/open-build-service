if CONFIG['theme']
  theme_path = Rails.root.join('app', 'views', 'vendor', CONFIG['theme'])
  Rails.logger.info "Using theme view path: #{theme_path}"
  ActionController::Base.prepend_view_path(theme_path)
end

