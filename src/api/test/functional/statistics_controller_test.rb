require File.dirname(__FILE__) + '/../test_helper'
require 'statistics_controller'

# Re-raise errors caught by the controller.
class StatisticsController; def rescue_action(e) raise e end; end

class StatisticsControllerTest < Test::Unit::TestCase


  fixtures :db_projects, :db_packages, :download_stats, :repositories, :architectures


  def setup
    @controller = StatisticsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end


  def test_latest_added
    prepare_request_with_user @request, 'tom', 'thunder'
    get :latest_added
    assert_response :success
    assert_tag :tag => 'latest_added', :child => { :tag => 'project' }
    assert_tag :tag => 'project', :attributes => {
      :name => "kde4",
      :created => "2008-04-28T05:05:05+02:00",
    }
  end


 def test_latest_updated
   prepare_request_with_user @request, 'tom', 'thunder'
   get :latest_updated
   assert_response :success
   assert_tag :tag => 'latest_updated', :child => { :tag => 'project' }
   assert_tag :tag => 'project', :attributes => {
     :name => "kde4",
     :updated => "2008-04-28T06:06:06+02:00",
   }
 end


  def test_download_counter
    prepare_request_with_user @request, 'tom', 'thunder'
    get :download_counter
    assert_response :success
    assert_tag :tag => 'download_counter', :child => { :tag => 'count' }
    assert_tag :tag => 'download_counter', :attributes => { :sum => 9302 }
    assert_tag :tag => 'count', :attributes => {
      :project => 'Apache',
      :package => 'apache2',
      :repository => 'SUSE_Linux_10.1',
      :architecture => 'x86_64'
    }
    assert_tag :tag => 'count', :content => '4096'
  end


  def test_download_counter_concatenated
    prepare_request_with_user @request, 'tom', 'thunder'
    # without project- & package-filter
    get :download_counter, { 'concat' => 'project' }
    assert_response :success
    assert_tag :tag => 'download_counter', :child => { :tag => 'count' }
    assert_tag :tag => 'download_counter', :attributes => { :sum => 9302 }
    assert_tag :tag => 'count', :attributes => {
      :project => 'Apache', :files => '9'
    }, :content => '8806'
    # with project- & package-filter
    get :download_counter, {
      'project' => 'Apache', 'package' => 'apache2', 'concat' => 'architecture'
    }
    assert_response :success
    assert_tag :tag => 'download_counter', :child => { :tag => 'count' }
    assert_tag :tag => 'download_counter', :attributes => { :sum => 8791 }
    assert_tag :tag => 'count', :attributes => {
      :architecture => 'x86_64', :files => '2'
    }, :content => '5207'
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
