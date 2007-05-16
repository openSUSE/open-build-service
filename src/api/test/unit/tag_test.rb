require File.dirname(__FILE__) + '/../test_helper'

class TagTest < Test::Unit::TestCase
  fixtures :tags

  def test_reject_tag
    t = Tag.new
    t.name = 'pr0n'
    t.created_at = "2007-03-09 14:57:54"
    assert false
  end


  # Replace this with your real tests.
  def test_truth
    assert true
  end
end
