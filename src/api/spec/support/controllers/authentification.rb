def login(user)
  request.session[:login] = user.login
end

def logout
  request.session[:login] = nil
end
