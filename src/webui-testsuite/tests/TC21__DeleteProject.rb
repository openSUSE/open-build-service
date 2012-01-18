class TC21__DeleteProject < TestCase


  test :delete_subproject do
  depend_on :create_subproject_for_user
    
    navigate_to ProjectOverviewPage, 
      :user => $data[:user1],
      :project => "home:user1:SubProject1"
    delete_project :newproject => "home:user1"
  end

  
  test :delete_home_project do
  depend_on :create_home_project_for_user
    
    navigate_to ProjectOverviewPage, 
      :user => $data[:user1],
      :project => "home:user1"
    delete_project
  end

  
  test :delete_global_project do
  depend_on :create_global_project
  
    navigate_to ProjectOverviewPage, 
      :user => $data[:admin],
      :project => "PublicProject1"
    delete_project
  end
  
  
end
