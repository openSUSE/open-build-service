require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class TagTest < ActiveSupport::TestCase
  fixtures :tags, :blacklist_tags, :taggings, :users

  def test_reject_tag
    t = Tag.new
    t.name = 'IamNotAllowed'
    t.created_at = "2007-03-09 14:57:54"
    assert t.save == false

    # expected error message
    assert_equal "The tag is blacklisted!", t.errors[:name].join(';')

    t = Tag.new
    t.name = 'NotAllowedSymbol_?'
    t.created_at = "2007-03-09 14:57:54"
    assert t.save == false

    # expected error message
    assert_equal "no ? and : allowed!", t.errors[:name].join(';')

    t = Tag.new
    t.name = 'NotAllowedSymbol_:'
    t.created_at = "2007-03-09 14:57:54"
    assert t.save == false

    # expected error message
    assert_equal "no ? and : allowed!", t.errors[:name].join(';')
  end

  def test_count
    # non-user context
    t = Tag.find_by_name("TagA")
    assert_kind_of Tag, t
    assert_equal 3, t.count, "Wrong tag-count for TagA."

    t = Tag.find_by_name("TagB")
    assert_kind_of Tag, t
    assert_equal 4, t.count, "Wrong tag-count for TagB."

    # user-context
    u = User.find_by_login('Iggy')
    assert_kind_of User, u

    opt = {scope: 'user', user: u}

    t = Tag.find_by_name("TagA")
    assert_kind_of Tag, t
    assert_equal 3, t.count(opt), "Wrong user-dependant tag-count for TagA."

    t = Tag.find_by_name("TagB")
    assert_kind_of Tag, t
    assert_equal 2, t.count(opt), "Wrong user-dependant tag-count for TagB."
  end

  def test_count_by_given_tags
    # by-given-tags context
    tags = Array.new

    # prepare the array of tags
    2.times do
      t = Tag.find_by_name("TagA")
      assert_kind_of Tag, t
      tags << t
    end

    3.times do
      t = Tag.find_by_name("TagB")
      assert_kind_of Tag, t
      tags << t
    end

    4.times do
      t = Tag.find_by_name("TagC")
      assert_kind_of Tag, t
      tags << t
    end

    # calculate tag count
    tags.each do |tag|
      tag.count(scope: "by_given_tags", tags: tags)
    end

    tags.uniq!

    # check the results
    assert_equal "TagA", tags[0].name
    assert_equal 2, tags[0].cached_count

    assert_equal "TagB", tags[1].name
    assert_equal 3, tags[1].cached_count

    assert_equal "TagC", tags[2].name
    assert_equal 4, tags[2].cached_count
  end
end
