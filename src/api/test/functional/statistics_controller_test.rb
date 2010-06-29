require File.dirname(__FILE__) + '/../test_helper'
require 'time'

class StatisticsControllerTest < ActionController::IntegrationTest

  fixtures :all

  def test_latest_added
    prepare_request_with_user 'tom', 'thunder'
    get url_for(:controller => :statistics, :action => :latest_added)
    assert_response :success
    assert_tag :tag => 'latest_added', :child => { :tag => 'project' }
    assert_tag :tag => 'project', :attributes => {
      :name => "kde4",
      :created => Time.local(2008, 04, 28, 05, 05, 05).xmlschema
    }
  end


 def test_latest_updated
   prepare_request_with_user 'tom', 'thunder'
   get url_for(:controller => :statistics, :action => :latest_updated)
   assert_response :success
   assert_tag :tag => 'latest_updated', :child => { :tag => 'project' }
   assert_tag :tag => 'project', :attributes => {
     :name => "kde4",
     :updated => Time.local(2008, 04, 28, 06, 06, 06).xmlschema,
   }
 end


  def test_download_counter
    prepare_request_with_user 'tom', 'thunder'
    get url_for(:controller => :statistics, :action => :download_counter)
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


  def test_download_counter_group_by
    prepare_request_with_user 'tom', 'thunder'
    # without project- & package-filter
    get url_for(:controller => :statistics, :action => :download_counter, 'group_by' => 'project' )
    assert_response :success
    assert_tag :tag => 'download_counter', :child => { :tag => 'count' }
    assert_tag :tag => 'download_counter', :attributes => { :all => 9302 }
    assert_tag :tag => 'count', :attributes => {
      :project => 'Apache', :files => '9'
    }, :content => '8806'
    # with project- & package-filter
    get url_for(:controller => :statistics, :action => :download_counter,
      'project' => 'Apache', 'package' => 'apache2', 'group_by' => 'arch')
    assert_response :success
    assert_tag :tag => 'download_counter', :child => { :tag => 'count' }
    assert_tag :tag => 'download_counter',
      :attributes => { :all => 9302 }
    assert_tag :tag => 'count', :attributes => {
      :arch => 'x86_64', :files => '6'
    }, :content => '5537'
  end


  def test_most_active
    prepare_request_with_user 'tom', 'thunder'
    # get most active packages
    get url_for(:controller => :statistics, :action => :most_active, :type => 'packages')
    assert_response :success
    assert_tag :tag => 'most_active', :child => { :tag => 'package' }
    assert_tag :tag => 'package', :attributes => {
      :name => "x11vnc",
      :project => "home:dmayr",
      :update_count => 0
    }
    # get most active projects
    get url_for(:action => :most_active, :type => 'projects')
    assert_response :success
    assert_tag :tag => 'most_active', :child => { :tag => 'project' }
    assert_tag :tag => 'project', :attributes => {
      :name => "home:dmayr",
      :packages => 1
    }
  end


  def test_highest_rated
    prepare_request_with_user 'tom', 'thunder'
    get url_for(:controller => :statistics, :action => :highest_rated)
    assert_response :success
    #assert_tag :tag => 'collection', :child => { :tag => 'xxxxx' }
    #assert_tag :tag => 'package', :attributes => {
    #  :name => "kdelibs",
    #  :xxx => "xxx",
    #}
  end


end
