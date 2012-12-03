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
  
  # RUBY CODE ENDS HERE.
  # BELOW ARE APPENDED ALL DATA STRUCTURES USED BY THE TESTS.
  


# -------------------------------------------------------------------------------------- #
NORMAL_SOURCE = <<CODE_END
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
