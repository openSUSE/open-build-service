# encoding: UTF-8
require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"
require 'tag_controller'

class TagControllerTest < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    @controller = TagController.new

    # wrapper for testing private functions
    def @controller.private_s_to_tag(tag)
      s_to_tag(tag)
    end

    def @controller.private_taglistXML_to_tags(taglistXML)
      taglistXML_to_tags(taglistXML)
    end

    def @controller.private_create_relationship(object, tagCreator, tag)
      create_relationship(object, tagCreator, tag)
    end

    def @controller.private_save_tags(object, tagCreator, tags)
      save_tags(object, tagCreator, tags)
    end

    def @controller.private_taglistXML_to_tags(taglistXML)
      taglistXML_to_tags(taglistXML)
    end

    reset_auth
  end

  def test_s_to_tag
    t = Tag.find_by_name("TagX")
    assert_nil t, "Precondition check failed, TagX already exists"

    # create a new tag
    t = @controller.private_s_to_tag("TagX")
    assert_kind_of Tag, t

    # find an existing tag
    t = @controller.private_s_to_tag("TagA")
    assert_kind_of Tag, t

    # expected exceptions
    assert_raise RuntimeError do
      @controller.private_s_to_tag("IamNotAllowed")
    end

    assert_raise RuntimeError do
      @controller.private_s_to_tag("NotAllowedSymbol:?")
    end
  end

  def test_create_relationship_rollback
    u = User.find_by_login("Iggy")
    assert_kind_of User, u

    p = Project.find_by_name("home:Iggy")
    assert_kind_of Project, p

    t = Tag.find_by_name("TagA")
    assert_kind_of Tag, t
    # an exception should be thrown, because the record already exists
    assert_raise ActiveRecord::RecordNotUnique do
      @controller.private_create_relationship(p, u, t)
    end
  end

  def test_create_relationship
    u = User.find_by_login("Iggy")
    assert_kind_of User, u

    initial_user_tags = u.tags.to_a.clone

    p = Project.find_by_name("home:Iggy")
    assert_kind_of Project, p

    # Precondition check: Tag "TagX" should not exist.
    t = Tag.find_by_name("TagX")
    assert_nil t, "Precondition check failed, TagX already exists"

    # create a tag for testing
    t = Tag.new
    t.name = "TagX"
    t.save

    # get this tag from the data base
    t = Tag.find_by_name("TagX")
    assert_kind_of Tag, t

    # create the relationship and store it in the join table
    @controller.private_create_relationship(p, u, t)

    # reload the user, seems to be necessary
    u = User.find_by_login("Iggy")
    assert_kind_of User, u

    # testing the relationship.
    assert_equal "TagX", (u.tags.to_a - initial_user_tags)[0].name
  end

  def test_save_tags
    u = User.find_by_login("Iggy")
    assert_kind_of User, u

    p = Project.find_by_name("home:Iggy")
    assert_kind_of Project, p

    # Precondition check: Tag "TagX" should not exist.
    t = Tag.find_by_name("TagX")
    assert_nil t, "Precondition check failed, TagX already exists"

    # Precondition check: Tag "TagY" should not exist.
    t = Tag.find_by_name("TagY")
    assert_nil t, "Precondition check failed, TagY already exists"

    # create a tag for testing
    tx = Tag.new
    tx.name = "TagX"
    tx.save

    # get this tag from the data base
    tx = Tag.find_by_name("TagX")
    assert_kind_of Tag, tx

    # create another tag for testing
    ty = Tag.new
    ty.name = "TagY"
    ty.save

    # get this tag from the data base
    ty = Tag.find_by_name("TagY")
    assert_kind_of Tag, ty

    t = Array.new
    t << tx
    t << ty

    @controller.private_save_tags(p, u, t)

    assert_kind_of Tag, u.tags.find_by_name("TagX")
    assert_kind_of Tag, u.tags.find_by_name("TagY")
  end

  def test_taglist_xml_to_tags
    u = User.find_by_login("Iggy")
    assert_kind_of User, u

    p = Project.find_by_name("home:Iggy")
    assert_kind_of Project, p

    # tags to create
    tags = %w(TagX TagY TagZ IamNotAllowed)

    # Precondition check: Tag "TagX" should not exist.
    tags.each do |tag|
      t = Tag.find_by_name(tag)
      assert_nil t, "Precondition check failed, #{tag} already exists"
    end

    # and a existing tag
    tags << "TagA"

    # prepare the xml document for testing
    xml = REXML::Document.new
    xml << REXML::XMLDecl.new(1.0, "UTF-8", "no")
    xml.add_element( REXML::Element.new("tags") )
    xml.root.add_attribute REXML::Attribute.new("project", "home:Iggy")
    tags.each do |tag|
      element = REXML::Element.new( 'tag' )
      element.add_attribute REXML::Attribute.new('name', tag)
      xml.root.add_element(element)
    end

    # testing
    tags, unsaved_tags = @controller.private_taglistXML_to_tags(xml.to_s)

    assert_kind_of Array, tags
    assert_kind_of Array, unsaved_tags

    # 4 tags saved and initialized
    assert_equal 4, tags.size
    # 1 tag rejected
    assert_equal "IamNotAllowed", unsaved_tags[0]
  end

  def test_get_project_tags
    login_Iggy

    # request tags for an unknown project
    get url_for(controller: :tag, action: :project_tags, project: "IamAnAlien")
    assert_response 404

    # request tags for an existing project
    get url_for(controller: :tag, action: :project_tags, project: "home:Iggy" )
    assert_response :success

    # checking response-data
    assert_xml_tag tag: "tags",
                   attributes: {
                     project: "home:Iggy",
                     user:    ""
                   },
                  child: { tag: "tag" }
    assert_xml_tag tag: "tags",
                   children: {
                     count: 4,
                     only:  { tag: "tag" }
                   }
    # checking each tag
    assert_xml_tag tag: "tags",
                   child: {
                     tag:        "tag",
                     attributes: { name: "TagA" }
                   }
    assert_xml_tag tag: "tags",
                   child: {
                     tag:        "tag",
                     attributes: { name: "TagB" }
                   }
    assert_xml_tag tag: "tags",
                   child: {
                     tag:        "tag",
                     attributes: { name: "TagC" }
                   }
    assert_xml_tag tag: "tags",
                   child: {
                     tag:        "tag",
                     attributes: {name: "TagF"}
                   }
  end

  def test_get_package_tags
    login_Iggy

    # request tags for an unknown project
    get url_for(controller: :tag, action: :package_tags, project: "IamAnAlien", package: "MeToo")
    assert_response 404

    # request tags for an existing project
    get url_for(controller: :tag, action: :package_tags, project: "home:Iggy", package: "TestPack" )
    assert_response :success

    # checking response-data
    assert_xml_tag tag: "tags",
                   attributes: {
                     project: "home:Iggy",
                     package: "TestPack",
                     user:    ""
                   },
                   child: { tag: "tag" }
    assert_xml_tag tag: "tags",
                   children: { count: 4, only: { tag: "tag" } }
    # checking each tag
    assert_xml_tag tag: "tags",
                    child: {tag: "tag", attributes: {name: "TagB"} }
    assert_xml_tag tag: "tags",
                    child: {tag: "tag", attributes: {name: "TagC"} }
    assert_xml_tag tag: "tags",
                    child: {tag: "tag", attributes: {name: "TagD"} }
    assert_xml_tag tag: "tags",
                    child: {tag: "tag", attributes: {name: "TagE"} }
  end

  #  def test_put_project_tags
  #    login_Iggy
  #
  #    #tags = ["TagX", "TagY", "TagZ", "IamNotAllowed", "TagA"]
  #    tags = ["TagX", "TagY", "TagZ", "TagA"]
  #
  #    #prepare the xml document for testing
  #    xml = REXML::Document.new
  #    xml << REXML::XMLDecl.new(1.0, "UTF-8", "no")
  #      xml.add_element( REXML::Element.new("tags") )
  #      xml.root.add_attribute REXML::Attribute.new("project", "home:Iggy")
  #      tags.each do |tag|
  #        element = REXML::Element.new( 'tag' )
  #        element.add_attribute REXML::Attribute.new('name', tag)
  #        xml.root.add_element(element)
  #    end
  #
  #
  #    #put tags for an existing project
  #    put :project_tags, :project => "home:Iggy" , xml.to_s
  #    assert_response :success
  #
  #
  #  end
  #
  #

  # This test is for testing the function get_tags_by_user_and_project
  # in the case of controller-internal usage of this function.
  def test_get_tags_by_user_and_project_internal_use
    def @controller.params
      {user: "Iggy", project: "home:Iggy"}
    end

    tags = @controller.get_tags_by_user_and_project( false )
    assert_equal 4, tags.size
    assert_equal 'TagA', tags[0].name
    assert_equal 'TagB', tags[1].name
    assert_equal 'TagC', tags[2].name
    assert_equal 'TagF', tags[3].name
  end

  # This test is for testing the function get_tags_by_user_and_package
  # in the case of controller-internal usage of this function.
  def test_get_tags_by_user_and_package_internal_use
    def @controller.params
      {user: "Iggy", project: "home:Iggy",
      package: "TestPack"}
    end

    tags = @controller.get_tags_by_user_and_package( false )
    assert_equal 4, tags.size
    assert_equal 'TagB', tags[0].name
    assert_equal 'TagC', tags[1].name
    assert_equal 'TagD', tags[2].name
    assert_equal 'TagE', tags[3].name
  end

  def test_get_tags_by_user_and_project
    login_Iggy

    # request tags for an unknown project
    get url_for(controller: :tag, action: :get_tags_by_user_and_project, project: "IamAnAlien",
    user: "Iggy" )
    assert_response 404

    # request tags for an unknown user
    get url_for(controller: :tag, action: :get_tags_by_user_and_project, project: "home:Iggy",
    user: "Alien" )
    assert_response 404

    # request tags for an existing project
    get url_for(controller: :tag, action: :get_tags_by_user_and_project, project: "home:Iggy",
    user: "Iggy" )
    assert_response :success

    # checking response-data
    assert_xml_tag tag: "tags",
                   attributes: {
                     project: "home:Iggy",
                     user:    "Iggy"
                   },
                   child: { tag: "tag" }
    assert_xml_tag tag: "tags",
                   children: { count: 4, only: { tag: "tag" } }
    # checking each tag
    assert_xml_tag tag: "tags",
                   child: {tag: "tag", attributes: {name: "TagA"} }
    assert_xml_tag tag: "tags",
                   child: {tag: "tag", attributes: {name: "TagB"} }
    assert_xml_tag tag: "tags",
                   child: {tag: "tag", attributes: {name: "TagC"} }
    assert_xml_tag tag: "tags",
                   child: {tag: "tag", attributes: {name: "TagF"} }

    # request tags for another user than the logged on user
    get url_for(controller: :tag, action: :get_tags_by_user_and_project, project: "home:Iggy",
    user: "fred" )
    assert_response :success

    # checking response-data
    assert_xml_tag tag: "tags",
    attributes: {
      project: "home:Iggy",
      user:    "fred"
    },
    child: { tag: "tag" }
    assert_xml_tag tag: "tags",
    children: { count: 2, only: { tag: "tag" } }

    # checking each tag
    assert_xml_tag tag: "tags",
    child: {tag: "tag", attributes: {name: "TagB"} }
    assert_xml_tag tag: "tags",
    child: {tag: "tag", attributes: {name: "TagC"} }
  end

  def test_get_tags_by_user_and_package
    login_Iggy

    # request tags for an unknown project
    get url_for(controller: :tag, action: :get_tags_by_user_and_package, project: "IamAnAlien",
    package: "MeToo",
    user: "Iggy" )
    assert_response 404

    # request tags for an unknown package
    get url_for(controller: :tag, action: :get_tags_by_user_and_package, project: "home:Iggy",
    package: "AlienPackage",
    user: "Iggy" )
    assert_response 404

    # request tags for an unknown user
    get url_for(controller: :tag, action: :get_tags_by_user_and_package, project: "home:Iggy",
    package: "TestPack",
    user: "Alien" )
    assert_response 404

    # request tags for an existing package
    get url_for(controller: :tag, action: :get_tags_by_user_and_package, project: "home:Iggy", package: "TestPack", user: "Iggy" )
    assert_response :success

    # checking response-data
    assert_xml_tag tag: "tags",
    attributes: {
      project: "home:Iggy",
      package: "TestPack",
      user:    "Iggy"
    },
    child: { tag: "tag" }
    assert_xml_tag tag: "tags",
    children: { count: 4, only: { tag: "tag" } }
    # checking each tag
    assert_xml_tag tag: "tags",
    child: {tag: "tag", attributes: {name: "TagB"} }
    assert_xml_tag tag: "tags",
    child: {tag: "tag", attributes: {name: "TagC"} }
    assert_xml_tag tag: "tags",
    child: {tag: "tag", attributes: {name: "TagD"} }
    assert_xml_tag tag: "tags",
    child: {tag: "tag", attributes: {name: "TagE"} }

    # request tags for another user than the logged on user
    get url_for(controller: :tag, action: :get_tags_by_user_and_package, project: "home:Iggy",
    package: "TestPack",
    user: "fred" )
    assert_response :success

    # checking response-data
    assert_xml_tag tag: "tags",
    attributes: {
      project: "home:Iggy",
      user:    "fred"
    },
    child: { tag: "tag" }
    assert_xml_tag tag: "tags",
    children: { count: 1, only: { tag: "tag" } }

    # checking each tag
    assert_xml_tag tag: "tags",
    child: {tag: "tag", attributes: {name: "TagB"} }
  end

  # This test gets all projects with tags by the logged on user Iggy
  def test_get_tagged_projects_by_user_1
    login_Iggy

    # request tags for an unknown user
    get url_for(controller: :tag, action: :get_tagged_projects_by_user, user: "IamAnAlienToo" )
    assert_response 404

    get url_for(controller: :tag, action: :get_tagged_projects_by_user, user: "Iggy")
    assert_response :success

    # checking response-data
    assert_xml_tag tag: "collection",
    attributes: { user: "Iggy"
    },
    child: { tag: "project" }
    assert_xml_tag tag: "collection",
    children: { count: 3, only: { tag: "project" } }
    # checking one of the three projects and each tag
    # TODO: check the others too
    assert_xml_tag tag: "collection",
    child: { tag:        "project",
             attributes: {name: "home:Iggy"},
             child:      {tag: "tag", attributes: {name: "TagA"} }
    }
    assert_xml_tag tag: "collection",
    child: { tag:   "project",
             child: {tag: "tag", attributes: {name: "TagB"} }
    }
    assert_xml_tag tag: "collection",
    child: { tag:   "project",
             child: {tag: "tag", attributes: {name: "TagF"} }
    }
  end

  # This test gets all projects with tags by another user than the the logged on
  # user Iggy
  def test_get_tagged_projects_by_user_2
    login_Iggy

    get url_for(controller: :tag, action: :get_tagged_projects_by_user, user: "fred")
    assert_response :success

    # checking response-data
    assert_xml_tag tag: "collection",
    attributes: { user: "fred"
    },
    child: { tag: "project" }
    assert_xml_tag tag: "collection",
    children: { count: 1, only: { tag: "project" } }
    # checking the project and each tag
    assert_xml_tag tag: "collection",
    child: { tag:        "project",
             attributes: {name: "home:Iggy"},
             child:      {tag: "tag", attributes: {name: "TagB"} }
    }
    assert_xml_tag tag: "collection",
    child: { tag:   "project",
             child: {tag: "tag", attributes: {name: "TagC"} }
    }
  end

  # This test gets all packages with tags by the logged on user Iggy
  def test_get_tagged_packages_by_user_1
    login_Iggy

    # request tags for an unknown user
    get url_for(controller: :tag, action: :get_tagged_packages_by_user, user: "IamAnAlienToo" )
    assert_response 404

    get url_for(controller: :tag, action: :get_tagged_packages_by_user, user: "Iggy")
    assert_response :success

    # checking response-data
    assert_xml_tag tag: "collection",
    attributes: { user: "Iggy"
    },
    child: { tag: "package" }
    assert_xml_tag tag: "collection",
    children: { count: 1, only: { tag: "package" } }
    # checking the project and each tag
    assert_xml_tag tag: "collection",
    child: { tag:        "package",
             attributes: {
                  name:    "TestPack",
                  project: "home:Iggy"
                },
             child:      {tag: "tag", attributes: {name: "TagB"} }
    }
    assert_xml_tag tag: "collection",
    child: { tag:        "package",
             attributes: {
                  name:    "TestPack",
                  project: "home:Iggy"
                },
             child:      {tag: "tag", attributes: {name: "TagC"} }
    }
    assert_xml_tag tag: "collection",
    child: { tag:        "package",
             attributes: {
                  name:    "TestPack",
                  project: "home:Iggy"
                },
             child:      {tag: "tag", attributes: {name: "TagD"} }
    }
    assert_xml_tag tag: "collection",
    child: { tag:        "package",
             attributes: {
                  name:    "TestPack",
                  project: "home:Iggy"
                },
             child:      {tag: "tag", attributes: {name: "TagE"} }
    }
  end

  # This test gets all packages with tags by another user than the the logged on
  # user Iggy
  def test_get_tagged_packages_by_user_2
    login_Iggy

    get url_for(controller: :tag, action: :get_tagged_packages_by_user, user: "fred")
    assert_response :success

    # checking response-data
    assert_xml_tag tag: "collection",
    attributes: { user: "fred"
    },
    child: { tag: "package" }
    assert_xml_tag tag: "collection",
    children: { count: 1, only: { tag: "package" } }
    # checking the project and each tag
    assert_xml_tag tag: "collection",
    child: { tag:        "package",
             attributes: {
                  name:    "TestPack",
                  project: "home:Iggy"
                },
             child:      {tag: "tag", attributes: {name: "TagB"} }
    }
  end

  def test_get_projects_by_tag
    login_Iggy

    # request tags for an unknown tag
    get url_for(controller: :tag, action: :get_projects_by_tag, tag: "AlienTag")
    assert_response 404

    get url_for(controller: :tag, action: :get_projects_by_tag, tag: "TagA")
    assert_response :success

    # checking response-data
    assert_xml_tag tag: "collection",
    attributes: {
      tag: "TagA"
    },
    child: { tag: "project" }
    assert_xml_tag tag: "collection",
    children: { count: 3, only: { tag: "project" } }
    # checking one of the three projects and each tag
    # TODO: check the others too
    assert_xml_tag tag: "collection",
    child: { tag:        "project",
             attributes: { name: "home:Iggy" },
             child:      {tag: "tag", attributes: {name: "TagA"} }
    }
    assert_xml_tag tag: "collection",
    child: { tag:        "project",
             attributes: { name: "home:Iggy" },
             child:      {tag: "tag", attributes: {name: "TagB"} }
    }
    assert_xml_tag tag: "collection",
    child: { tag:        "project",
             attributes: { name: "home:Iggy" },
             child:      {tag: "tag", attributes: {name: "TagC"} }
    }
    assert_xml_tag tag: "collection",
    child: { tag:        "project",
             attributes: { name: "home:Iggy" },
             child:      { tag: "tag", attributes: {name: "TagF"} }
    }
  end

  # This test gets all projects tagged by the tree tags TagA, TagB, TagC
  # Result: only one project (home:Iggy)
  def test_get_projects_by_three_tags
    login_Iggy

    get url_for(controller: :tag, action: :get_projects_by_tag, tag: "TagA::TagB::TagC")
    assert_response :success

    # checking response-data
    assert_xml_tag tag: "collection",
    attributes: { tag: "TagA::TagB::TagC" },
    child: { tag: "project" }
    assert_xml_tag tag: "collection",
    children: { count: 1, only: { tag: "project" } }
    # checking the project and each tag
    assert_xml_tag tag: "collection",
    child: { tag:        "project",
             attributes: {name: "home:Iggy"},
             child:      {tag: "tag", attributes: {name: "TagA"} }
    }
    assert_xml_tag tag: "collection",
    child: { tag:        "project",
             attributes: { name: "home:Iggy" },
             child:      {tag: "tag", attributes: {name: "TagB"} }
    }
    assert_xml_tag tag: "collection",
    child: { tag:        "project",
             attributes: {name: "home:Iggy" },
             child:      {tag: "tag", attributes: {name: "TagC"} }
    }
    assert_xml_tag tag: "collection",
    child: { tag:        "project",
             attributes: {name: "home:Iggy" },
             child:      {tag: "tag", attributes: {name: "TagF"} }
    }
  end

  # This test gets all projects tagged by the tree tags TagA, TagB, TagC,
  # but tags are in different order
  # Result: only one project (home:Iggy)
  def test_get_projects_by_three_tags_different_order
    login_Iggy

    get url_for(controller: :tag, action: :get_projects_by_tag, tag: "TagC::TagA::TagB")
    assert_response :success

    # checking response-data
    assert_xml_tag tag: "collection",
    attributes: { tag: "TagC::TagA::TagB" },
    child: { tag: "project" }
    assert_xml_tag tag: "collection",
    children: { count: 1, only: { tag: "project" } }
    # checking the project and each tag
    assert_xml_tag tag: "collection",
    child: { tag:        "project",
             attributes: {name: "home:Iggy" },
             child:      {tag: "tag", attributes: {name: "TagA"} }
    }
    assert_xml_tag tag: "collection",
    child: { tag:        "project",
             attributes: {name: "home:Iggy" },
             child:      {tag: "tag", attributes: {name: "TagB"} }
    }
    assert_xml_tag tag: "collection",
    child: { tag:        "project",
             attributes: {name: "home:Iggy" },
             child:      {tag: "tag", attributes: {name: "TagC"} }
    }
    assert_xml_tag tag: "collection",
    child: { tag:        "project",
             attributes: {name: "home:Iggy" },
             child:      {tag: "tag", attributes: {name: "TagF"} }
    }
  end

  # This test gets all projects tagged by the two tags TagA and TagC
  # Result: two projects (home:Iggy, kde)
  def test_get_projects_by_two_tags
    login_Iggy

    get url_for(controller: :tag, action: :get_projects_by_tag, tag: "TagA::TagC")
    assert_response :success

    # checking response-data
    assert_xml_tag tag: "collection",
    attributes: { tag: "TagA::TagC" },
    child: { tag: "project" }
    assert_xml_tag tag: "collection",
    children: { count: 2, only: { tag: "project" } }

    # checking the project home:Iggy and each tag
    assert_xml_tag tag: "collection",
    child: { tag:        "project",
             attributes: {name: "home:Iggy" },
             child:      {tag: "tag", attributes: {name: "TagA"} }
    }
    assert_xml_tag tag: "collection",
    child: { tag:        "project",
             attributes: {name: "home:Iggy"},
             child:      {tag: "tag", attributes: {name: "TagB"} }
    }
    assert_xml_tag tag: "collection",
    child: { tag:        "project",
             attributes: {name: "home:Iggy" },
             child:      {tag: "tag", attributes: {name: "TagC"} }
    }
    assert_xml_tag tag: "collection",
    child: { tag:        "project",
             attributes: {name: "home:Iggy" },
             child:      {tag: "tag", attributes: {name: "TagF"} }
    }

    # checking the second project home:Iggy and each tag
    assert_xml_tag tag: "collection",
    child: { tag:        "project",
             attributes: {name: "kde" },
             child:      {tag: "tag", attributes: {name: "TagA"} }
    }
    assert_xml_tag tag: "collection",
    child: { tag:        "project",
             attributes: {name: "kde" },
             child:      {tag: "tag", attributes: {name: "TagC"} }
    }
  end

  def test_get_packages_by_tag
    login_Iggy

    # request tags for an unknown tag
    get url_for(controller: :tag, action: :get_packages_by_tag, tag: "AlienTag")
    assert_response 404

    get url_for(controller: :tag, action: :get_packages_by_tag, tag: "TagB")
    assert_response :success

    # checking response-data
    assert_xml_tag tag: "collection",
    attributes: { tag: "TagB"
    },
    child: { tag: "package" }
    assert_xml_tag tag: "collection",
    children: { count: 1, only: { tag: "package" } }
    # checking the package and each tag
    assert_xml_tag tag: "collection",
    child: { tag:        "package",
             attributes: {
                  name:    "TestPack",
                  project: "home:Iggy"
                },
             child:      {tag: "tag", attributes: {name: "TagB"} }
    }
    assert_xml_tag tag: "collection",
    child: { tag:        "package",
             attributes: {
                  name:    "TestPack",
                  project: "home:Iggy"
                },
             child:      {tag: "tag", attributes: {name: "TagC"} }
    }
    assert_xml_tag tag: "collection",
    child: { tag:        "package",
             attributes: {
                  name:    "TestPack",
                  project: "home:Iggy"
                },
             child:      {tag: "tag", attributes: {name: "TagD"} }
    }
    assert_xml_tag tag: "collection",
    child: { tag:        "package",
             attributes: {
                  name:    "TestPack",
                  project: "home:Iggy"
                },
             child:      {tag: "tag", attributes: {name: "TagE"} }
    }
  end

  # This test gets all packages tagged by the two tags TagA and TagC
  # Result: only one package (TestPack)
  def test_get_packages_by_two_tags
    login_Iggy

    get url_for(controller: :tag, action: :get_packages_by_tag, tag: "TagB::TagC")
    assert_response :success

    # checking response-data
    assert_xml_tag tag: "collection",
    attributes: { tag: "TagB::TagC"
    },
    child: { tag: "package" }
    assert_xml_tag tag: "collection",
    children: { count: 1, only: { tag: "package" } }
    # checking the package and each tag
    assert_xml_tag tag: "collection",
    child: { tag:        "package",
             attributes: {
                  name:    "TestPack",
                  project: "home:Iggy"
                },
             child:      {tag: "tag", attributes: {name: "TagB"} }
    }
    assert_xml_tag tag: "collection",
    child: { tag:        "package",
             attributes: {
                  name:    "TestPack",
                  project: "home:Iggy"
                },
             child:      {tag: "tag", attributes: {name: "TagC"} }
    }
    assert_xml_tag tag: "collection",
    child: { tag:        "package",
             attributes: {
                  name:    "TestPack",
                  project: "home:Iggy"
                },
             child:      {tag: "tag", attributes: {name: "TagD"} }
    }
    assert_xml_tag tag: "collection",
    child: { tag:        "package",
             attributes: {
                  name:    "TestPack",
                  project: "home:Iggy"
                },
             child:      {tag: "tag", attributes: {name: "TagE"} }
    }
  end

  # This test gets all packages tagged by the two tags TagA and TagB
  # Result: no package can be found
  def test_get_packages_by_two_tags_nothing_found
    login_Iggy

    get url_for(controller: :tag, action: :get_packages_by_tag, tag: "TagA::TagB")
    assert_response :success

    # checking response-data
    assert_xml_tag tag: "collection",
    attributes: { tag: "TagA::TagB"
    },
    children: { count: 0 }
  end

  def test_get_objects_by_tag
    login_Iggy

    # request tags for an unknown tag
    get url_for(controller: :tag, action: :get_objects_by_tag, tag: "AlienTag")
    assert_response 404

    get url_for(controller: :tag, action: :get_objects_by_tag, tag: "TagB")
    assert_response :success

    # checking response-data
    assert_xml_tag tag:        "collection",
                   attributes: { tag: "TagB" },
                   child:      { tag: "project" }

    assert_xml_tag tag:        "collection",
                   attributes: { tag: "TagB" },
                   child:      { tag: "package" }

    # checking the project and each tag
    assert_xml_tag tag:   "collection",
                   child: {
                     tag:        "project",
                     attributes: {
                       name: "home:Iggy"
                     },
                     child:      {
                       tag:        "tag",
                       attributes: {
                         name: "TagA"
                       }
                     }
                   }

    assert_xml_tag tag:   "collection",
                   child: {
                     tag:        "project",
                     attributes: {
                       name: "home:Iggy"
                     },
                     child:      {
                       tag:        "tag",
                       attributes: { name: "TagB"} }
                   }

    assert_xml_tag tag:   "collection",
                   child: {
                   tag:        "project",
                   attributes: {
                     name: "home:Iggy"
                   },
                   child:      {
                     tag:        "tag",
                     attributes: { name: "TagC" } }
                   }

    assert_xml_tag tag:   "collection",
                   child: {
                     tag:        "project",
                     attributes: {
                       name: "home:Iggy"
                     },
                     child:      {
                       tag:        "tag",
                       attributes: { name: "TagF" }
                     }
                   }

    # checking the package and each tag
    assert_xml_tag tag:   "collection",
                   child: {
                     tag:        "package",
                     attributes: {
                       name:    "TestPack",
                       project: "home:Iggy"
                     },
                     child:      {
                       tag:        "tag",
                       attributes: { name: "TagB" }
                     }
                   }

    assert_xml_tag tag:   "collection",
                   child: {
                     tag:        "package",
                     attributes: {
                       name:    "TestPack",
                       project: "home:Iggy"
                     },
                     child:      {
                       tag:        "tag",
                       attributes: { name: "TagC" }
                     }
                   }

    assert_xml_tag tag:   "collection",
                   child: {
                     tag:        "package",
                     attributes: {
                       name:    "TestPack",
                       project: "home:Iggy"
                     },
                     child:      {
                       tag:        "tag",
                       attributes: { name: "TagD" }
                     }
                   }

    assert_xml_tag tag:   "collection",
                   child: {
                     tag:        "package",
                     attributes: {
                       name:    "TestPack",
                       project: "home:Iggy"
                     },
                     child:      {
                       tag:        "tag",
                       attributes: { name: "TagE" }
                     }
                   }
  end

  def test_tags_by_user_and_object_put_for_a_project
    # Precondition check: Get all tags for Iggy and the home:project.
    login_Iggy
    get "/tag/get_tags_by_user_and_project", project: 'home:Iggy',
    user: 'Iggy'
    assert_response :success
    # checking response-data
    assert_xml_tag tag: "tags",
                   attributes: {
                     project: "home:Iggy",
                     user:    "Iggy"
                   },
                   child: { tag: "tag" }
    assert_xml_tag tag: "tags",
                   children: { count: 4, only: { tag: "tag" } }
    # checking each tag
    assert_xml_tag tag: "tags",
                   child: {tag: "tag", attributes: {name: "TagA"} }
    assert_xml_tag tag: "tags",
                   child: {tag: "tag", attributes: {name: "TagB"} }
    assert_xml_tag tag: "tags",
                   child: {tag: "tag", attributes: {name: "TagC"} }
    assert_xml_tag tag: "tags",
                   child: {tag: "tag", attributes: {name: "TagF"} }

    # tags to create
    tags = %w(TagX TagY TagZ TagA)
    # prepare the xml document (request data)
    xml = REXML::Document.new
    xml << REXML::XMLDecl.new(1.0, "UTF-8", "no")
    xml.add_element( REXML::Element.new("tags") )
    xml.root.add_attribute REXML::Attribute.new("project", "home:Iggy")
    tags.each do |tag|
      element = REXML::Element.new( 'tag' )
      element.add_attribute REXML::Attribute.new('name', tag)
      xml.root.add_element(element)
    end

    # add tags
    put url_for(controller: :tag, action: :tags_by_user_and_object, project: 'home:Iggy', user: 'Iggy'), xml.to_s
    assert_response :success

    # Get data again and check that tags where added or removed
    get url_for(controller: :tag, action: :get_tags_by_user_and_project, project: 'home:Iggy',
    user: 'Iggy')
    assert_response :success
    # checking response-data
    assert_xml_tag tag: "tags",
    attributes: {
      project: "home:Iggy",
      user:    "Iggy"
    },
    child: { tag: "tag" }
    assert_xml_tag tag: "tags",
    children: { count: 4, only: { tag: "tag" } }
    # checking each tag
    assert_xml_tag tag: "tags",
    child: { tag: "tag", attributes: { name: "TagX" } }
    assert_xml_tag tag: "tags",
    child: { tag: "tag", attributes: { name: "TagY" } }
    assert_xml_tag tag: "tags",
    child: { tag: "tag", attributes: { name: "TagZ" } }
    assert_xml_tag tag: "tags",
    child: { tag: "tag", attributes: { name: "TagA" } }
  end

  def test_tags_by_user_and_object_put_for_a_package
    # Precondition check: Get all tags for Iggy and a package.
    login_Iggy
    get "/tag/get_tags_by_user_and_package", project: 'home:Iggy',
    package: 'TestPack', user: 'Iggy'
    assert_response :success
    # checking response-data
    assert_xml_tag tag: "tags",
    attributes: {
      project: "home:Iggy",
      package: "TestPack",
      user:    "Iggy"
    },
    child: { tag: "tag" }
    assert_xml_tag tag: "tags",
    children: { count: 4, only: { tag: "tag" } }
    # checking each tag
    assert_xml_tag tag: "tags",
    child: {tag: "tag", attributes: {name: "TagB"} }
    assert_xml_tag tag: "tags",
    child: {tag: "tag", attributes: {name: "TagC"} }
    assert_xml_tag tag: "tags",
    child: {tag: "tag", attributes: {name: "TagD"} }
    assert_xml_tag tag: "tags",
    child: {tag: "tag", attributes: {name: "TagE"} }

    # tags to create
    tags = %w(TagX TagY TagZ TagB)
    # prepare the xml document (request data)
    xml = REXML::Document.new
    xml << REXML::XMLDecl.new(1.0, "UTF-8", "no")
    xml.add_element( REXML::Element.new("tags") )
    xml.root.add_attribute REXML::Attribute.new("project", "home:Iggy")
    tags.each do |tag|
      element = REXML::Element.new( 'tag' )
      element.add_attribute REXML::Attribute.new('name', tag)
      xml.root.add_element(element)
    end

    # add tags
    put url_for(controller: :tag, action: :tags_by_user_and_object, project: 'home:Iggy',
    package: "TestPack",
    user: 'Iggy'), xml.to_s
    assert_response :success

    # Get data again and check that tags where added or removed
    get url_for(controller: :tag, action: :get_tags_by_user_and_package, project: 'home:Iggy',
    package: 'TestPack',
    user: 'Iggy')
    assert_response :success
    # checking response-data
    assert_xml_tag tag: "tags",
    attributes: {
      project: "home:Iggy",
      package: "TestPack",
      user:    "Iggy"
    },
    child: { tag: "tag" }
    assert_xml_tag tag: "tags",
    children: { count: 4, only: { tag: "tag" } }
    # checking each tag
    assert_xml_tag tag: "tags",
    child: {tag: "tag", attributes: {name: "TagX"} }
    assert_xml_tag tag: "tags",
    child: {tag: "tag", attributes: {name: "TagY"} }
    assert_xml_tag tag: "tags",
    child: {tag: "tag", attributes: {name: "TagZ"} }
    assert_xml_tag tag: "tags",
    child: {tag: "tag", attributes: {name: "TagB"} }
  end

  # test for writing tags for another user than the logged in user <- forbidden
  def test_tags_by_user_and_object_put_as_invalid_user
    login_Iggy

    # tags to create
    tags = %w(TagX TagY TagZ TagB)
    # prepare the xml document (request data)
    xml = REXML::Document.new
    xml << REXML::XMLDecl.new(1.0, "UTF-8", "no")
    xml.add_element( REXML::Element.new("tags") )
    xml.root.add_attribute REXML::Attribute.new("project", "home:Iggy")
    tags.each do |tag|
      element = REXML::Element.new( 'tag' )
      element.add_attribute REXML::Attribute.new('name', tag)
      xml.root.add_element(element)
    end

    # put request for an unknown user
    put url_for(controller: :tag, action: :tags_by_user_and_object, project: 'home:Iggy',
      package: "TestPack",
      user: 'Alien'), xml.to_s
    assert_response 404

    # put request for another user than the logged on user.
    put url_for(controller: :tag, action: :tags_by_user_and_object, project: 'home:Iggy',
      package: "TestPack",
      user: 'fred'), xml.to_s
    assert_response 403
  end

  def test_tags_by_user_and_object_put_for_invalid_objects
    login_Iggy

    # put request for an unknown project
    get "/tag/tags_by_user_and_object", project: 'AlienProject', user: 'Iggy'
    assert_response 404

    # put request for an unknown package
    get "/tag/tags_by_user_and_object", project: 'home:Iggy',
      package: "AlienPackage",
      user: 'Iggy'
    assert_response 404
  end
end
