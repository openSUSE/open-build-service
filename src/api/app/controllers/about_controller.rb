class AboutController < ApplicationController
  validate_action index: { method: :get, response: :about }
  # TODO: Devise: Explicitly don't require authenticated user
  before_action :set_response_format_to_xml

  def index
    @api_revision = CONFIG['version'].to_s
    @last_deployment = Git::LAST_DEPLOYMENT
    @commit = Git::COMMIT
  end
end
