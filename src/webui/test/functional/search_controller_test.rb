# -*- coding: utf-8 -*-
#
require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"        

class SearchControllerTest < ActionDispatch::IntegrationTest

  def validate_search_page
    assert page.find(:id, 'header-logo')
    assert page.has_text? "Search for Buildservice Projects or Packages"
    assert page.has_text? "Search term:"
    assert page.has_text? "Require attribute:"
  end

  def search options
    validate_search_page

    options[:for]    ||= [:projects, :packages]
    options[:in]     ||= [:name]
    options[:expect] ||= :success

    project     = page.find(:id, 'project')
    package     = page.find(:id, 'package')
    name        = page.find(:id, 'name')
    title       = page.find(:id, 'title')
    description = page.find(:id, 'description')

    fill_in "Search term:", with: options[:text]

    project.click     if options[:for].include?(:projects) != project.selected?
    package.click     if options[:for].include?(:packages) != package.selected?
    name.click        if options[:in].include?(:name)      != name.selected?
    title.click       if options[:in].include?(:title)     != title.selected?
    description.click if options[:in].include?(:description) != description.selected?
    if options[:attribute]
      select(options[:attribute], from: "Require attribute:")
    end
    find("#search-term").click

    if options[:expect] == :success
      if !options[:text].blank?
        search_details = "for \"#{options[:text]}\""
        if options[:attribute]
          search_details += " with \"#{options[:attribute]}\""
        end
      else
        search_details = "with attribute \"#{options[:attribute]}\""
      end
      found_text = find("div#content h3").text
      assert_match found_text, %r{^Search Results #{search_details}\s+\(\d+\)$}, 
      "'#{found_text}' did not match /^Search Results #{search_details}\s+\(\d+\)$/"
    elsif options[:expect] == :invalid_search_text
      assert_equal "Search String must contain at least 2 characters OR you search for an attribute.", flash_message
      assert_equal :alert, flash_message_type
      validate_search_page
    elsif options[:expect] == :invalid_search_options
      #TODO: IMP
    end
  end

  def search_results
    raw_results = page.all("table#search_result tr")
    raw_results.collect do |row|
      theclass = row.first("img")["class"]
      case theclass
      when "project"
        { :type         => :project, 
          :project_name => row.find("a.project-link").text }
      when "package"
        { :type         => :package, 
          :package_name => row.find("a.package-link").text,
          :project_name => row.find("a.project-link").text }
      else
        fail "Unrecognized result icon. #{alt}"
      end
    end
  end
  
  test "find search link in footer" do
    visit "/"
    find(:css, "div#footer a.search-link").click
    validate_search_page
  end
  
  test "basic search functionality" do
    visit '/search/search'
    validate_search_page

    visit '/search/search?search_text=Base'
    assert page.has_text?(/Base.* distro without update project/)
  end

  test "search by baseurl" do
    visit '/search/search?search_text=obs://build.opensuse.org/openSUSE:Factory/standard/fd6e76cd402226c76e65438a5e3df693-bash'
    assert find('#flash-messages').has_text? "Project not found: openSUSE:Factory"

    visit '/search/search?search_text=obs://foo'
    assert find('#flash-messages').has_text?(%{obs:// searches are not random})
  end

  test "search for home projects" do
  
    visit search_path

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


  test "search for subprojects" do

    visit search_path

    search(
      :text => "branches", 
      :for  => [:projects], 
      :in   => [:name])

    results = search_results
    assert results.include? :type => :project, :project_name => "home:Iggy:branches:kde4"
    assert results.count == 1
  end


  test "search_for_public_projects" do

    visit search_path

    search(
      :text => "Local", 
      :for  => [:projects], 
      :in   => [:name])

    assert search_results.include? :type => :project, :project_name => "LocalProject"
    assert search_results.count == 1
  end


  test "search_for_packages" do

    visit search_path

    search(
      :text => "Test",
      :for  => [:packages], 
      :in   => [:name])
    
    results = search_results
    assert results.include? :type => :package, :project_name => "CopyTest",  :package_name => "test"
    assert results.include? :type => :package, :project_name => "home:Iggy", :package_name => "ToBeDeletedTestPack"
    assert results.include? :type => :package, :package_name => "TestPack",  :project_name => "home:Iggy"
    assert_equal 3, results.count
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


  test "search non existing by name" do

    visit search_path
  
    search(
      :text => "no such name, please!", 
      :for  => [:projects, :packages], 
      :in   => [:name])

    assert search_results.empty?
  end


  test "search non existing by title" do

    visit search_path

    search(
      :text => "Perhaps a non-existing title.", 
      :for  => [:projects, :packages], 
      :in   => [:title])

    assert search_results.empty?
  end


  test "search_non_existing_by_description" do

    visit search_path  

    search(
      :text => "Some non-existing description I hope.", 
      :for  => [:projects, :packages], 
      :in   => [:description])

    assert search_results.empty?
  end


  test "search non existing by attributes" do
    visit search_path

    search(
      :text => "", 
      :for  => [:projects, :packages], 
      :in   => [],
      :attribute => "OBS:RequestCloned")

    assert search_results.empty?
  end

  test "search_for_nothing" do
    visit search_path

    search(
      :text => "Some empty search.", 
      :for  => [], 
      :in   => [:name, :title, :description])

    assert search_results.empty?
  end
  
  test "search russian" do
    visit search_path
    
    search(text: "вокябюч", :for  => [:projects, :packages], :in   => [:name, :title, :description])
    
    results = search_results
    assert page.has_text? "Этёам вокябюч еюж эи"
    assert page.has_text? "窞綆腤 埱娵徖 渮湸湤 殠 唲堔"
    results.include?(:type => :project, :project_name => "home:tom")
    assert_equal 1, results.count
  end

  test "search_in_nothing" do
    visit search_path  

    search(
      :text => "Some empty search again.", 
      :for  => [:projects, :packages], 
      :in   => [],
      :expect => :invalid_search_options)
  end
  
  
  test "search_with_empty_text" do
    visit search_path
    search(
      :text => "", 
      :for  => [:projects, :packages], 
      :in   => [:name],
      :expect => :invalid_search_text)
  end
  
end
