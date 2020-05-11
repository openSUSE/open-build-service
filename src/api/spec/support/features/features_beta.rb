module FeaturesBeta
  def click_menu_link(menu_name, action_name)
    click_link(menu_name, visible: true)
    within('#navigation') do
      click_link(action_name)
    end
  end

  def skip_on_mobile
    skip('Run this test only for desktop') if Capybara.current_driver == :mobile
  end

  def desktop?
    Capybara.current_driver == :desktop
  end

  def mobile?
    Capybara.current_driver == :mobile
  end
end

RSpec.configure do |c|
  c.include FeaturesBeta, type: :feature
end
