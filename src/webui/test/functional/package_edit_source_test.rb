# -*- coding: utf-8 -*-
require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"        

class PackageEditSourcesTest < ActionDispatch::IntegrationTest
  include ApplicationHelper
  include ActionView::Helpers::JavaScriptHelper

  def setup
    @package = "TestPack"
    @project = "home:Iggy"
    super

    login_Iggy
    visit package_show_path(:project => @project, :package => @package)
  end

  def open_file file
    find(:css, "tr##{valid_xml_id('file-' + file)} td:first-child a").click
    assert page.has_text? "File #{file} of Package #{@package}"
  end

  def open_add_file
    click_link('Add file')
    assert page.has_text? "Add File to"
  end

  def add_file file
    file[:expect]      ||= :success
    file[:name]        ||= ""
    file[:upload_from] ||= :local_file
    file[:upload_path] ||= ""

    assert [:local_file, :remote_url].include? file[:upload_from]

    fill_in "filename", with: file[:name]

    if file[:upload_from] == :local_file then
      find(:id, "file_type").select("local file")
      begin
        page.attach_file("file", file[:upload_path]) unless file[:upload_path].blank?
      rescue Capybara::FileNotFound
        if file[:expect] != :invalid_upload_path
          raise "file was not found, but expect was #{file[:expect]}"
        else
          return
        end
      end
    else
      find(:id, "file_type").select("remote URL")
      fill_in("file_url", with: file[:upload_path]) if file[:upload_path]
    end
    click_button("Save changes")

    # get file's name from upload path in case it wasn't specified caller
    file[:name] = File.basename(file[:upload_path]) if file[:name] == ""

    if file[:expect] == :success
      assert_equal "The file #{file[:name]} has been added.", flash_message
      assert_equal :info, flash_message_type
      assert find(:css, "#files_table tr#file-#{valid_xml_id(file[:name])}")
      # TODO: Check that new file is in the list
    elsif file[:expect] == :no_path_given
      assert_equal :alert, flash_message_type
      assert_equal flash_message, "No file or URI given."
    elsif file[:expect] == :invalid_upload_path
      assert_equal :alert, flash_message_type
      assert page.has_text? "Add File to"
    elsif file[:expect] == :no_permission
      assert_equal :alert, flash_message_type
      assert page.has_text? "Add File to"
    elsif file[:expect] == :download_failed
      # the _service file is added, but the download fails
      fm = flash_messages
      assert_equal 2, fm.count
      assert_equal "The file #{file[:name]} has been added.", fm[0]
      assert fm[1].include?("service download_url failed"), "expected '#{fm[1]}' to include 'Download failed'"
    else
      raise "Invalid value for argument expect."
    end
  end

  # ============================================================================
  #
  def edit_file new_content
    # new edit page does not allow comments
 #   validate { @driver.page_source.include? "Comment your changes (optional):" }
    
    savebutton = find(:css, ".buttons.save")
    assert page.has_selector?(".buttons.save.inactive")
    
    # is it all rendered?
    assert page.has_selector?(".CodeMirror-lines")

    # codemirror is not really test friendly, so just brute force it - we basically
    # want to test the load and save work flow not the codemirror library
    page.execute_script("editors[0].setValue('#{escape_javascript(new_content)}');")
    
    # wait for it to be active
    assert !page.has_selector?(".buttons.save.inactive")
    assert !savebutton["class"].split(" ").include?("inactive")
    savebutton.click
    assert page.has_selector?(".buttons.save.inactive")
    assert savebutton["class"].split(" ").include? "inactive"

    #assert_equal "Successfully saved file #{@file}", flash_message
    #assert_equal :info, flash_message_type

  end
  
  test "erase_file_content" do
    open_file "myfile"
    edit_file ""
  end
  
  test "edit_empty_file" do
    open_file "TestPack.spec"
    edit_file NORMAL_SOURCE
  end

  
  test "add_new_source_file_to_home_project_package" do
    
    open_add_file
    add_file :name => "HomeSourceFile1"
  end


  test "add_source_file_from_local_file" do
    
    source_file = File.new "HomeSourceFile2.cc", "w"
    source_file.write NORMAL_SOURCE
    source_file.close
    
    open_add_file
    add_file(
      :upload_from => :local_file,
      :upload_path => File.expand_path(source_file.path) )
  end
  
    
  test "add_source_file_from_local_file_override_name" do
    
    source_file = File.new "MySourceFile.cc", "w"
    source_file.write NORMAL_SOURCE
    source_file.close
    
    open_add_file
    add_file(
      :name => "HomeSourceFile3",
      :upload_from => :local_file,
      :upload_path => File.expand_path(source_file.path) )
  end
  
  
  test "add_source_file_from_empty_local_file" do
    
    source_file = File.new "EmptySource1.c", "w"
    source_file.close
    
    open_add_file
    add_file(
      :upload_from => :local_file,
      :upload_path => File.expand_path(source_file.path) )
  end
  
  test "add_source_file_with_invalid_name" do
  
    open_add_file
    add_file(
      :name => "\/\/ invalid name",
      :upload_from => :local_file,
      :expect => :invalid_upload_path)
  end


  test "add_source_file_all_fields_empty" do
  
    open_add_file
    add_file(
      :name => "",
      :upload_path => "",
      :expect => :invalid_upload_path)
  end

  # RUBY CODE ENDS HERE.
  # BELOW ARE APPENDED ALL DATA STRUCTURES USED BY THE TESTS.
  


# -------------------------------------------------------------------------------------- #
NORMAL_SOURCE = <<CODE_END
#include <QApplication>
#include <QDir>
#include <QFileInfo>
#include <QMessageBox>
#include <QProcess>
#include <QString>
#include <QTextStream>
#include <stdlib.h>
#include "gamestoreform.h"

QString detectDistro()
{
  QFileInfo fi("/etc/SuSE-release");
  if (fi.exists()) return "openSUSE";
  return "";
}

bool detect3D()
{
  QProcess glxinfo;
  glxinfo.start("glxinfo");
  if (!glxinfo.waitForStarted(1000)) return false;
  if (!glxinfo.waitForFinished(1000)) return false;
  QByteArray o = glxinfo.readAll();
  return ( o.indexOf(QByteArray("direct rendering: Yes")) > -1 );
}

int main( int argc, char *argv[] )
{
  QApplication app( argc, argv );

  GameStoreInfo::distro = detectDistro();
  if (GameStoreInfo::distro.isEmpty()) {
    QMessageBox::critical(0, "Error", "Game Store was unable to detect your distribution.");
    return 1;
  }

  char *tmp = getenv("XDG_CACHE_HOME");
  GameStoreInfo::cachedir = tmp ? tmp : QDir::homePath() + "/.cache";
  GameStoreInfo::cachedir += + "/gamestore/";
  QDir dir;
  dir.mkpath(GameStoreInfo::cachedir + "icon");
  dir.mkpath(GameStoreInfo::cachedir + "thumb");

  GameStoreForm *window = new GameStoreForm();
  window->show();

  if (!detect3D()) {
    QMessageBox::warning(0, "Warning", "Your system reports that it is not capable of hardware accelerated 3D graphics. You might expect difficulties running some of the games.\nUsually the cause of this error is that there are no drivers for your graphics card installed.");
  }

  return app.exec();
}
CODE_END
# -------------------------------------------------------------------------------------- #
  
end
