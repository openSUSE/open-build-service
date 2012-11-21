class TC04__EditProject < TestCase

  
  test :change_home_project_title do
  depend_on :create_home_project_for_user

    navigate_to ProjectOverviewPage, 
      :user    => $data[:user1],
      :project => "home:user1"
    change_project_info(
      :title => "My Title hopefully got changed " + Time.now.to_i.to_s)
  end

  
  test :change_home_project_description do
  depend_on :create_home_project_for_user

    navigate_to ProjectOverviewPage, 
      :user    => $data[:user1],
      :project => "home:user1"
    change_project_info(
      :description => "New description. Not kidding.. Brand new! " + Time.now.to_i.to_s)
  end

  
  test :change_home_project_info do
  depend_on :create_home_project_for_user
  
    navigate_to ProjectOverviewPage, 
      :user    => $data[:user1],
      :project => "home:user1"
    change_project_info(
      :title => "My Title hopefully got changed " + Time.now.to_i.to_s,
      :description => "New description. Not kidding.. Brand new! " + Time.now.to_i.to_s)
  end

    
  test :change_subproject_title do
  depend_on :create_subproject_for_user
  
    navigate_to ProjectOverviewPage, 
      :user    => $data[:user1],
      :project => "home:user1:SubProject1"
    change_project_info(
      :title => "My Title hopefully got changed " + Time.now.to_i.to_s)
  end

  
  test :change_subproject_description do
  depend_on :create_subproject_for_user
  
    navigate_to ProjectOverviewPage, 
      :user    => $data[:user1],
      :project => "home:user1:SubProject1"
    change_project_info(
      :description => "New description. Not kidding.. Brand new! " + Time.now.to_i.to_s)
  end
  
  test :change_subproject_info do
  depend_on :create_subproject_for_user
  
    navigate_to ProjectOverviewPage, 
      :user    => $data[:user1],
      :project => "home:user1:SubProject1"
    change_project_info(
      :title => "My Title hopefully got changed " + Time.now.to_i.to_s,
      :description => "New description. Not kidding.. Brand new! " + Time.now.to_i.to_s)
  end

  
  test :change_global_project_title do
  depend_on :create_global_project
  
    navigate_to ProjectOverviewPage, 
      :user    => $data[:admin],
      :project => "PublicProject1"
    change_project_info(
      :title => "My Title hopefully got changed " + Time.now.to_i.to_s)
  end

  
  test :change_global_project_description do
  depend_on :create_global_project
  
    navigate_to ProjectOverviewPage, 
      :user    => $data[:admin],
      :project => "PublicProject1"
    change_project_info(
      :description => "New description. Not kidding.. Brand new! " + Time.now.to_i.to_s)
  end

  
  test :change_global_project_info do
  depend_on :create_global_project
  
    navigate_to ProjectOverviewPage, 
      :user    => $data[:admin],
      :project => "PublicProject1"
    change_project_info(
      :title => "My Title hopefully got changed " + Time.now.to_i.to_s,
      :description => "New description. Not kidding.. Brand new! " + Time.now.to_i.to_s)
  end

  
end
