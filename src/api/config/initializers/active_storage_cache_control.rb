Rails.application.reloader.to_prepare do
  ActiveStorage::DiskController.class_eval do
    before_action only: [:show] do
      response.set_header('Cache-Control', 'max-age=86400, public')
    end
  end
end
