require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class IssueControllerTest < ActionController::IntegrationTest
  fixtures :all

  def test_get_issues
    # bugs are public atm. Secret stuff should not get imported.
    get '/issue_trackers'
    assert_response :success
    get '/issue_trackers/bnc'
    assert_response :success
    get '/issue_trackers/bnc/issues/123456'
    assert_response :success

    # as user
    prepare_request_with_user "Iggy", "asdfasdf"
    get '/issue_trackers'
    assert_response :success
    get '/issue_trackers/bnc'
    assert_response :success
#    get '/issue_trackers/bnc/issues'
#    assert_response :success
    get '/issue_trackers/bnc/issues/123456'
    assert_response :success
    assert_xml_tag :tag => 'name', :content => "123456"
    assert_xml_tag :tag => 'tracker', :content => "bnc"
    assert_xml_tag :tag => 'label', :content => "bnc#123456"
    assert_xml_tag :tag => 'url', :content => "https://bugzilla.novell.com/show_bug.cgi?id=123456"
    assert_xml_tag :tag => 'state', :content => "CLOSED"
    assert_xml_tag :tag => 'summary', :content => "OBS is not bugfree!"
    assert_xml_tag :parent => { :tag => 'owner' }, :tag => 'login', :content => "fred"
    assert_xml_tag :parent => { :tag => 'owner' }, :tag => 'email', :content => "fred@feuerstein.de"
    assert_xml_tag :parent => { :tag => 'owner' }, :tag => 'realname', :content => "Frederic Feuerstone"
    assert_no_xml_tag :tag => 'password'

    # get new, incomplete issue .. don't crash ...
    get '/issue_trackers/bnc/issues/1234'
    assert_response :success
    assert_xml_tag :tag => 'name', :content => "1234"
    assert_xml_tag :tag => 'tracker', :content => "bnc"
    assert_no_xml_tag :tag => 'password'
  end

  def test_get_issue_for_patchinfo_and_project
    get '/source/Devel:BaseDistro:Update?view=issues'
    assert_response 401
    get '/source/Devel:BaseDistro:Update/pack3?view=issues'
    assert_response 401

    # as user
    prepare_request_with_user "Iggy", "asdfasdf"
    get '/source/Devel:BaseDistro:Update/pack3?view=issues'
    assert_response :success
    assert_xml_tag :parent => { :tag => 'issue' }, :tag => 'name', :content => "123456"
    assert_xml_tag :parent => { :tag => 'issue' }, :tag => 'tracker', :content => "bnc"
    get '/source/Devel:BaseDistro:Update?view=issues'
    assert_response :success
    assert_xml_tag :parent => { :tag => 'issue' }, :tag => 'name', :content => "123456"
    assert_xml_tag :parent => { :tag => 'issue' }, :tag => 'tracker', :content => "bnc"
  end

  def test_search_issues
    get "/search/package/id", :match => 'issue/@name="123456"'
    assert_response 401
    get "/search/package/id", :match => 'issue/@tracker="bnc"'
    assert_response 401
    get "/search/package/id", :match => 'issue/[@name="123456" and @tracker="bnc"]'
    assert_response 401
    get "/search/package/id", :match => 'issue/owner/@login="fred"'
    assert_response 401
    get "/search/package/id", :match => 'issue/@state="RESOLVED"'
    assert_response 401

    # search via bug owner
    prepare_request_with_user "Iggy", "asdfasdf"
    # running patchinfo search as done by webui
    get "/search/package/id", :match => '[issue/[@state="CLOSED" and owner/@login="fred"] and kind="patchinfo"]'
    assert_response :success
    assert_xml_tag :parent => { :tag => "collection" }, :tag => "package", :attributes => { :project => 'Devel:BaseDistro:Update', :name => 'pack3' }

    get "/search/package/id", :match => 'issue/owner/@login="fred"'
    assert_response :success
    assert_xml_tag :parent => { :tag => "collection" }, :tag => "package", :attributes => { :project => 'Devel:BaseDistro:Update', :name => 'pack3' }

    # search for specific issue state, issue is in RESOLVED state actually
    get "/search/package/id", :match => 'issue/@state="OPEN"'
    assert_response :success
    assert_no_xml_tag :parent => { :tag => "collection" }, :tag => "package", :attributes => { :project => 'Devel:BaseDistro:Update', :name => 'pack3' }

    # running patchinfo search as done by webui
    get "/search/package/id", :match => '[kind="patchinfo" and issue/[@state="CLOSED" and owner/@login="fred"]]'
    assert_response :success
    assert_xml_tag :parent => { :tag => "collection" }, :tag => "package", :attributes => { :project => 'Devel:BaseDistro:Update', :name => 'pack3' }

    # test with not matching kind to verify that it does not match
    get "/search/package/id", :match => '[issue/[@state="CLOSED" and owner/@login="fred"] and kind="aggregate"]'
    assert_response :success
    assert_no_xml_tag :parent => { :tag => "collection" }, :tag => "package", :attributes => { :project => 'Devel:BaseDistro:Update', :name => 'pack3' }

    # search via bug issue id
    get "/search/package/id", :match => '[issue/[@name="123456" and @tracker="bnc"]]'
    assert_response :success
    assert_xml_tag :parent => { :tag => "collection" }, :tag => "package", :attributes => { :project => 'Devel:BaseDistro:Update', :name => 'pack3' }
  end

  def test_get_issue_for_linked_packages
    changes = "-------------------------------------------------------------------\n
