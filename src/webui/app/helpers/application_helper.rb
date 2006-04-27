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

  def link_to_home_project
    link_to "Home Project", :controller => "project", :action => "show", 
      :project => "home:" + session[:login]
  end

  def link_to_project project
    link_to project, :controller => "project", :action => :show,
      :project => project
  end

  def link_to_package project, package
    link_to package, :controller => "package", :action => :show,
      :project => project, :package => package
  end

end
