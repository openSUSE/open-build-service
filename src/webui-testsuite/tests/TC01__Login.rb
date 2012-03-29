class TC01__Login < TestCase

  test :login_as_user do
  
    navigate_to MainPage, :user => :none
    login_as $data[:user1]
    logout
  end

  
  test :login_as_second_user do
  
    navigate_to MainPage, :user => :none
    login_as $data[:user2]
    logout
  end

  
  test :login_as_admin do
  
    navigate_to MainPage, :user => :none
    login_as $data[:admin], :admin
    
    # connect to OBS
    $page.interconnect
    
    logout
  end

  
  test :login_invalid_entry do
  
    navigate_to MainPage, :user => :none
    login_as $data[:invalid_user], expect = :error
    login_as $data[:user1]
    logout
  end

  
  test :login_empty_entry do
  
    navigate_to MainPage, :user => :none
    login_as( {:login => "", :password => "" }, expect = :error )
    login_as $data[:user1]
    logout
  end

  
  test :login_from_search do
  
    navigate_to MainPage, :user => :none
    open_search
    login_as $data[:user1]
    logout
  end

  
  test :login_from_all_projects do
  
    navigate_to MainPage, :user => :none
    open_all_projects
    login_as $data[:user1]
    logout
  end

  
  test :login_from_status_monitor do
  
    navigate_to MainPage, :user => :none
    open_status_monitor
    login_as $data[:user1]
    logout
  end
  

end
