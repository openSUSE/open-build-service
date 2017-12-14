class AboutController < ApplicationController
  validate_action index: { method: :get, response: :about }
  skip_before_action :extract_user
  skip_before_action :require_login
  before_action :set_response_format_to_xml

  def index
    @api_revision = CONFIG['version'].to_s
  end
end
