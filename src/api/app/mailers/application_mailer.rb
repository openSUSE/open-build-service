class ApplicationMailer < ActionMailer::Base
  before_action :set_host

  default Precedence: 'bulk',
          'X-OBS-URL': ActionDispatch::Http::URL.url_for(controller: :main, action: :index, only_path: false, host: @host),
          'Auto-Submitted': 'auto-generated'

  private

  def set_host
    # FIXME: This if for the view. Use action_mailer.default_url_options instead
    # https://guides.rubyonrails.org/action_mailer_basics.html#generating-urls-in-action-mailer-views
    @host = ::Configuration.obs_url
  end
end
