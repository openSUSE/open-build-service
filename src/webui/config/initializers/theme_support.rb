
if CONFIG['theme']
  Rails.logger.info "Using theme view path: #{RAILS_ROOT}/app/views/vendor/#{CONFIG['theme']}"
  ActionController::Base.prepend_view_path(RAILS_ROOT + "/app/views/vendor/#{CONFIG['theme']}")
  Rails.logger.info "Using theme static path: #{RAILS_ROOT}/public/vendor/#{CONFIG['theme']}"
  ActionController::Base.asset_host = Proc.new do |source, request|
    local_path = "#{RAILS_ROOT}/public/vendor/#{CONFIG['theme']}#{source}".split("?")
    asset_host = CONFIG['asset_host'] || "#{request.protocol}#{request.host_with_port}"
    if File.exists?(local_path[0])
      Rails.logger.debug "using themed file: #{asset_host}/vendor/#{CONFIG['theme']}/#{source}"
      "#{asset_host}/vendor/#{CONFIG['theme']}"
    else
      "#{asset_host}"
    end
  end
end

