require File.dirname(__FILE__) + '/../test_helper'
require 'time'

class StatisticsControllerTest < ActionController::IntegrationTest

  fixtures :all

  def test_latest_added
    prepare_request_with_user "adrian", "so_alone"
    get url_for(:controller => :source, :action => :package_meta, :project => "HiddenProject", :package => "test_latest_added")
    assert_response 404
    put url_for(:controller => :source, :action => :package_meta, :project => "HiddenProject", :package => "test_latest_added"), 
        '<package project="HiddenProject" name="test_latest_added"> <title/> <description/> </package>'
    assert_response 200
    assert_tag( :tag => "status", :attributes => { :code => "ok"} )

    get url_for(:controller => :statistics, :action => :latest_added)
    assert_response :success
if $ENABLE_BROKEN_TEST
#FIXME2.2
    assert_tag :tag => 'latest_added', :child => { :tag => 'package' }
    assert_tag :tag => 'package', :attributes => { :name => "test_latest_added" }
end

    prepare_request_with_user 'tom', 'thunder'
    get url_for(:controller => :statistics, :action => :latest_added)
    assert_response :success
if $ENABLE_BROKEN_TEST
#FIXME2.2
    assert_tag :tag => 'latest_added', :child => { :tag => 'project' }
    assert_tag :tag => 'project', :attributes => {
      :name => "kde4",
      :created => Time.local(2008, 04, 28, 05, 05, 05).xmlschema
    }
end

    prepare_request_with_user "fred", "geröllheimer"
    get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "test_latest_added1")
    assert_response 404
    put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "test_latest_added1"), 
        '<package project="kde4" name="test_latest_added1"> <title/> <description/> </package>'
    assert_response 200
    assert_tag( :tag => "status", :attributes => { :code => "ok"} )

    get url_for(:controller => :statistics, :action => :latest_added)
    assert_response :success
if $ENABLE_BROKEN_TEST
#FIXME2.2
    assert_tag :tag => 'latest_added', :child => { :tag => 'package' }
    assert_tag :tag => 'package', :attributes => { :name => "test_latest_added1" }
end
  end


 def test_latest_updated
   prepare_request_with_user "adrian", "so_alone"
   get url_for(:controller => :source, :action => :package_meta, :project => "HiddenProject", :package => "test_latest_added")
   assert_response 404
   put url_for(:controller => :source, :action => :package_meta, :project => "HiddenProject", :package => "test_latest_added"), 
   '<package project="HiddenProject" name="test_latest_added"> <title/> <description/> </package>'
   assert_response 200
   assert_tag( :tag => "status", :attributes => { :code => "ok"} )

   get url_for(:controller => :statistics, :action => :latest_updated)
   assert_response :success
if $ENABLE_BROKEN_TEST
#FIXME2.2
   assert_tag :tag => 'latest_updated', :child => { :tag => 'package' }
   assert_tag :tag => 'package', :attributes => { :name => "test_latest_added" }
end

   prepare_request_with_user 'tom', 'thunder'
   get url_for(:controller => :statistics, :action => :latest_updated)
   assert_response :success
if $ENABLE_BROKEN_TEST
#FIXME2.2
   assert_tag :tag => 'latest_updated', :child => { :tag => 'project' }
   assert_tag :tag => 'project', :attributes => {
     :name => "kde4",
     :updated => Time.local(2008, 04, 28, 06, 06, 06).xmlschema,
   }
end

   prepare_request_with_user "fred", "geröllheimer"
   get url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "test_latest_added1")
   assert_response 404
   put url_for(:controller => :source, :action => :package_meta, :project => "kde4", :package => "test_latest_added1"), 
   '<package project="kde4" name="test_latest_added1"> <title/> <description/> </package>'
   assert_response 200
   assert_tag( :tag => "status", :attributes => { :code => "ok"} )

   get url_for(:controller => :statistics, :action => :latest_updated)
   assert_response :success
if $ENABLE_BROKEN_TEST
#FIXME2.2
   assert_tag :tag => 'latest_updated', :child => { :tag => 'package' }
   assert_tag :tag => 'package', :attributes => { :name => "test_latest_added1" }
end
 end


 def test_timestamp_calls
   prepare_request_with_user "adrian", "so_alone"
   get url_for(:controller => :statistics, :action => :added_timestamp, :project => "HiddenProject", :package => "pack")
   assert_response 200

   get url_for(:controller => :statistics, :action => :updated_timestamp , :project => "HiddenProject", :package => "pack")
   assert_response 200

   get url_for(:controller => :statistics, :action => :added_timestamp, :project => "kde4", :package => "kdelibs")
   assert_response 200

   get url_for(:controller => :statistics, :action => :updated_timestamp, :project => "kde4", :package => "kdelibs")
   assert_response 200

   prepare_request_with_user "fred", "geröllheimer"
   get url_for(:controller => :statistics, :action => :added_timestamp, :project => "kde4", :package => "kdelibs")
   assert_response 200

   get url_for(:controller => :statistics, :action => :updated_timestamp, :project => "kde4", :package => "kdelibs")
   assert_response 200

   get url_for(:controller => :statistics, :action => :added_timestamp , :project => "HiddenProject", :package => "not_existing")
   assert_response 404

   get url_for(:controller => :statistics, :action => :updated_timestamp , :project => "HiddenProject", :package => "not_existing")
   assert_response 404

   get url_for(:controller => :statistics, :action => :added_timestamp , :project => "HiddenProject")
   assert_response 404

   get url_for(:controller => :statistics, :action => :updated_timestamp , :project => "HiddenProject")
   assert_response 404

 end

 def test_rating_and_activity
   prepare_request_with_user "adrian", "so_alone"
   get url_for(:controller => :statistics, :action => :rating, :project => "kde4", :package => "kdelibs")
   assert_response :success

   get url_for(:controller => :statistics, :action => :rating, :project => "kde4")
   assert_response :success

   get url_for(:controller => :statistics, :action => :rating , :project => "HiddenProject", :package => "NOT_EXISTING")
   assert_response 404

   get url_for(:controller => :statistics, :action => :rating , :project => "HiddenProject")
   assert_response :success

   get url_for(:controller => :statistics, :action => :activity, :project => "kde4", :package => "kdelibs")
   assert_response :success

   get url_for(:controller => :statistics, :action => :activity, :project => "kde4")
   assert_response :success

   get url_for(:controller => :statistics, :action => :activity , :project => "HiddenProject", :package => "pack")
   assert_response :success

   get url_for(:controller => :statistics, :action => :activity , :project => "HiddenProject")
   assert_response :success

   # no access to HiddenProject
   prepare_request_with_user "fred", "geröllheimer"
   get url_for(:controller => :statistics, :action => :rating, :project => "kde4", :package => "kdelibs")
   assert_response :success

   get url_for(:controller => :statistics, :action => :rating , :project => "HiddenProject")
   assert_response 404

   get url_for(:controller => :statistics, :action => :rating , :project => "HiddenProject", :package => "NOT_EXISTING")
   assert_response 404

   get url_for(:controller => :statistics, :action => :activity, :project => "kde4", :package => "kdelibs")
   assert_response :success
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

if $ENABLE_BROKEN_TEST
#FIXME2.2
# fixture data is actually there, this test case looks broken anyway, but it became
# different broken now. The statistic stuff need anyway a big overhowl and is not usable atm :/
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
