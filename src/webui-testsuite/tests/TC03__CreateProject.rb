class TC03__CreateProject < TestCase


  test :create_home_project_for_user do
  depend_on :login_as_user
  
    navigate_to MainPage, :user => $data[:user1]
    open_new_project
    assert creating_home_project?
    create_project(:title => "HomeProject Title",
                   :description => "Test generated empty home project.")
  end
  
  
  test :create_home_project_for_second_user do
  depend_on :login_as_second_user
  
    navigate_to MainPage, :user => $data[:user2]
    open_new_project
    assert creating_home_project?
    create_project(
                   :title => "HomeProject Title",
                   :description => "Test generated empty home project for second user.")
  end


  test :create_subproject_for_user do
  depend_on :create_home_project_for_user
  
    navigate_to ProjectOverviewPage, 
      :user => $data[:user1],
      :project => "home:user1"
    open_create_subproject
    create_project(
      :name => "SubProject1", 
      :title => "SubProject1 Title",
      :description => "Test generated empty subproject.")
  end

  
  test :create_home_project_for_admin do
  depend_on :login_as_admin
  
    navigate_to MainPage, :user => $data[:admin]
    # now done in login as it involves interconnect
  end

  
  test :create_subproject_without_name do
  depend_on :create_home_project_for_user
  
    navigate_to ProjectOverviewPage, 
      :user => $data[:user1],
      :project => "home:user1"
    open_create_subproject
    create_project( 
      :name => "", 
      :title => "NewTitle" + Time.now.to_i.to_s, 
      :description => "Test generated empty project without name. Should give error!",
      :expect => :invalid_name)    
  end
  
  
  test :create_subproject_name_with_spaces do
  depend_on :create_home_project_for_user
  
    navigate_to ProjectOverviewPage, 
      :user => $data[:user1],
      :project => "home:user1"
    open_create_subproject
    create_project( 
      :name => "project name with spaces", 
      :title => "NewTitle" + Time.now.to_i.to_s, 
      :description => "Test generated empty project without name. Should give error!",
      :expect => :invalid_name)    
  end

  
  test :create_subproject_with_only_name do
  depend_on :create_home_project_for_user
    
    navigate_to ProjectOverviewPage, 
      :user => $data[:user1],
      :project => "home:user1"
    open_create_subproject
    create_project(
      :name => "SubProject2",
      :title => "",
      :description => "")
  end

  
  test :create_subproject_with_long_description do
  depend_on :create_home_project_for_user
  
    navigate_to ProjectOverviewPage, 
      :user => $data[:user1],
      :project => "home:user1"
    open_create_subproject
    create_project( 
      :name => "SubProject3", 
      :title => "Subproject with long text", 
      :description => LONG_DESCRIPTION)
  end

  
  test :create_subproject_duplicate_name do
  depend_on :create_subproject_for_user
  
    navigate_to ProjectOverviewPage, 
      :user => $data[:user1],
      :project => "home:user1"
    open_create_subproject
    create_project( 
      :name => "SubProject1", 
      :title => "NewTitle" + Time.now.to_i.to_s, 
      :description => "Empty subproject with duplicated name. Should give error!",
      :expect => :already_exists)
  end

  
  test :create_global_project do
  depend_on :login_as_admin
  
    navigate_to AllProjectsPage, :user => $data[:admin]
    open_new_project
    create_project(
      :name => "PublicProject1",
      :title => "NewTitle" + Time.now.to_i.to_s, 
      :description => "Test generated empty public project by #{current_user[:login]}.")
  end

  
  test :create_global_project_as_user do
  depend_on :login_as_user
  
    navigate_to AllProjectsPage, :user => $data[:user1]
    open_new_project
    create_project(
      :name => "PublicProj-" + Time.now.to_i.to_s,
      :title => "NewTitle" + Time.now.to_i.to_s, 
      :description => "Test generated empty public project by user. Should give error.",
      :expect => :no_permission)
  end
  
  
  # RUBY CODE ENDS HERE.
  # BELOW ARE APPENDED ALL DATA STRUCTURES USED BY THE TESTS.
  


# -------------------------------------------------------------------------------------- #
LONG_DESCRIPTION = <<LICENSE_END
        GNU GENERAL PUBLIC LICENSE
           Version 2, June 1991

 Copyright (C) 1989, 1991 Free Software Foundation, Inc.
 51 Franklin Steet, Fifth Floor, Boston, MA  02111-1307  USA
 Everyone is permitted to copy and distribute verbatim copies
 of this license document, but changing it is not allowed.

          Preamble

  The licenses for most software are designed to take away your
freedom to share and change it.  By contrast, the GNU General Public
License is intended to guarantee your freedom to share and change free
software--to make sure the software is free for all its users.  This
General Public License applies to most of the Free Software
Foundation's software and to any other program whose authors commit to
using it.  (Some other Free Software Foundation software is covered by
the GNU Library General Public License instead.)  You can apply it to
your programs, too.

  When we speak of free software, we are referring to freedom, not
price.  Our General Public Licenses are designed to make sure that you
have the freedom to distribute copies of free software (and charge for
this service if you wish), that you receive source code or can get it
if you want it, that you can change the software or use pieces of it
in new free programs; and that you know you can do these things.

  To protect your rights, we need to make restrictions that forbid
anyone to deny you these rights or to ask you to surrender the rights.
These restrictions translate to certain responsibilities for you if you
distribute copies of the software, or if you modify it.

LICENSE_END
# -------------------------------------------------------------------------------------- #


end
