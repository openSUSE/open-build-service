# -*- coding: utf-8 -*-
require_relative '../../test_helper'

class Webui::PackageEditSourcesTest < Webui::IntegrationTest
  include ActionView::Helpers::JavaScriptHelper
  include URI

  def setup
    @package = 'TestPack'
    @project = 'home:Iggy'
    @package_object = Package.get_by_project_and_name(@project, @package)

    use_js
    login_Iggy to: package_show_path(project: @project, package: @package)
  end

  def text_path(name)
    File.expand_path( Rails.root.join("test/texts/#{name}") )
  end

  def open_add_file
    click_link('Add file')
    page.must_have_text 'Add File to'
  end

  def add_file(file)
    file[:expect]      ||= :success
    file[:name]        ||= ''
    file[:upload_from] ||= :local_file
    file[:upload_path] ||= ''

    assert [:local_file, :remote_url].include? file[:upload_from]

    # get file's name from upload path in case it wasn't specified caller
    file[:name] = File.basename(file[:upload_path]) if file[:name] == ''

    fill_in 'filename', with: file[:name]

    if file[:upload_from] == :local_file
      find(:id, 'file_type').select('local file')
      begin
        page.attach_file('file', file[:upload_path]) unless file[:upload_path].blank?
      rescue Capybara::FileNotFound
        return unless file[:expect] != :error

        raise "file was not found, but expect was #{file[:expect]}"
      end
    else
      find(:id, 'file_type').select('remote URL')
      fill_in('file_url', with: file[:upload_path]) if file[:upload_path]
    end
    click_button('Save changes')

    if file[:expect] == :success
      flash_message.must_equal "The file '#{file[:name]}' has been successfully saved."
      flash_message_type.must_equal :info
      click_link(file[:name])
      page.must_have_text "File #{file[:name]} of Package #{@package}"

      # Check if uploaded file and stored are the same
      expected = file[:upload_path].present? ? File.open(file[:upload_path]).read : ''

      # Request the file from the backend to compare it with the uploaded one
      actual = @package_object.source_file(file[:name])

      # HTML encoding is necessary because backend returns it already encoded
      # but without the whitespaces, therefore we encode again to be sure
      expected = URI.encode(expected)
      actual = URI.encode(actual)

      assert_equal expected.inspect, actual.inspect
    elsif file[:expect] == :error
      flash_message_type.must_equal :alert
      flash_message.must_equal file[:flash_message]
      page.must_have_text 'Add File to'
    elsif file[:expect] == :service
      flash_message.must_equal "The file '#{file[:name]}' has been successfully saved."
      flash_message_type.must_equal :info
      assert find(:css, "#files_table tr#file-#{valid_xml_id('_service')}"), 'expected to find the _service file in the files table'
    else
      raise 'Invalid value for argument expect.'
    end
  end

  def test_erase_file_content # spec/features/webui/packages_spec.rb
    find(:css, "tr##{valid_xml_id('file-myfile')} td:first-child a").click
    page.must_have_text "File myfile of Package #{@package}"
    # is it all rendered?
    page.must_have_selector('.CodeMirror-lines')

    # codemirror is not really test friendly, so just brute force it - we basically
    # want to test the load and save work flow not the codemirror library
    page.execute_script("editors[0].setValue('');")
    assert !find(:css, '.buttons.save')['class'].split(' ').include?('inactive')
    find(:css, '.buttons.save').click
    page.must_have_selector('.buttons.save.inactive')

    flash_message.must_equal "The file 'myfile' has been successfully saved."
    flash_message_type.must_equal :info

    # Check if the saved content matches the uploaded content
    assert_equal "", @package_object.source_file("myfile")
  end

  def test_edit_empty_file # spec/features/webui/packages_spec.rb
    find(:css, "tr##{valid_xml_id('file-myfile')} td:first-child a").click
    page.must_have_text "File myfile of Package #{@package}"
    # is it all rendered?
    page.must_have_selector('.CodeMirror-lines')

    edit_text = File.read(text_path('SourceFile.cc'))

    # codemirror is not really test friendly, so just brute force it - we basically
    # want to test the load and save work flow not the codemirror library
    page.execute_script("editors[0].setValue('#{escape_javascript(edit_text)}');")
    assert !find(:css, '.buttons.save')['class'].split(' ').include?('inactive')
    find(:css, '.buttons.save').click
    page.must_have_selector('.buttons.save.inactive')

    flash_message.must_equal "The file 'myfile' has been successfully saved."
    flash_message_type.must_equal :info

    # Check if the saved content matches the uploaded content
    content = @package_object.source_file('myfile')
    assert_equal edit_text.inspect, content.inspect
  end

  def test_add_new_source_file_to_home_project_package # spec/features/webui/packages_spec.rb
    open_add_file
    # Touch an empty file
    add_file(name: 'HomeSourceFile1')
  end

  def test_chinese_chars # spec/features/webui/packages_spec.rb
    open_add_file
    fu = '学习总结' # you don't want to know what that means in chinese
    add_file(name: fu, upload_path: text_path('chinese.txt'))

    visit package_view_file_path(project: @project, package: @package, filename: fu)
    page.must_have_button 'Save'
  end

  def test_add_source_file_from_local_file # spec/features/webui/packages_spec.rb
    open_add_file
    add_file(upload_from: :local_file, upload_path: text_path('SourceFile.cc'))
  end

  def test_add_source_file_from_local_file_override_name # spec/features/webui/packages_spec.rb
    open_add_file
    add_file(
      name: 'HomeSourceFile3',
      upload_from: :local_file,
      upload_path: text_path('SourceFile.cc')
    )
  end

  def test_add_source_file_from_empty_local_file # spec/features/webui/packages_spec.rb
    open_add_file
    add_file(
      upload_from: :local_file,
      upload_path: text_path('EmptySource.c'))
  end

  def test_add_source_file_from_remote_file # spec/features/webui/packages_spec.rb
    open_add_file
    add_file(
      upload_from: :remote_url,
      upload_path: 'https://raw.github.com/openSUSE/open-build-service/master/.gitignore',
      expect: :service)
  end

  def test_add_source_file_with_invalid_name # spec/controllers/webui/package_controller_spec.rb
    open_add_file
    add_file(
      name: "\/\/ invalid name",
      upload_from: :local_file,
      expect: :error,
      flash_message: "Error while creating '\/\/ invalid name' file: '\/\/ invalid name' is not a valid filename."
    )
  end

  def test_add_source_file_all_fields_empty # spec/controllers/webui/package_controller_spec.rb
    open_add_file

    # The button is disabled when all fields are empty.
    # However, we want to test that the controller returns an error message
    # if the user enables the button.
    page.execute_script("$('#submit_button').attr('disabled', false);")
    add_file(
      name: '',
      upload_path: '',
      expect: :error,
      flash_message: "Error while creating '' file: No file or URI given."
    )
  end

  def test_add_empty_special_file # spec/features/webui/packages_spec.rb
    open_add_file
    add_file(
      name: '_link',
      upload_from: :local_file,
      upload_path: text_path('EmptySource.c'),
      expect: :error,
      flash_message: "Error while creating '_link' file: Document is empty, not allowed for link."
    )
  end

  def test_add_invalid_special_file # spec/features/webui/packages_spec.rb
    open_add_file
    add_file(
      name: '_link',
      upload_from: :local_file,
      upload_path: text_path('broken_link.xml'),
      expect: :error,
      flash_message: "Error while creating '_link' file: link validation error: Extra content at the end of the document."
    )
  end

  def test_add_valid_special_file # spec/features/webui/packages_spec.rb
    open_add_file
    add_file(
      name: '_aggregate',
      upload_from: :local_file,
      upload_path: text_path('aggregate.xml'),
      expect: :success
    )
  end
end
