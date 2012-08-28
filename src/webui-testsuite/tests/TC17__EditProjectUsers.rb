class TC17__EditProjectUsers < TestCase


  test :edit_project_user_increase_roles do
  depend_on :add_project_bugowner
    
    navigate_to ProjectOverviewPage,
      :user => $data[:user1],
      :project => "home:user1"
    open_tab "users"
    edit_user :name => :user3,
      :reviewer   => true,
      :downloader => true
  end
  

  test :edit_project_user_reduce_roles do
  depend_on :edit_project_user_increase_roles
    
    navigate_to ProjectOverviewPage,
      :user => $data[:user1],
      :project => "home:user1"
    open_tab "users"
    edit_user :name => :user3,
      :reviewer   => false,
      :downloader => false
  end
  

  test :edit_project_user_remove_all_roles do
  depend_on :add_additional_project_roles_to_a_user
    
    navigate_to ProjectOverviewPage,
      :user => $data[:user1],
      :project => "home:user1"
    open_tab "users"
    edit_user :name => :user6,
      :maintainer => false,
      :bugowner   => false,
      :reviewer   => false,
      :downloader => false,
      :reader     => false
  end
  
  
  test :edit_project_user_add_all_roles do
  depend_on :add_project_reviewer
    
    navigate_to ProjectOverviewPage,
      :user => $data[:user1],
      :project => "home:user1"
    open_tab "users"
    edit_user :name => :user4,
      :maintainer => true,
      :bugowner   => true,
      :reviewer   => true,
      :downloader => true,
      :reader     => true
  end
  
  
end

