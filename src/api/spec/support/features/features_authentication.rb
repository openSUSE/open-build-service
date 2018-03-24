module FeaturesAuthentication
  def login(user, password = 'buildservice')
    visit session_new_path
    expect(page).to have_text 'Please Log In'
    fill_in 'user-login', with: user.login
    fill_in 'user-password', with: password
    click_button 'Log In »'
    expect(page).to have_link 'link-to-user-home'
    User.current = user
  end

  def logout
    visit session_destroy_path
    expect(page).to have_no_link('link-to-user-home')
    User.current = nil
  end
end

RSpec.configure do |c|
  c.include FeaturesAuthentication, type: :feature
end
