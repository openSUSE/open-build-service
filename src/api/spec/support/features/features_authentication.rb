module FeaturesAuthentication
  def login(user, password = 'buildservice')
    visit new_session_path
    expect(page).to have_text 'Please Log In'
    within('#loginform') do
      fill_in 'username', with: user.login
      fill_in 'password', with: password
      click_button 'Log In'
    end
    expect(page).to have_link 'link-to-user-home', visible: :all
    User.session = user
  end

  def logout
    visit session_path(method: :delete)
    expect(page).to have_no_link('link-to-user-home')
    User.session = nil
  end
end

RSpec.configure do |c|
  c.include FeaturesAuthentication, type: :feature
end
