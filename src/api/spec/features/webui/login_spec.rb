require "browser_helper"

RSpec.feature "Login", type: :feature, js: true do
  let!(:user) { create(:confirmed_user, login: "proxy_user") }

  context "In proxy mode" do
    before do
      @before = CONFIG["proxy_auth_mode"]
      # Fake proxy mode
      CONFIG["proxy_auth_mode"] = :on
    end

    after do
      CONFIG["proxy_auth_mode"] = @before
    end

    scenario "should log in a user when the header is set" do
      page.driver.add_header("X_USERNAME", "proxy_user")

      visit search_path
      expect(page).to have_css("#link-to-user-home", text: "proxy_user")
    end

    scenario "should not log in any user when no header is set" do
      visit search_path
      expect(page).to have_content("Log In")
    end

    scenario "should create a new user account if user does not exist in OBS" do
      page.driver.add_header('X_USERNAME', 'new_user')
      page.driver.add_header('X_EMAIL', 'new_user@obs.com')
      page.driver.add_header('X_FIRSTNAME', 'Bob')
      page.driver.add_header('X_LASTNAME', 'Geldof')

      visit search_path

      expect(page).to have_css("#link-to-user-home", text: "new_user")
      user = User.where(login: "new_user", realname: "Bob Geldof", email: "new_user@obs.com")
      expect(user).to exist
    end
  end

  scenario "login with home project shows a link to it" do
    login user
    expect(page).to have_content "#{user.login} | Home Project | Logout"
  end

  scenario "login without home project shows a link to create it" do
    user.home_project.destroy
    login user
    expect(page).to have_content "#{user.login} | Create Home | Logout"
  end

  scenario "login via login page" do
    visit user_login_path
    fill_in "Username", with: user.login
    fill_in "Password", with: "buildservice"
    click_button("Log In")

    expect(find('#link-to-user-home').text).to eq user.login
  end

  scenario "login via widget" do
    visit root_path
    click_link("Log In")

    within("div#login-form") do
      fill_in "Username", with: user.login
      fill_in "Password", with: "buildservice"
      click_button("Log In")
    end

    expect(find("#link-to-user-home").text).to eq user.login
  end

  scenario "login with wrong data" do
    visit root_path
    click_link("Log In")

    within("#login-form") do
      fill_in "Username", with: user.login
      fill_in "Password", with: "foo"
      click_button "Log In"
    end

    expect(page).to have_content("Authentication failed")
  end

  scenario "logout" do
    login(user)

    within("div#subheader") do
      click_link("Logout")
    end

    expect(page).not_to have_css("a#link-to-user-home")
    expect(page).to have_link("Log")
  end
end
