class TC15__AllProjectsList < TestCase


  test :check_public_projects_list do
  depend_on :login_as_user, :create_global_project
  
    navigate_to AllProjectsPage, :user => :none
    filter_projects(
      :pattern => "", 
      :exclude_home_projects => true)
    refresh_page  
    
    assert displayed_projects.include? "PublicProject1"
    assert displayed_projects.include? "BaseDistro"
    # there are way more in the api fixtures
    assert displayed_projects.count > 2
  end


  test :check_all_projects_list do
  depend_on :login_as_user, :create_subproject_with_long_description,
    :create_subproject_with_long_description, :create_subproject_with_only_name, :create_subproject_for_user,
    :create_global_project, :create_home_project_for_second_user
  
    navigate_to AllProjectsPage, :user => :none
    filter_projects(
      :pattern => "", 
      :exclude_home_projects => false)
    refresh_page  

    assert displayed_projects.include? "PublicProject1"
    assert displayed_projects.include? "home:king"
    assert displayed_projects.include? "home:user1"
    assert displayed_projects.include? "home:user1:SubProject1"
    assert displayed_projects.include? "home:user1:SubProject2"
    assert displayed_projects.include? "home:user1:SubProject3"
    assert displayed_projects.include? "home:user2"
    # all the others from the api fixtures are there too
    assert displayed_projects.count > 7
  end


  test :filter_specific_project do
  depend_on :login_as_user, :create_subproject_with_long_description
  
    navigate_to AllProjectsPage, :user => :none
    filter_projects(
      :pattern => "home:user1:SubProject3", 
      :exclude_home_projects => false)
    refresh_page  

    assert displayed_projects.include? "home:user1:SubProject3"
    assert displayed_projects.count == 1
  end


  test :filter_non_global_projects do
  depend_on :login_as_user, :create_subproject_with_long_description, :create_subproject_with_only_name, :create_subproject_for_user
  
    navigate_to AllProjectsPage, :user => :none
    filter_projects(
      :pattern => "home:", 
      :exclude_home_projects => false)
    refresh_page
    
    assert displayed_projects.include? "home:user1"
    assert displayed_projects.include? "home:user1:SubProject1"
    assert displayed_projects.include? "home:user1:SubProject2"
    assert displayed_projects.include? "home:user1:SubProject3"
    assert displayed_projects.count > 6
  end

  test :filter_all_subprojects do
  depend_on :login_as_user
  
    navigate_to AllProjectsPage, :user => :none
    filter_projects(
      :pattern => "Sub", 
      :exclude_home_projects => false)
    refresh_page
    
    assert displayed_projects.include? "home:user1:SubProject1"
    assert displayed_projects.include? "home:user1:SubProject2"
    assert displayed_projects.include? "home:user1:SubProject3"
    assert displayed_projects.count == 3
  end


  test :filter_all_projects_by_user do
  depend_on :login_as_user, :create_subproject_with_long_description, :create_subproject_with_only_name, :create_subproject_for_user
  
    navigate_to AllProjectsPage, :user => :none
    filter_projects(
      :pattern => "user1", 
      :exclude_home_projects => false)
    refresh_page
       
    assert displayed_projects.include? "home:user1"
    assert displayed_projects.include? "home:user1:SubProject1"
    assert displayed_projects.include? "home:user1:SubProject2"
    assert displayed_projects.include? "home:user1:SubProject3"
    assert displayed_projects.count == 4
  end
  
  test :filter_non_existing do
  depend_on :login_as_user
  
    navigate_to AllProjectsPage, :user => :none
    filter_projects(
      :pattern => "dqwdgewrfewdwqdwq", 
      :exclude_home_projects => false)
    refresh_page
    
    assert displayed_projects.count == 0
  end

  
end
