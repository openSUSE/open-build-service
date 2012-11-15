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
This
is
a very
long
text
that
will
break
into
many 
many
lines.

Way
more
than
what
might
be
reasonable
so
the
lines
are folded
away
by
default.
LICENSE_END
# -------------------------------------------------------------------------------------- #


end
