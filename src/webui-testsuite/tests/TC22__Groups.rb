class TC22__Groups < TestCase

  test :show_groups do
  depend_on :login_as_user

    navigate_to GroupIndexPage, :user => $data[:user1]
    open_first_group
    open_first_user # On GroupShowPage
  end

end
