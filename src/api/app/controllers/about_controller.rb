class AboutController < ApplicationController

  def index
    # ACL(index): nothing to change
    @api_revision = "#{CONFIG['version']}"
  end
  
end
