class PrivacyController < ApplicationController

  def ichain_login
    # if this method is exectuted, the code has gone through the iChain 
    # login and the user is authenticated.
    # Note that all the following code is not really neccessary but 
    # only for test purposes.  See application/extract_user for the real
    # user extraction and verification.
    if request.env.has_key? 'X-username'
      user = request.env['X-username']
      logger.debug "Have this iChain Username: #{user}"
    else 
      logger.debug "No X-Username found!"
    end
    if params[:continue]
      redirect_to params[:continue]
    end
    redirect_to( "/" )
  end
end