Blah bnc#13\n
-------------------------------------------------------------------\n
Blah bnc#14\n
-------------------------------------------------------------------\n
Blubber bnc#15\n
"

    prepare_request_with_user "Iggy", "asdfasdf"
    post "/source/BaseDistro/pack1", :cmd => "branch", :target_project => "home:Iggy:branches:BaseDistro"
    assert_response :success
    put "/source/home:Iggy:branches:BaseDistro/pack1/file.changes", changes
    assert_response :success
    post "/source/home:Iggy:branches:BaseDistro/pack1", :cmd => "branch", :target_project => "home:Iggy:branches:BaseDistro", :target_package => "pack_new"
    assert_response :success
    changes += "-------------------------------------------------------------------\n
Aha bnc#123456\n
"
    changes.gsub!(/Blubber/, 'Blabber') # leads to changed
    changes.gsub!(/bnc#14/, '') # leads to removed
    put "/source/home:Iggy:branches:BaseDistro/pack_new/file.changes", changes
    assert_response :success

    get "/source/home:Iggy:branches:BaseDistro/pack1?view=issues"
    assert_response :success
    get "/source/home:Iggy:branches:BaseDistro/pack_new?view=issues"
    assert_response :success
    assert_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'kept'}}, :tag => 'name', :content => "13"
    assert_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'deleted'}}, :tag => 'name', :content => "14"
    assert_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'changed'}}, :tag => 'name', :content => "15"
    assert_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'added'}}, :tag => 'name', :content => "123456"

    get "/source/home:Iggy:branches:BaseDistro/pack_new?view=issues&changes=added"
    assert_response :success
    assert_no_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'kept'}}, :tag => 'name', :content => "13"
    assert_no_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'deleted'}}, :tag => 'name', :content => "14"
    assert_no_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'changed'}}, :tag => 'name', :content => "15"
    assert_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'added'}}, :tag => 'name', :content => "123456"

    get "/source/home:Iggy:branches:BaseDistro/pack_new?view=issues&changes=kept,deleted"
    assert_response :success
    assert_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'kept'}}, :tag => 'name', :content => "13"
    assert_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'deleted'}}, :tag => 'name', :content => "14"
    assert_no_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'changed'}}, :tag => 'name', :content => "15"
    assert_no_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'added'}}, :tag => 'name', :content => "123456"

    get "/source/home:Iggy:branches:BaseDistro?view=issues&changes=kept,deleted"
    assert_response :success
    assert_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'kept'}}, :tag => 'name', :content => "13"
    assert_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'deleted'}}, :tag => 'name', :content => "14"
    assert_no_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'changed'}}, :tag => 'name', :content => "15"
    assert_no_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'added'}}, :tag => 'name', :content => "123456"

    get "/source/home:Iggy:branches:BaseDistro?view=issues&login=unknown"
    assert_response :success
    assert_no_xml_tag :parent => { :tag => 'issue' }
    get "/source/home:Iggy:branches:BaseDistro/pack_new?view=issues&login=unknown"
    assert_response :success
    assert_no_xml_tag :parent => { :tag => 'issue' }

    get "/source/home:Iggy:branches:BaseDistro?view=issues&login=fred"
    assert_response :success
    assert_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'added'}}, :tag => 'name', :content => "123456"
    get "/source/home:Iggy:branches:BaseDistro/pack_new?view=issues&login=fred"
    assert_response :success
    assert_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'added'}}, :tag => 'name', :content => "123456"

    get "/source/home:Iggy:branches:BaseDistro?view=issues&states=FANTASY"
    assert_response :success
    assert_no_xml_tag :parent => { :tag => 'issue' }
    get "/source/home:Iggy:branches:BaseDistro/pack_new?view=issues&states=FANTASY"
    assert_response :success
    assert_no_xml_tag :parent => { :tag => 'issue' }

    get "/source/home:Iggy:branches:BaseDistro?view=issues&states=OPEN,CLOSED"
    assert_response :success
    assert_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'added'}}, :tag => 'name', :content => "123456"
    get "/source/home:Iggy:branches:BaseDistro/pack_new?view=issues&states=OPEN,CLOSED"
    assert_response :success
    assert_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'added'}}, :tag => 'name', :content => "123456"

    get "/search/package/id", :match => '[issue/[@name="123456" and @tracker="bnc" and @change="added"]]'
    assert_response :success
    assert_xml_tag :parent => { :tag => "collection" }, :tag => "package", :attributes => { :project => 'home:Iggy:branches:BaseDistro', :name => 'pack_new' }

    get "/search/package/id", :match => '[issue/[@name="123456" and @tracker="bnc" and (@change="added" or @change="changed")]]'
    assert_response :success
    assert_xml_tag :parent => { :tag => "collection" }, :tag => "package", :attributes => { :project => 'home:Iggy:branches:BaseDistro', :name => 'pack_new' }

    get "/search/package/id", :match => '[issue/[@name="123456" and @tracker="bnc" and @change="kept"]]'
    assert_response :success
    assert_no_xml_tag :parent => { :tag => "collection" }, :tag => "package", :attributes => { :project => 'home:Iggy:branches:BaseDistro', :name => 'pack_new' }

    #cleanup
    delete "/source/home:Iggy:branches:BaseDistro"
    assert_response :success
  end

  def test_commit_file_to_linked_package
    changes = "-------------------------------------------------------------------\n
