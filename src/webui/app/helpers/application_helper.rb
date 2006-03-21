# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  
  def logged_in?
     !session[:login].nil?
  end
  
  def user
    u = nil
    if logged_in?
      u = Person.find :login => session[:login]
    end
    return u
  end
end
