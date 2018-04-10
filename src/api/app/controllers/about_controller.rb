# frozen_string_literal: true
class AboutController < ApplicationController
  validate_action index: { method: :get, response: :about }
  skip_before_action :extract_user
  skip_before_action :require_login
  before_action :set_response_format_to_xml

  def index
    @api_revision = CONFIG['version'].to_s
    @last_deployment = last_deployment
  end

  private

  def last_deployment
    File.new('last_deploy').atime
  rescue Errno::ENOENT
    ''
  end
end
