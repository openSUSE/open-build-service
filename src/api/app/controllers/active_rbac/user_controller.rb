class ActiveRbac::UserController < ActiveRbac::ComponentController

  def list
    
    if params[:onlyunconfirmned]
      @user_pages, @users = paginate :user, :conditions => [ "state = 5"], :order_by => "login", :per_page => 25
    else
      @user_pages, @users = paginate :user, :order_by => "login", :per_page => 25
    end
  end 
  
end
