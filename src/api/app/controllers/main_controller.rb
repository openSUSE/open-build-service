class MainController < ApplicationController

  def index
  end

  def notfound
    render_error :message => "Page not found", :status => 404, :errorcode => "not_found"
    return
  end

end
