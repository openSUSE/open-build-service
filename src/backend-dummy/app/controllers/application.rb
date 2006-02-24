# Filters added to this controller will be run for all controllers in the application.
# Likewise, all the methods added will be available for all controllers.
class ApplicationController < ActionController::Base

  def render_error( opt = {} )
    @errorcode = 500

    if opt[:status]
      @errorcode = opt[:status]
    end
    
    @summary = "Internal Server Error"
    if opt[:message]
      @summary = opt[:message]
    end
    
    if opt[:exception]
      @exception = opt[:exception ]
    end

    render :template => 'error', :status => @errorcode
  end


end