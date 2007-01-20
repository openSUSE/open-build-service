require File.dirname(__FILE__) + '/../test_helper'
require 'statistics_controller'

# Re-raise errors caught by the controller.
class StatisticsController; def rescue_action(e) raise e end; end

class StatisticsControllerTest < Test::Unit::TestCase


  fixtures :db_projects, :db_packages


  def setup
    @controller = StatisticsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end


  def test_latest_added
    prepare_request_with_user @request, 'tom', 'thunder'
    get :latest_added
    assert_response :success
    assert_tag :tag => 'collection', :child => { :tag => 'item' }
    assert_tag :tag => 'item', :attributes => {
      :name => "kde4",
      :created => "2005-05-05T05:05:05+02:00",
      :kind => "project"
    }
  end


  def test_latest_updated
    prepare_request_with_user @request, 'tom', 'thunder'
    get :latest_updated
    assert_response :success
    assert_tag :tag => 'collection', :child => { :tag => 'item' }
    assert_tag :tag => 'item', :attributes => {
      :name => "kde4",
      :updated => "2006-06-06T06:06:06+02:00",
      :kind => "project"
    }
  end


  def test_most_downloads
    prepare_request_with_user @request, 'tom', 'thunder'
    get :most_downloaded
    assert_response :success
    assert_tag :tag => 'collection', :child => { :tag => 'package' }
    assert_tag :tag => 'package', :attributes => {
      :name => "kdelibs",
      :project => "kde4",
      :downloads => "12345"
    }
  end


  # TODO: implement test
  def test_latest_built
    #prepare_request_with_user @request, 'tom', 'thunder'
    #get :latest_built
    #assert_response :success
    #assert_tag :tag => 'collection', :child => { :tag => 'xxxxx' }
    #assert_tag :tag => 'package', :attributes => {
    #  :name => "kdelibs",
    #  :xxx => "xxx",
    #}
  end


  # TODO: implement test
  def test_most_active
    #prepare_request_with_user @request, 'tom', 'thunder'
    #get :most_active
    #assert_response :success
    #assert_tag :tag => 'collection', :child => { :tag => 'xxxxx' }
    #assert_tag :tag => 'package', :attributes => {
    #  :name => "kdelibs",
    #  :xxx => "xxx",
    #}
  end


  # TODO: implement test
  def test_highest_rated
    #prepare_request_with_user @request, 'tom', 'thunder'
    #get :highest_rated
    #assert_response :success
    #assert_tag :tag => 'collection', :child => { :tag => 'xxxxx' }
    #assert_tag :tag => 'package', :attributes => {
    #  :name => "kdelibs",
    #  :xxx => "xxx",
    #}
  end


end
