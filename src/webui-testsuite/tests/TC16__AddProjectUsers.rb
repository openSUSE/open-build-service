class TC16__AddProjectUsers < TestCase


  test :add_project_maintainer do
  depend_on :create_home_project_for_user
  
    navigate_to ProjectOverviewPage,
      :user => $data[:user1],
      :project => "home:user1"
    open_tab "users"
    add_user "user2", "maintainer"
  end
  
  
  test :add_project_bugowner do
  depend_on :create_home_project_for_user
  
    navigate_to ProjectOverviewPage,
      :user => $data[:user1],
      :project => "home:user1"
    open_tab "users"
    add_user "user3", "bugowner"
  end
  
  
  test :add_project_reviewer do
  depend_on :create_home_project_for_user
  
    navigate_to ProjectOverviewPage,
      :user => $data[:user1],
      :project => "home:user1"
    open_tab "users"
    add_user "user4", "reviewer"
  end
  
  
  test :add_project_downloader do
  depend_on :create_home_project_for_user
  
    navigate_to ProjectOverviewPage,
      :user => $data[:user1],
      :project => "home:user1"
    open_tab "users"
    add_user "user5", "downloader"
  end
  
  
  test :add_project_reader do
  depend_on :create_home_project_for_user
  
    navigate_to ProjectOverviewPage,
      :user => $data[:user1],
      :project => "home:user1"
    open_tab "users"
    add_user "user6", "reader"
  end
  
  
  test :add_additional_project_roles_to_a_user do
  depend_on :add_project_reader
  
    navigate_to ProjectOverviewPage,
      :user => $data[:user1],
      :project => "home:user1"
    open_tab "users"
    add_user "user6", "reviewer"
    add_user "user6", "downloader"
  end
  
  
  test :add_all_project_roles_to_admin do
  depend_on :create_home_project_for_user
    
    navigate_to ProjectOverviewPage,
      :user => $data[:user1],
      :project => "home:user1"
    open_tab "users"
    add_user "king", "maintainer"
    add_user "king", "bugowner"
    add_user "king", "reviewer"
    add_user "king", "downloader"
    add_user "king", "reader"
  end
  
  
  test :add_project_role_to_non_existing_user do
  depend_on :create_home_project_for_user
  
    navigate_to ProjectOverviewPage,
      :user => $data[:user1],
      :project => "home:user1"
    open_tab "users"
    add_user "sadasxsacxsacsa", "reader", :expect => :unknown_user
  end
  
  
  test :add_project_role_with_empty_user_field do
  depend_on :create_home_project_for_user
  
    navigate_to ProjectOverviewPage,
      :user => $data[:user1],
      :project => "home:user1"
    open_tab "users"
    add_user "", "maintainer", :expect => :invalid_userid
  end
  
  
  test :add_project_role_to_invalid_username do
  depend_on :create_home_project_for_user
  
    navigate_to ProjectOverviewPage,
      :user => $data[:user1],
      :project => "home:user1"
    open_tab "users"
    add_user '~@$@#%#%@$0-=<m,.,\/\/12`;.{{}}{}', "maintainer", :expect => :invalid_userid
  end
  
  
  test :add_project_role_to_username_with_question_sign do
  depend_on :create_home_project_for_user
  
    navigate_to ProjectOverviewPage,
      :user => $data[:user1],
      :project => "home:user1"
    open_tab "users"
    add_user 'still-buggy?', "maintainer", :expect => :invalid_userid
  end
  
  
end