Blah bnc#13\n
-------------------------------------------------------------------\n
Blah bnc#14\n
-------------------------------------------------------------------\n
Blubber bnc#15\n
"

    prepare_request_with_user "Iggy", "asdfasdf"
    post "/source/BaseDistro/pack1", :cmd => "branch", :target_project => "home:Iggy:branches:BaseDistro"
    assert_response :success
    put "/source/home:Iggy:branches:BaseDistro/pack1/file.changes", changes
    assert_response :success
    post "/source/home:Iggy:branches:BaseDistro/pack1", :cmd => "branch", :target_project => "home:Iggy:branches:BaseDistro", :target_package => "pack_new"
    assert_response :success
    changes += "-------------------------------------------------------------------\n
Aha bnc#123456\n
"
    changes.gsub!(/Blubber/, 'Blabber') # leads to changed
    changes.gsub!(/bnc#14/, '') # leads to removed
    put "/source/home:Iggy:branches:BaseDistro/pack_new/file.changes?rev=repository", changes
    assert_response :success
    post "/source/home:Iggy:branches:BaseDistro/pack_new?cmd=commitfilelist&keeplink=1", ' <directory> <entry name="file.changes" md5="'+ Digest::MD5.hexdigest(changes) + '" /> </directory> '
    assert_response :success

    get "/source/home:Iggy:branches:BaseDistro/pack1?view=issues"
    assert_response :success
    get "/source/home:Iggy:branches:BaseDistro/pack_new?view=issues"
    assert_response :success
    assert_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'kept'}}, :tag => 'name', :content => "13"
    assert_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'deleted'}}, :tag => 'name', :content => "14"
    assert_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'changed'}}, :tag => 'name', :content => "15"
    assert_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'added'}}, :tag => 'name', :content => "123456"

    #cleanup
    delete "/source/home:Iggy:branches:BaseDistro"
    assert_response :success
  end

  def test_issues_of_missingok_package
    changes = "-------------------------------------------------------------------\n
Blah bnc#13\n
-------------------------------------------------------------------\n
Blah bnc#14\n
-------------------------------------------------------------------\n
Blubber bnc#15\n
"

    prepare_request_with_user "Iggy", "asdfasdf"
    post "/source/BaseDistro/new_package", :cmd => "branch", :missingok => 1, :target_project => "home:Iggy:branches:BaseDistro"
    assert_response :success
    put "/source/home:Iggy:branches:BaseDistro/new_package/file.changes", changes
    assert_response :success
    put "/source/home:Iggy:branches:BaseDistro/new_package/file.changes?rev=repository", changes
    assert_response :success
    post "/source/home:Iggy:branches:BaseDistro/new_package?cmd=commitfilelist&keeplink=1", ' <directory> <entry name="file.changes" md5="'+ Digest::MD5.hexdigest(changes) + '" /> </directory> '
    assert_response :success

    get "/source/home:Iggy:branches:BaseDistro/new_package?view=issues"
    assert_response :success
    assert_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'added'}}, :tag => 'name', :content => "13"
    assert_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'added'}}, :tag => 'name', :content => "14"
    assert_xml_tag :parent => { :tag => 'issue', :attributes => {:change => 'added'}}, :tag => 'name', :content => "15"

    #cleanup
    delete "/source/home:Iggy:branches:BaseDistro"
    assert_response :success
  end

end
