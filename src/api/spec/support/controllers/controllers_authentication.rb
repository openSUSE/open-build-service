module ControllersAuthentication
  def login(user)
    request.session[:login] = user.login
    User.current = user
  end

  def logout
    request.session[:login] = nil
  end
end

RSpec.configure do |c|
  c.include ControllersAuthentication, type: :controller
end
