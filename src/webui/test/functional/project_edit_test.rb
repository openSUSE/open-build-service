require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"        

class ProjectEditTest < ActionDispatch::IntegrationTest

  
  # ============================================================================
  #  
  def project_title
    find(:id, "project_title").text
  end


  # ============================================================================
  # Returns the description of the viewed project as is displayed.
  # Caller should keep in mind that multi-space / multi-line text
  # will probably get trimmed and stripped when displayed.
  #
  def project_description
    find(:id, "description_text").text
  end

  # ============================================================================
  # Changes project's title and/or description.
  # Expects arguments grouped into a hash.
  #
  def change_project_info new_info
    assert !new_info[:title].blank? || !new_info[:description].blank?

    click_link 'Edit description'
    assert page.has_text? "Edit Project Information of "

    unless new_info[:title].nil?
      fill_in "title", with: new_info[:title]
    end

    unless new_info[:description].nil?
      new_info[:description].squeeze!(" ")
      new_info[:description].gsub!(/ *\n +/ , "\n")
      new_info[:description].strip!
      fill_in "description", with: new_info[:description]
    end

    click_button "Save changes"

    unless new_info[:title].nil?
      assert_equal new_info[:title], project_title
    end
    unless new_info[:description].nil?
      assert_equal new_info[:description], project_description
    end

  end

  test "change_home_project_title" do
    login_Iggy
    visit project_show_path(project: "home:Iggy")

    change_project_info(
      :title => "My Title hopefully got changed " + Time.now.to_i.to_s)
  end

  test "change_home_project_description" do
    login_Iggy
    visit project_show_path(project: "home:Iggy")
    change_project_info(
      :description => "New description. Not kidding.. Brand new! " + Time.now.to_i.to_s)
  end

  
  test "change_home_project_info" do
    login_Iggy
    visit project_show_path(project: "home:Iggy")
    change_project_info(
      :title => "My Title hopefully got changed " + Time.now.to_i.to_s,
      :description => "New description. Not kidding.. Brand new! " + Time.now.to_i.to_s)
  end

  test "change_global_project_title" do
    login_king
    visit project_show_path(project: "LocalProject")

    change_project_info(
      :title => "My Title hopefully got changed " + Time.now.to_i.to_s)
  end

  
  test "change_global_project_description" do
    login_king
    visit project_show_path(project: "LocalProject")

    change_project_info(
      :description => "New description. Not kidding.. Brand new! " + Time.now.to_i.to_s)
  end

  
  test "change_global_project_info" do
    login_king
    visit project_show_path(project: "LocalProject")

    change_project_info(
      :title => "My Title hopefully got changed " + Time.now.to_i.to_s,
      :description => "New description. Not kidding.. Brand new! " + Time.now.to_i.to_s)
  end
  
end
