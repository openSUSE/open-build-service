class PrivacyController < ApplicationController
  skip_before_filter :authorize
  def ichain_login
    # if this method is exectuted, the code has gone through the iChain 
    # login and the user is authenticated.
    # Note that all the following code is not really neccessary but 
    # only for test purposes.  See application/extract_user for the real
    # user extraction and verification.
    if request.env.has_key? 'HTTP_X_USERNAME' # X-username'
      user = request.env[ 'HTTP_X_USERNAME' ] # X-username']
      logger.debug "Have this iChain Username: #{user}"
      if false & session[:return_to]
        redirect_to session[:return_to]
        session[:return_to] = nil
        return
      end
      redirect_to "/main/index2"
    else 
      logger.debug "No X-Username found!"
      request.env.each do |name, val|
        logger.debug "Header value: #{name} = #{val}"
      end

      render_error :code => 401, :message => "iChain configuration error. Sorry."
    end
  end
end

