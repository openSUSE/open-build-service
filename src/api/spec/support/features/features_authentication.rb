module FeaturesAuthentication
  def login(user)
    page.set_rack_session(login: user.login)
  end

  def logout
    page.set_rack_session(login: nil)
  end
end

RSpec.configure do |c|
  c.include FeaturesAuthentication, type: :feature
end
