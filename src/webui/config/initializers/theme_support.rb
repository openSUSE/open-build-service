
if CONFIG['theme']
  Rails.logger.info "Using theme view path: #{RAILS_ROOT}/app/views/vendor/#{CONFIG['theme']}"
  ActionController::Base.prepend_view_path(RAILS_ROOT + "/app/views/vendor/#{CONFIG['theme']}")
end

