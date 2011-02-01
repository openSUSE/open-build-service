require 'test_helper'
require 'has_mobile_views'

class MobileController < ActionController::Base
  has_mobile_views
  def index
    render :nothing => true
  end

  def rescue_action_in_public e
    raise e
  end
end
ActionController::Routing::Routes.draw {|map| map.resources :mobile }

class HasMobileViewsTest < ActionController::TestCase
  tests MobileController

  test "should set the mode properly" do
    get :index
    assert_equal false, session[:mobile_view]
    assert !@controller.view_paths.include?("app/mobile_views")

    get :index, :force_view => 'mobile'
    assert_equal true, session[:mobile_view]
    assert @controller.view_paths.include?("app/mobile_views")
  end

end