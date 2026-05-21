class AboutController < ApplicationController
  validate_action index: { method: :get, response: :about }
  # We always allow access to this action...
  skip_before_action :extract_user, :require_login, :check_anonymous_access
  before_action :set_response_format_to_xml

  def index
    @api_revision = CONFIG['version'].to_s
    @last_deployment = Git::LAST_DEPLOYMENT
    @commit = Git::COMMIT
  end
end
