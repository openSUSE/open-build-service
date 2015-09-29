require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class BackendFileTest < ActiveSupport::TestCase
  fixtures :all

  CONFIG_FILE_STRING_FOR_HOME_IGGY_PROJECT = 'Type: spec
Substitute: kiwi package
Substitute: kiwi-packagemanager:instsource package
Ignore: package:bash'

  NEW_CONFIG_FILE_STRING_FOR_HOME_IGGY_PROJECT = 'Type: spec
Substitute: kiwi package
Substitute: kiwi-packagemanager:instsource package
Ignore: package:bash
Ignore: package:cups'

  setup do
    @valid_backend_file = ProjectConfigFile.new(project_name: 'home:Iggy') # Using ProjectConfigFile class because BackendFile class is abstract
    @not_valid_backend_file = ProjectConfigFile.new(project_name: 'home:Iggee') # Using ProjectConfigFile class because BackendFile class is abstract
  end

  def test_get_file_from_backend
    assert @valid_backend_file.file.is_a?(Tempfile)
    assert_not @not_valid_backend_file.file
  end

  def test_file_content_from_backend
    assert_equal @valid_backend_file.to_s, CONFIG_FILE_STRING_FOR_HOME_IGGY_PROJECT
  end

  def test_get_file_from_local_path
    path = ''
    Tempfile.open('test_backend_file', Dir.tmpdir, encoding: 'ascii-8bit') do |tempfile|
      tempfile.write(CONFIG_FILE_STRING_FOR_HOME_IGGY_PROJECT)
      path = tempfile.path
    end
    assert @valid_backend_file.file_from_path(path).is_a?(File)
    assert_equal @valid_backend_file.to_s, CONFIG_FILE_STRING_FOR_HOME_IGGY_PROJECT
  end

  def test_updating_backend_file_from_local_file
    assert_equal @valid_backend_file.to_s, CONFIG_FILE_STRING_FOR_HOME_IGGY_PROJECT
    path = ''
    Tempfile.open('test_backend_file', Dir.tmpdir, encoding: 'ascii-8bit') do |tempfile|
      tempfile.write(NEW_CONFIG_FILE_STRING_FOR_HOME_IGGY_PROJECT)
      path = tempfile.path
    end
    User.current = users(:Iggy)
    query_params = {user: User.current.login, comment: "Updated by test"}
    assert @valid_backend_file.file_from_path(path).is_a?(File)
    @valid_backend_file.save!(query_params)
    @valid_backend_file.reload # to be sure that the file comes from backend
    assert_equal @valid_backend_file.to_s, NEW_CONFIG_FILE_STRING_FOR_HOME_IGGY_PROJECT
    @valid_backend_file.save(query_params, CONFIG_FILE_STRING_FOR_HOME_IGGY_PROJECT) # Leave the file as before
  end

  def test_updating_backend_file_from_string
    assert_equal @valid_backend_file.to_s, CONFIG_FILE_STRING_FOR_HOME_IGGY_PROJECT
    User.current = users(:Iggy)
    query_params = {user: User.current.login, comment: "Updated by test"}
    @valid_backend_file.save(query_params, NEW_CONFIG_FILE_STRING_FOR_HOME_IGGY_PROJECT)
    @valid_backend_file.reload # to be sure that the file comes from backend
    assert_equal @valid_backend_file.to_s, NEW_CONFIG_FILE_STRING_FOR_HOME_IGGY_PROJECT
    @valid_backend_file.save(query_params, CONFIG_FILE_STRING_FOR_HOME_IGGY_PROJECT) # Leave the file as before
  end

  def test_destroy_backend_file
    assert_equal @valid_backend_file.to_s, CONFIG_FILE_STRING_FOR_HOME_IGGY_PROJECT
    User.current = users(:Iggy)
    query_params = {user: User.current.login, comment: "Updated by test"}
    assert @valid_backend_file.destroy(query_params)
    assert_raises(Exception) do
      @valid_backend_file.to_s # The model is destroyed and frozen, will raise an exception
    end
    @valid_backend_file = ProjectConfigFile.new(project_name: 'home:Iggy') # Recreate the model to save it
    @valid_backend_file.save(query_params, CONFIG_FILE_STRING_FOR_HOME_IGGY_PROJECT) # Leave the file as before
  end

end
