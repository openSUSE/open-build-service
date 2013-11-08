require 'test_helper'

class Webui::ProjectEditTest < Webui::IntegrationTest

  uses_transaction :test_change_global_project_description
  uses_transaction :test_change_global_project_info
  uses_transaction :test_change_home_project_description
  uses_transaction :test_change_home_project_info
  uses_transaction :test_change_home_project_title
  uses_transaction :test_change_global_project_title

  # ============================================================================
  #  
  def project_title
    find(:id, 'project_title').text
  end


  # ============================================================================
  # Returns the description of the viewed project as is displayed.
  # Caller should keep in mind that multi-space / multi-line text
  # will probably get trimmed and stripped when displayed.
  #
  def project_description
    find(:id, 'description_text').text
  end

  # ============================================================================
  # Changes project's title and/or description.
  # Expects arguments grouped into a hash.
  #
  def change_project_info new_info
    assert !new_info[:title].blank? || !new_info[:description].blank?

    click_link 'Edit description'
    page.must_have_text 'Edit Project Information of '

    unless new_info[:title].nil?
      fill_in 'title', with: new_info[:title]
    end

    unless new_info[:description].nil?
      new_info[:description].squeeze!(' ')
      new_info[:description].gsub!(/ *\n +/ , "\n")
      new_info[:description].strip!
      fill_in 'description', with: new_info[:description]
    end

    click_button 'Save changes'

    unless new_info[:title].nil?
      project_title.must_equal new_info[:title]
    end
    unless new_info[:description].nil?
      project_description.must_equal new_info[:description]
    end

  end

  test 'change_home_project_title' do
    login_Iggy to: webui_engine.project_show_path(project: 'home:Iggy')

    change_project_info(
      :title => 'My Title hopefully got changed ' + Time.now.to_i.to_s)
  end

  test 'change_home_project_description' do
    login_Iggy to: webui_engine.project_show_path(project: 'home:Iggy')
    change_project_info(
      :description => 'New description. Not kidding.. Brand new! ' + Time.now.to_i.to_s)
  end

  
  test 'change_home_project_info' do
    login_Iggy to: webui_engine.project_show_path(project: 'home:Iggy')
    change_project_info(
      :title => 'My Title hopefully got changed ' + Time.now.to_i.to_s,
      :description => 'New description. Not kidding.. Brand new! ' + Time.now.to_i.to_s)
  end

  test 'change_global_project_title' do
    login_king to: webui_engine.project_show_path(project: 'LocalProject')

    change_project_info(
      :title => 'My Title hopefully got changed ' + Time.now.to_i.to_s)
  end

  
  test 'change_global_project_description' do
    login_king to: webui_engine.project_show_path(project: 'LocalProject')

    change_project_info(
      :description => 'New description. Not kidding.. Brand new! ' + Time.now.to_i.to_s)
  end

  
  test 'change_global_project_info' do
    login_king to: webui_engine.project_show_path(project: 'LocalProject')

    change_project_info(
      :title => 'My Title hopefully got changed ' + Time.now.to_i.to_s,
      :description => 'New description. Not kidding.. Brand new! ' + Time.now.to_i.to_s)
  end
  
end
