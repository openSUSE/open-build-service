# -*- coding: utf-8 -*-
require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"        

class PackageBranchTest < ActionDispatch::IntegrationTest

  def create_package_branch new_branch
    click_link 'Branch existing package'

    assert page.has_text? "Add New Package Branch to #{@project}"
    assert page.has_text? "Name of original project:"
    assert page.has_text? "Name of package in original project:"
    assert page.current_url =~ %r{/project/new_package_branch}

    new_branch[:expect]           ||= :success
    new_branch[:name]             ||= ""
    new_branch[:original_name]    ||= ""
    new_branch[:original_project] ||= ""

    fill_in "linked_project", with: new_branch[:original_project]
    fill_in "linked_package", with: new_branch[:original_name]
    fill_in "target_package", with: new_branch[:name]

    click_button "Create Branch"

    if new_branch[:expect] == :success
      assert_equal "Branched package #{@project} / #{new_branch[:name]}", flash_message
      assert_equal :info, flash_message_type
      assert page.current_url.end_with? package_show_path(project: @project, package: new_branch[:name])
    elsif new_branch[:expect] == :invalid_package_name
      assert_equal "Invalid package name: '#{new_branch[:original_name]}'", flash_message
      assert_equal :alert, flash_message_type
    elsif new_branch[:expect] == :invalid_project_name
      assert_equal "Invalid project name: '#{new_branch[:original_project]}'", flash_message
      assert_equal :alert, flash_message_type
    elsif new_branch[:expect] == :already_exists
      assert_equal "Package '#{new_branch[:name]}' already exists in project '#{@project}'", flash_message
      assert_equal :alert, flash_message_type
    else
      throw "Invalid value for argument <expect>."
    end
  end

  def setup
    @project = "home:Iggy"
    super
  end

  test "branch_package_for_home_project" do

    login_Iggy
    visit project_show_path(:project => @project)

    create_package_branch(
      :name => "TestPack_link",
      :original_name => "TestPack",
      :original_project => "home:Iggy")
  end
    
  test "branch_package_for_global_project" do

    login_Iggy
    visit project_show_path(:project => @project)

    create_package_branch(
      :name => "PublicPackage1",
      :original_name => "kdelibs",
      :original_project => "kde4")
  end
    
  
  test "branch_package_twice_duplicate_name" do

    login_Iggy
    visit project_show_path(:project => @project)

    create_package_branch(
      :expect => :already_exists,
      :name => "TestPack",
      :original_name => "TestPack",
      :original_project => "home:Iggy")
  end
  
    
  test "branch_package_twice" do

    login_Iggy
    visit project_show_path(:project => @project)

    create_package_branch(
      :name => "TestPack2",
      :original_name => "kdelibs",
      :original_project => "kde4")
    visit project_show_path(:project => @project)
    create_package_branch(
      :name => "TestPack3",
      :original_name => "kdelibs",
      :original_project => "kde4")
  end


  test "branch_empty_package_name" do

    login_Iggy
    visit project_show_path(:project => @project)

    create_package_branch(
      :name => "",
      :original_name => "",
      :original_project => "home:Iggy",
      :expect => :invalid_package_name)
  end
  
  test "branch_empty_project_name" do

    login_Iggy
    visit project_show_path(:project => @project)

    create_package_branch(
      :name => "TestPack",
      :original_name => "TestPack",
      :original_project => "",
      :expect => :invalid_project_name)
  end

  test "branch_package_name_with_spaces" do

    login_Iggy
    visit project_show_path(:project => @project)

    create_package_branch(
      :name => "BranchedPackage",
      :original_name => "invalid package name",
      :original_project => "home:Iggy",
      :expect => :invalid_package_name)
  end


  test "branch_project_name_with_spaces" do
  
    login_Iggy
    visit project_show_path(:project => @project)

    create_package_branch(
      :name => "BranchedPackage",
      :original_name => "SomePackage",
      :original_project => "invalid project name",
      :expect => :invalid_project_name)
  end
  
  
end
