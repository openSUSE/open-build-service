# -*- coding: utf-8 -*-

require 'test_helper'

class Webui::SearchControllerTest < Webui::IntegrationTest

  def setup
    OBSApi::TestSphinx.ensure
  end

  def validate_search_page
    page.must_have_selector '#header-logo'
    page.must_have_text "Search"
    page.must_have_text "Advanced"
  end

  def search options  
    validate_search_page
    # avoid the animation that happens when you press the button
    page.execute_script('$("#advanced_container").show()')
    #click_button("advanced_link") # yes, that's the id of the button :)

    options[:for]    ||= [:projects, :packages]
    options[:in]     ||= [:name]
    options[:expect] ||= :success

    fill_in "search_input", with: options[:text]

    page.find(:id, 'project').set(options[:for].include?(:projects))
    page.find(:id, 'package').set(options[:for].include?(:packages))
    page.find(:id, 'name').set(options[:in].include?(:name))
    page.find(:id, 'title').set(options[:in].include?(:title))
    page.find(:id, 'description').set(options[:in].include?(:description))

    if options[:attribute]
      select(options[:attribute], from: "attribute_list")
    end
    click_button "search_button"

    if options[:expect] == :success
      page.must_have_selector('.search_result')
    elsif options[:expect] == :invalid_search_text
      flash_message.must_equal "Search string must contain at least two characters."
      flash_message_type.must_equal :alert
      validate_search_page
    elsif options[:expect] == :invalid_search_options
      flash_message.must_equal "You have to search for #{options[:text]} in something. Click the advanced button..."
      flash_message_type.must_equal :alert
      assert search_results.empty?
      validate_search_page
    elsif options[:expect] == :no_results
      flash_message.must_equal "Your search did not return any results."
      flash_message_type.must_equal :info
      assert search_results.empty?
      validate_search_page
    end
  end

  def search_results
    raw_results = page.all("div.search_result")
    raw_results.collect do |row|
      theclass = row.first("img")["class"].split(' ')[0]
      case theclass
      when "icons-project"
      when "project"
        { :type         => :project,
          :project_name => row.find("a.project").text,
        }
      when "icons-package"
      when "package"
        { :type         => :package, 
          :project_name => row.find("a.project").text,
          :package_name => row.find("a.package").text,
        }
      else
        fail "Unrecognized result icon. #{theclass}"
      end
    end
  end

  test "find_search_link_in_footer" do
    visit webui_engine.root_path
    find(:css, "div#footer a.search-link").click
    validate_search_page
  end
  
  test "basic_search_functionality" do
    visit webui_engine.search_path
    validate_search_page

    visit webui_engine.root_path + '/search?search_text=basedistro'
    page.must_have_text(/Base.* contains official released updates/)

    visit webui_engine.root_path + '/search?search_text=basedistro3'
    page.must_have_text(/Base.* distro without update project/)

    visit webui_engine.root_path + '/search?search_text=kdebase'
    page.must_have_link 'kdebase'
  end
  
  test "header_search_functionality" do
    visit webui_engine.root_path
    fill_in 'search', with: 'kdebase'
    page.evaluate_script("$('#global-search-form').get(0).submit()")
    validate_search_page
    page.must_have_link 'kdebase'

    fill_in 'search', with: 'basedistro3'
    page.evaluate_script("$('#global-search-form').get(0).submit()")
    validate_search_page
    page.must_have_text(/Base.* distro without update project/)
  end

  test "search_by_baseurl" do
    visit webui_engine.root_path + '/search?search_text=obs://build.opensuse.org/openSUSE:Factory/standard/fd6e76cd402226c76e65438a5e3df693-bash'
    find('#flash-messages').must_have_text "Project not found: openSUSE:Factory"

    visit webui_engine.root_path + '/search?search_text=obs://foo'
    find('#flash-messages').must_have_text(%{This disturl does not compute!})
  end

  test "search_for_home_projects" do
  
    visit webui_engine.search_path

    search(
      :text => "Home",
      :for  => [:projects],
      :in   => [:title])

    results = search_results
    # tom set no description
    assert !results.include?(:type => :project, :project_name => "home:tom")
    assert results.include? :type => :project, :project_name => "home:Iggy"
    assert results.include? :type => :project, :project_name => "home:adrian"
    # important match as it's having "home" and not "Home"
    assert results.include? :type => :project, :project_name => "home:dmayr"
    assert results.include? :type => :project, :project_name => "home:Iggy:branches:kde4"
    # the api fixtures add home dirs too
    assert results.count >= 4
  end


  test "search_for_subprojects" do

    visit webui_engine.search_path

    search(
      :text => "branches", 
      :for  => [:projects], 
      :in   => [:name])

    results = search_results
    assert results.include? :type => :project, :project_name => "home:Iggy:branches:kde4"
    results.count.must_equal 1
  end


  test "search_for_projects" do

    visit webui_engine.search_path

    search(
      :text => "localproject",
      :for  => [:projects], 
      :in   => [:name])

    results = search_results
    assert results.include? :type => :project, :project_name => "LocalProject"
    results.count.must_equal 1
  end


  test "search_for_packages" do

    visit webui_engine.search_path

    search(
      :text => "Test",
      :for  => [:packages], 
      :in   => [:name])
    
    results = search_results
    assert results.include? :type => :package, :project_name => "CopyTest", :package_name => "test"
    #assert results.include? :type => :package, :project_name => "home:Iggy", :package_name => "TestPack"
    #assert results.include? :type => :package, :project_name => "home:Iggy", :package_name => "ToBeDeletedTestPack"
    results.count.must_equal 1
  end
  

  test "search_by_title" do
    #TODO
  end


  test "search by description" do
    #TODO
  end


  test "search by attributes" do
    #TODO
  end


  test "search_non_existing_by_name" do

    visit webui_engine.search_path
  
    search(
      :text => "no such name, please!", 
      :for  => [:projects, :packages], 
      :in   => [:name],
      :expect => :no_results)
  end


  test "search_non_existing_by_title" do

    visit webui_engine.search_path

    search(
      :text => "Perhaps a non-existing title.", 
      :for  => [:projects, :packages], 
      :in   => [:title],
      :expect => :no_results)
  end


  test "search_non_existing_by_description" do

    visit webui_engine.search_path

    search(
      :text => "Some non-existing description I hope.", 
      :for  => [:projects, :packages], 
      :in   => [:description],
      :expect => :no_results)
  end


  test "search_non_existing_by_attributes" do
    visit webui_engine.search_path

    search(
      :text => "", 
      :for  => [:projects, :packages], 
      :in   => [],
      :attribute => "OBS:RequestCloned",
      :expect => :no_results)
  end

  test "search_for_nothing" do
    visit webui_engine.search_path

    search(
      :text => "Some empty search.", 
      :for  => [:projects, :packages], 
      :in   => [:name, :title, :description],
      :expect => :no_results)
  end
  
  test "search_russian" do
    visit webui_engine.search_path
    
    search(
      :text => "вокябюч",
      :for  => [:projects, :packages],
      :in   => [:name, :title, :description])
    
    results = search_results
    page.must_have_text "窞綆腤 埱娵徖 渮湸湤 殠 唲堔"
    results.include?(:type => :project, :project_name => "home:tom")
    results.count.must_equal 1
  end

  test "search_in_nothing" do
    visit webui_engine.search_path

    search(
      :text => "Some empty search again.", 
      :for  => [:projects, :packages], 
      :in   => [],
      :expect => :invalid_search_options)
  end
  
  
  test "search_with_empty_text" do
    visit webui_engine.search_path
    search(
      :text => "", 
      :for  => [:projects, :packages], 
      :in   => [:name],
      :expect => :invalid_search_text)
  end

  test "search_hidden_as_anonymous" do

    visit webui_engine.search_path
  
    search(
      :text => "packcopy",
      :for  => [:projects, :packages],
      :in   => [:name, :title],
      :expect => :no_results)
  end

  test "search_hidden_as_adrian" do

    login_adrian
    visit webui_engine.search_path

    search(
      :text => "packcopy",
      :for  => [:projects, :packages],
      :in   => [:name, :title])

    results = search_results
    assert results.include? :type => :package, :package_name => "packCopy", :project_name=>"HiddenProject"
    results.count.must_equal 1
  end

end
