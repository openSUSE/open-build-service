# -*- coding: utf-8 -*-
require_relative '../../test_helper'

class Webui::PackageEditTest < Webui::IntegrationTest
  uses_transaction :test_change_home_project_package_description
  uses_transaction :test_change_home_project_package_info
  uses_transaction :test_change_home_project_package_title

  def setup # src/api/spec/controllers/webui/package_controller_spec.rb
    @package = 'TestPack'
    @project = 'home:Iggy'
    super
  end

  # ============================================================================
  #
  def package_title # src/api/spec/controllers/webui/package_controller_spec.rb
    find(:id, 'package_title').text
  end

  # ============================================================================
  #
  def package_description # src/api/spec/controllers/webui/package_controller_spec.rb
    find(:id, 'description-text').text
  end

  # ============================================================================
  #
  def change_package_info new_info # src/api/spec/controllers/webui/package_controller_spec.rb
    assert !new_info[:title].blank? || !new_info[:description].blank?

    click_link('Edit description')

    page.must_have_text "Edit Package Information of #{@package} (Project #{@project})"
    page.must_have_text 'Title:'
    page.must_have_text 'Description:'

    fill_in 'title', with: new_info[:title] unless new_info[:title].nil?

    unless new_info[:description].nil?
      new_info[:description].squeeze!(' ')
      new_info[:description].gsub!(/ *\n +/, "\n")
      new_info[:description].strip!
      fill_in 'description', with: new_info[:description]
    end

    click_button 'Save changes'

    page.must_have_text 'Source Files'
    page.must_have_text 'Build Results'

    assert_equal package_title, new_info[:title] unless new_info[:title].nil?
    unless new_info[:description].nil?
      assert_equal package_description, new_info[:description]
    end
  end

  def test_change_home_project_package_title # src/api/spec/controllers/webui/package_controller_spec.rb
    login_Iggy to: package_show_path(project: @project, package: @package)

    change_package_info(
      title: 'My Title hopefully got changed ' + Time.now.to_i.to_s)
  end

  def test_change_home_project_package_description # src/api/spec/controllers/webui/package_controller_spec.rb
    login_Iggy to: package_show_path(project: @project, package: @package)

    change_package_info(
      description: 'New description. Not kidding.. Brand new! ' + Time.now.to_i.to_s)
  end

  def test_change_home_project_package_info # src/api/spec/controllers/webui/package_controller_spec.rb
    login_Iggy to: package_show_path(project: @project, package: @package)

    change_package_info(
      title: 'My Title hopefully got changed ' + Time.now.to_i.to_s,
      description: 'New description. Not kidding.. Brand new! ' + Time.now.to_i.to_s)
  end
end
