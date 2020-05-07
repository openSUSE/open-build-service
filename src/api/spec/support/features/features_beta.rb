module FeaturesBeta
  def click_menu_link(menu_name, action_name)
    click_link(menu_name, visible: true)
    within('#navigation') do
      click_link(action_name)
    end
  end
end

RSpec.configure do |c|
  c.include FeaturesBeta, type: :feature
end
