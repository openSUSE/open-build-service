class MailHandlerController < ApplicationController
  skip_before_filter :extract_user
  skip_before_action :require_login

  respond_to :xml, :json

  def upload
    # UNIMPLEMENTED STUB JUST FOR TESTING
    render_ok
  end

end
