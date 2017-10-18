# -*- coding: utf-8 -*-
require_relative '../../test_helper'

class Webui::PackageCreateTest < Webui::IntegrationTest
  setup do
    @project = 'home:Iggy'
  end

  def open_new_package
    click_link('Create package')
    page.must_have_text 'Create New Package for '
  end

  def create_package(new_package)
    new_package[:expect]      ||= :success
    new_package[:name]        ||= ''
    new_package[:title]       ||= ''
    new_package[:description] ||= ''

    new_package[:description].squeeze!(' ')
    new_package[:description].gsub!(/ *\n +/, "\n")
    new_package[:description].strip!
    message_prefix = "Package '#{new_package[:name]}' "

    fill_in 'name', with: new_package[:name]
    fill_in 'title', with: new_package[:title]
    fill_in 'description', with: new_package[:description]

    click_button('Save changes')

    if new_package[:expect] == :success
      flash_message.must_equal message_prefix + 'was created successfully'
      flash_message_type.must_equal :info
      new_package[:description] = 'No description set' if new_package[:description].empty?
      assert_equal new_package[:description].gsub(%r{\s+}, ' '), find(:id, 'description-text').text
    elsif new_package[:expect] == :invalid_name
      flash_message.must_equal "Invalid package name: '#{new_package[:name]}'"
      flash_message_type.must_equal :alert
      page.must_have_text 'Create New Package for '
    elsif new_package[:expect] == :already_exists
      flash_message.must_equal message_prefix + "already exists in project '#{@project}'"
      flash_message_type.must_equal :alert
      page.must_have_text 'Create New Package for '
    else
      throw 'Invalid value for argument expect(must be :success, :invalid_name, :already_exists)'
    end
  end

  def test_create_home_project_package_for_user # spec/features/webui/projects_spec.rb
    use_js
    login_Iggy to: project_show_path(project: 'home:Iggy')
    open_new_package
    create_package(
      name: 'HomePackage1',
      title: 'Title for HomePackage1',
      description: 'Empty home project package created')

    # now check duplicated name
    visit project_show_path(project: 'home:Iggy')
    open_new_package
    create_package(
      name: 'HomePackage1',
      title: 'Title for HomePackage1',
      description: 'Empty home project package created',
      expect: :already_exists)

    # tear down
    delete_package('home:Iggy', 'HomePackage1')
  end

  def test_create_global_project_package # spec/features/webui/projects_spec.rb
    use_js
    login_king to: project_show_path(project: 'LocalProject')

    open_new_package
    create_package(
      name: 'PublicPackage1',
      title: 'Title for PublicPackage1',
      description: 'Empty public project package created')
    # tear down
    delete_package('LocalProject', 'PublicPackage1')
  end

  def test_create_package_without_name # spec/features/webui/projects_spec.rb
    login_Iggy to: project_show_path(project: 'home:Iggy')

    open_new_package
    create_package(
      name: '',
      title: 'Title for HomePackage1',
      description: 'Empty home project package without name. Must fail.',
      expect: :invalid_name)
  end

  def test_create_package_name_with_spaces # spec/features/webui/projects_spec.rb
    login_Iggy to: project_show_path(project: 'home:Iggy')

    open_new_package
    create_package(
      name: 'invalid package name',
      description: 'Empty home project package with invalid name. Must fail.',
      expect: :invalid_name)
  end

  def test_create_package_with_only_name # spec/features/webui/projects_spec.rb
    use_js
    login_Iggy to: project_show_path(project: 'home:Iggy')

    open_new_package
    create_package(
      name: 'HomePackage-OnlyName',
      description: '')
    # tear down
    delete_package('home:Iggy', 'HomePackage-OnlyName')
  end

  def test_create_package_strange_name # spec/features/webui/projects_spec.rb
    use_js
    login_Iggy to: project_show_path(project: 'home:Iggy')

    open_new_package
    create_package name: 'Testing包صفقةäölü', expect: :invalid_name

    create_package name: 'Cplus+'
    packageurl = page.current_url
    visit project_show_path( project: 'home:Iggy')

    baseuri = URI.parse(page.current_url)
    foundcplus = nil
    page.all('#raw_packages a').each do |link|
      next unless link.text == 'Cplus+'
      foundcplus = baseuri.merge(link['href']).to_s
      break
    end
    assert !foundcplus.nil?
    foundcplus.must_equal packageurl

    # tear down
    delete_package('home:Iggy', 'Cplus+')
  end
end
