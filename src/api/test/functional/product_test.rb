require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'source_controller'

class ProductTests < ActionDispatch::IntegrationTest 
  fixtures :all
  
  def test_simple_product_file
    login_tom
    put "/source/home:tom:temporary/_meta",
        '<project name="home:tom:temporary"> <title/> <description/> 
           <repository name="me" />
         </project>'
    assert_response :success
    put "/source/home:tom:temporary/_product/_meta",
        '<package project="home:tom:temporary" name="_product"> <title/> <description/> 
            <person userid="adrian" role="maintainer" />
         </package>'
    assert_response :success
    put "/source/home:tom:temporary:link/_meta",
        '<project name="home:tom:temporary:link"> <title/> <description/> 
           <link project="home:tom:temporary" />
           <repository name="me" />
         </project>'
    assert_response :success

    # everything works even when the project is not owner by me?
    login_adrian
    # upload sources in right order
    ["defaults-archsets.include", "defaults-conditionals.include", "defaults-repositories.include", "obs.group", "obs-release.spec", "simple.product"].each do |file|
      raw_put "/source/home:tom:temporary/_product/#{file}",
              File.open("#{Rails.root}/test/fixtures/backend/source/simple_product/#{file}").read()
      assert_response :success
    end

    # product views in a project
    get "/source/home:tom:temporary?view=productlist"
    assert_response :success
    assert_xml_tag :tag => "product", 
                   :attributes => { :name => "simple", :cpe => "cpe:/o:obs_fuzzies:simple:13.1", :originproject => "home:tom:temporary" }
    get "/source/home:tom:temporary?view=productlist&expand=1"
    assert_response :success
    assert_xml_tag :tag => "product", 
                   :attributes => { :name => "simple", :cpe => "cpe:/o:obs_fuzzies:simple:13.1", :originproject => "home:tom:temporary" }

    # product views via project links
    get "/source/home:tom:temporary:link?view=productlist"
    assert_response :success
    assert_no_xml_tag :tag => "product"
    get "/source/home:tom:temporary:link?view=productlist&expand=1"
    assert_response :success
    assert_xml_tag :tag => "product", 
                   :attributes => { :name => "simple", :cpe => "cpe:/o:obs_fuzzies:simple:13.1", :originproject => "home:tom:temporary" }

    # product views in a package
    get "/source/home:tom:temporary/_product?view=issues"
    assert_response :success
    assert_xml_tag :tag => "kind", :content => "product"
    get "/source/home:tom:temporary/_product?view=products"
    assert_response :success
    assert_xml_tag :parent => { :tag => "product", :attributes => { :id => 'simple' } },
                   :tag => "name", :content => "simple"
    get "/source/home:tom:temporary/_product?view=products&product=simple"
    assert_response :success
    assert_xml_tag :tag => "name", :content => "simple"
    get "/source/home:tom:temporary/_product?view=products&product=DOES_NOT_EXIST"
    assert_response :success
    assert_no_xml_tag :tag => "name", :content => "simple"

    product = Package.find_by_project_and_name("home:tom:temporary","_product").products.first
    assert_equal "simple", product.name
    assert_equal "cpe:/o:obs_fuzzies:simple:13.1", product.cpe
    assert_equal product.product_update_repositories.first.repository.project.name, "BaseDistro2.0:LinkedUpdateProject"
    assert_equal product.product_update_repositories.first.repository.name, "BaseDistro2LinkedUpdateProject_repo"

    get "/source/home:tom:temporary/_product:simple-release/simple-release.spec"
    assert_response :success
    get "/source/home:tom:temporary/_product:simple-cd-cd-i586_x86_64/simple-cd-cd-i586_x86_64.kiwi"
    assert_response :success
    assert_xml_tag :tag => "source", :attributes => { :path => "obs://home:Iggy/10.2" },
                   :parent => { :tag => "instrepo", :attributes => { :name => "repository_1", :priority => "1", :local => "true" } }
    assert_xml_tag :tag => "repopackage", :attributes => { :name => "skelcd-obs", :medium => "0", :removearch => "src,nosrc", :onlyarch => "i586,x86_64" },
                   :parent => { :tag => "metadata" }
    assert_xml_tag :tag => "repopackage", :attributes => { :name => "patterns-obs", :medium => "0", :removearch => "src,nosrc", :onlyarch => "i586,x86_64" },
                   :parent => { :tag => "metadata" }
    get "/source/home:tom:temporary/_product:simple-cd-cd-i586_x86_64/simple-cd-cd-i586_x86_64.kwd"
    assert_response :success
    assert_match(/^obs-server: \+Kwd:\\nsupport_l3\\n-Kwd:/, @response.body)

    # invalid uploads 
    raw_put "/source/home:tom:temporary/_product/obs.group",
      File.open("#{Rails.root}/test/fixtures/backend/source/simple_product/INVALID_obs.group").read()
    assert_response 400
    assert_xml_tag :tag => "status", :attributes => { :code => '400', :origin => 'backend' }
    assert_match(/Illegal support key ILLEGAL for obs-server/, @response.body)

    login_tom
    delete "/source/home:tom:temporary:link"
    assert_response :success
    delete "/source/home:tom:temporary"
    assert_response :success
  end

  def test_sle11_product_file
    login_tom
    put "/source/home:tom:temporary/_meta",
        '<project name="home:tom:temporary"> <title/> <description/> 
           <repository name="me" />
         </project>'
    assert_response :success
    put "/source/home:tom:temporary/_product/_meta",
        '<package project="home:tom:temporary" name="_product"> <title/> <description/> 
            <person userid="adrian" role="maintainer" />
         </package>'
    assert_response :success
    put "/source/home:tom:temporary:link/_meta",
        '<project name="home:tom:temporary:link"> <title/> <description/> 
           <link project="home:tom:temporary" />
           <repository name="me" />
         </project>'
    assert_response :success

    # everything works even when the project is not owner by me?
    login_adrian
    # upload sources in right order
    ["defaults-archsets.include", "defaults-conditionals.include", "defaults-repositories.include", "obs.group", "obs-release.spec", "SUSE_SLES.product"].each do |file|
      raw_put "/source/home:tom:temporary/_product/#{file}",
              File.open("#{Rails.root}/test/fixtures/backend/source/sle11_product/#{file}").read()
      assert_response :success
    end

    # product views in a project
    get "/source/home:tom:temporary?view=productlist"
    assert_response :success
    assert_xml_tag :tag => "product", 
                   :attributes => { :name => "SUSE_SLES", :cpe => "cpe:/a:suse:suse_sles:11.2", :originproject => "home:tom:temporary" }
    get "/source/home:tom:temporary?view=productlist&expand=1"
    assert_response :success
    assert_xml_tag :tag => "product", 
                   :attributes => { :name => "SUSE_SLES", :cpe => "cpe:/a:suse:suse_sles:11.2", :originproject => "home:tom:temporary" }

    # product views via project links
    get "/source/home:tom:temporary:link?view=productlist"
    assert_response :success
    assert_no_xml_tag :tag => "product"
    get "/source/home:tom:temporary:link?view=productlist&expand=1"
    assert_response :success
    assert_xml_tag :tag => "product", 
                   :attributes => { :name => "SUSE_SLES", :cpe => "cpe:/a:suse:suse_sles:11.2", :originproject => "home:tom:temporary" }

    # product views in a package
    get "/source/home:tom:temporary/_product?view=issues"
    assert_response :success
    assert_xml_tag :tag => "kind", :content => "product"
    get "/source/home:tom:temporary/_product?view=products"
    assert_response :success
    assert_xml_tag :parent => { :tag => "product", :attributes => { :id => 'simple' } },
                   :tag => "name", :content => "SUSE_SLES"
    get "/source/home:tom:temporary/_product?view=products&product=SUSE_SLES"
    assert_response :success
    assert_xml_tag :tag => "name", :content => "SUSE_SLES"
    get "/source/home:tom:temporary/_product?view=products&product=DOES_NOT_EXIST"
    assert_response :success
    assert_no_xml_tag :tag => "name"

    product = Package.find_by_project_and_name("home:tom:temporary","_product").products.first
    assert_equal "SUSE_SLES", product.name
    assert_equal "cpe:/a:suse:suse_sles:11.2", product.cpe
    assert_equal product.product_update_repositories.first.repository.project.name, "BaseDistro2.0:LinkedUpdateProject"
    assert_equal product.product_update_repositories.first.repository.name, "BaseDistro2LinkedUpdateProject_repo"

    get "/source/home:tom:temporary/_product:SUSE_SLES-SP3-migration/SUSE_SLES-SP3-migration.spec"
    assert_response :success
    get "/source/home:tom:temporary/_product:SUSE_SLES-release/SUSE_SLES-release.spec"
    assert_response :success
    get "/source/home:tom:temporary/_product:sle-obs-cd-cd-i586_x86_64/sle-obs-cd-cd-i586_x86_64.kiwi"
    assert_response :success
    assert_xml_tag :tag => "source", :attributes => { :path => "obs://home:Iggy/10.2" },
                   :parent => { :tag => "instrepo", :attributes => { :name => "repository_1", :priority => "1", :local => "true" } }
    assert_xml_tag :tag => "repopackage", :attributes => { :name => "skelcd-obs", :medium => "0", :removearch => "src,nosrc", :onlyarch => "i586,x86_64" },
                   :parent => { :tag => "metadata" }
    assert_xml_tag :tag => "repopackage", :attributes => { :name => "patterns-obs", :medium => "0", :removearch => "src,nosrc", :onlyarch => "i586,x86_64" },
                   :parent => { :tag => "metadata" }
    get "/source/home:tom:temporary/_product:sle-obs-cd-cd-i586_x86_64/sle-obs-cd-cd-i586_x86_64.kwd"
    assert_response :success
    assert_match(/^obs-server: \+Kwd:\\nsupport_l3\\n-Kwd:/, @response.body)

    login_tom
    delete "/source/home:tom:temporary:link"
    assert_response :success
    delete "/source/home:tom:temporary"
    assert_response :success
  end

end
