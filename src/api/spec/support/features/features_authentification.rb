module FeaturesAuthentification
  def login(user, password = 'buildservice')
    visit user_login_path
    fill_in 'Username', with: user.login
    fill_in 'Password', with: password
    click_button 'Log In'
  end

  def logout
    visit user_logout_path
  end
end

RSpec.configure do |c|
  c.include FeaturesAuthentification, type: :feature
end
