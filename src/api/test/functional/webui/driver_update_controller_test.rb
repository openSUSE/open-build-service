require_relative '../../test_helper'

class Webui::DriverUpdateControllerTest < Webui::IntegrationTest

  include Webui::WebuiHelper

  setup do
    login_Iggy
  end

  teardown do

  end

  # TODO: End this test cases if they should. We saw that the DriverUpdateController is unused.
  def test_create
    visit driver_update_create_path(package: 'TestPack', project: 'home:Iggy')
    page.must_have_text 'Driver update disk wizard'
    fill_in 'name', with: 'Test Driver Update Image'
    check 'arch[x86_64]'
  end

  # TODO: End this test cases if they should. We saw that the DriverUpdateController is unused.
  def test_edit

  end

  # TODO: End this test cases if they should. We saw that the DriverUpdateController is unused.
  def test_save

  end

  # TODO: End this test cases if they should. We saw that the DriverUpdateController is unused.
  def test_binaries

  end
end
