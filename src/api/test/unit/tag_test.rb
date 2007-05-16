require File.dirname(__FILE__) + '/../test_helper'

class TagTest < Test::Unit::TestCase
  fixtures :tags
  fixtures :blacklist_tags

  def test_reject_tag
    t = Tag.new
    t.name = 'IamNotAllowed'
    t.created_at = "2007-03-09 14:57:54"
    assert t.save == false
  end

end
