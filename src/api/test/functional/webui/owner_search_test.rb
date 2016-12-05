# -*- coding: utf-8 -*-

require_relative '../../test_helper'

class Webui::OwnerSearchTest < Webui::IntegrationTest
  uses_transaction :test_basic_owner_search
  uses_transaction :test_owner_search_with_devel

  def setup
    @attrib = Attrib.find_or_create_by!(attrib_type: AttribType.where(name: "OwnerRootProject").first,
                   project: Project.where(name: "home:Iggy").first)
    wait_for_scheduler_start
  end

  def visit_owner_search
    visit url_for(controller: '/webui/search', action: :owner, only_path: true)
  end

  def search(options)
    validate_search_page
    find("#advanced_link").click

    options[:flags]  ||= []
    options[:expect] ||= :success

    fill_in "search_input", with: options[:text]
    options[:flags].each do |f|
      find("input[id='#{f}']").set(true)
    end

    click_button "search_button"

    if options[:expect] == :no_results
      flash_message.must_equal "Your search did not return any results."
      flash_message_type.must_equal :info
      assert search_results.empty?
    end
  end

  def validate_search_page
    page.must_have_text "Search for people responsible"
    page.must_have_text "Advanced"
  end

  def search_results
    raw_results = page.all("div.search_result")
    raw_results.collect do |row|
      {
        project: (row.find("a.project").text rescue nil),
        package: (row.find("a.package").text rescue nil),
        owners:  (row.find("p").text rescue nil)
      }
    end
  end

  def test_empty_owner_search # spec/controllers/webui/search_controller_spec.rb
    visit_owner_search
    search text: "does_not_exist", expect: :no_results
  end

  def test_basic_owner_search # spec/controllers/webui/search_controller_spec.rb
    run_publisher
    visit_owner_search
    search text: "package", expect: "success"
    result = search_results.first
    assert result[:project] == "home:Iggy"
    assert result[:package] == "TestPack"
    assert result[:owners].include? "(fred) as maintainer"
    assert result[:owners].include? "(Iggy) as maintainer"
    assert result[:owners].include? "(Iggy) as bugowner"
    # test_group_b is maintainer, but has no active member
    assert_not result[:owners].include? "test_group_empty as maintainer"
  end

  def test_owner_search_with_devel # spec/controllers/webui/search_controller_spec.rb
    run_publisher
    use_js

    # set devel package (this one has another devel package in home:coolo:test)
    pkg = Package.find_by_project_and_name 'home:Iggy', 'TestPack'
    pkg.develpackage = Package.find_by_project_and_name 'kde4', 'kdelibs'
    pkg.save

    visit_owner_search

    # Search including devel projects
    search text: "package", flags: [:devel], expect: "success"
    result = search_results.first
    assert result[:project] == "home:coolo:test"

    # search again, but ignore devel package
    search text: "package", flags: [:nodevel], expect: "success"
    result = search_results.first
    assert result[:project] == "home:Iggy"
    assert result[:package] == "TestPack"

    # reset devel package setting again
    pkg.develpackage = nil
    pkg.save
  end
end
