class PrivacyController < ApplicationController
  skip_before_filter :authorize, :set_return_to
  def ichain_login
    # if this method is exectuted, the code has gone through the iChain 
    # login and the user is authenticated.
    # Note that all the following code is not really neccessary but 
    # only for test purposes.  See application/extract_user for the real
    # user extraction and verification.
    if request.env.has_key? 'HTTP_X_USERNAME' # X-username'
      session[:return_to] ||= "/main/index2"
      user = request.env[ 'HTTP_X_USERNAME' ] # X-username']
      logger.debug "Have this iChain Username: #{user}"
      session[:return_to] = "/main/index2" if %w(/ /privacy/ichain_login).include? session[:return_to]
      redirect_to session[:return_to]
    else 
      logger.debug "No X-Username found!"
      request.env.each do |name, val|
        logger.debug "Header value: #{name} = #{val}"
      end

      flash[:error] = "iChain configuration error. Sorry."
      redirect_back_or_to :controller => 'main', :action => 'index'
    end
  end
end

