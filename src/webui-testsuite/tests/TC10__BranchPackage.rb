class TC10__BranchPackage < TestCase


  test :branch_package_for_home_project do
  depend_on :create_home_project_package_for_user,
            :create_home_project_for_second_user,
            :add_new_source_file_to_home_project_package
  
    navigate_to ProjectOverviewPage,
      :user => $data[:user2],
      :project => "home:user2"
    open_branch_package
    create_package_branch(
      :name => "HomePackage1",
      :original_name => "HomePackage1",
      :original_project => "home:user1")
  end
    
    
  test :branch_package_for_subproject do
  depend_on :create_subproject_package_for_user,
            :create_home_project_for_second_user
  
    navigate_to ProjectOverviewPage,
      :user => $data[:user2],
      :project => "home:user2"
    open_branch_package
    create_package_branch(
      :name => "SubPackage1",
      :original_name => "SubPackage1",
      :original_project => "home:user1:SubProject1")
  end
    
    
  test :branch_package_for_global_project do
  depend_on :create_global_project_package,
            :create_home_project_for_second_user,
	    :add_new_source_file_to_global_project_package
  
    navigate_to ProjectOverviewPage,
      :user => $data[:user2],
      :project => "home:user2"
    open_branch_package
    create_package_branch(
      :name => "PublicPackage1",
      :original_name => "PublicPackage1",
      :original_project => "PublicProject1")
  end
    
  
  test :branch_package_twice_duplicate_name do
  depend_on :branch_package_for_home_project
  
    navigate_to ProjectOverviewPage,
      :user => $data[:user2],
      :project => "home:user2"
    open_branch_package
    create_package_branch(
      :expect => :already_exists,
      :name => "HomePackage1",
      :original_name => "HomePackage1",
      :original_project => "home:user1")
  end
  
    
  test :branch_package_twice do
  depend_on :branch_package_for_home_project
  
    navigate_to ProjectOverviewPage,
      :user => $data[:user2],
      :project => "home:user2"
    open_branch_package
    create_package_branch(
      :name => "HomePackage1-Duplicate",
      :original_name => "HomePackage1",
      :original_project => "home:user1")
  end


  test :branch_empty_package_name do
  depend_on :create_home_project_package_for_user,
            :create_home_project_for_second_user
  
    navigate_to ProjectOverviewPage,
      :user => $data[:user2],
      :project => "home:user2"
    open_branch_package
    create_package_branch(
      :name => "",
      :original_name => "",
      :original_project => "home:user1",
      :expect => :invalid_package_name)
  end
  
  test :branch_empty_project_name do
  depend_on :create_home_project_package_for_user,
            :create_home_project_for_second_user
  
    navigate_to ProjectOverviewPage,
      :user => $data[:user2],
      :project => "home:user2"
    open_branch_package
    create_package_branch(
      :name => "HomePackage1",
      :original_name => "HomePackage1",
      :original_project => "",
      :expect => :invalid_project_name)
  end

  test :branch_package_name_with_spaces do
  depend_on :create_home_project_package_for_user,
            :create_home_project_for_second_user
  
    navigate_to ProjectOverviewPage,
      :user => $data[:user2],
      :project => "home:user2"
    open_branch_package
    create_package_branch(
      :name => "BranchedPackage",
      :original_name => "invalid package name",
      :original_project => "home:user1",
      :expect => :invalid_package_name)
  end


  test :branch_project_name_with_spaces do
  depend_on :create_home_project_package_for_user,
            :create_home_project_for_second_user
  
    navigate_to ProjectOverviewPage,
      :user => $data[:user2],
      :project => "home:user2"
    open_branch_package
    create_package_branch(
      :name => "BranchedPackage",
      :original_name => "SomePackage",
      :original_project => "invalid project name",
      :expect => :invalid_project_name)
  end
  
  
end
