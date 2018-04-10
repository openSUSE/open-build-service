# frozen_string_literal: true
require_relative '../test_helper'
require 'obsapi/test_sphinx'

class FullTextSearchTest < ActiveSupport::TestCase
  fixtures :all

  def setup
    OBSApi::TestSphinx.ensure
    User.current = nil
  end

  test 'search for basedistro' do
    s = FullTextSearch.new(text: 'basedistro')
    assert_equal 4, s.search.total_entries
  end

  test 'search for kdelibs' do
    s = FullTextSearch.new(text: 'kdelibs')
    # The order is relevant
    assert_equal ['kdelibs', 'kdelibs_DEVEL_package'], s.search.map(&:name)
  end

  test 'using underscore to search for kdelibs_devel' do
    s = FullTextSearch.new(text: 'kdelibs_devel')
    assert_equal 1, s.search.total_entries
  end

  test 'using two words to search for kdelibs_devel' do
    s = FullTextSearch.new(text: 'kdelibs devel')
    assert_equal 1, s.search.total_entries
  end

  test 'searching by issue' do
    # Only by issue
    s = FullTextSearch.new(issue_tracker_name: 'bnc', issue_name: '123456')
    # Order is not relevant
    assert_equal ['BaseDistro', 'patchinfo'], s.search.map(&:name).sort
    # Only projects
    s.classes = ['Project']
    assert_equal ['BaseDistro'], s.search.map(&:name)
    s.classes = []
    # Issue + incorrect text
    s.text = 'not to be found'
    assert_equal 0, s.search.total_entries
    # Issue + included text
    s.text = 'container'
    assert_equal ['patchinfo'], s.search.map(&:name)
  end

  test 'searching by non existent issue' do
    # Only by issue
    s = FullTextSearch.new(issue_tracker_name: 'bnc', issue_name: '002200')
    # Wrong issue and no text
    assert_equal 0, s.search.total_entries
    # Wrong issue + wrong text
    s.text = 'not to be found'
    assert_equal 0, s.search.total_entries
    # Wrong issue + existent text
    s.text = 'container'
    assert_equal 0, s.search.total_entries
  end

  test 'searching by attrib' do
    # Only by attrib
    s = FullTextSearch.new(attrib_type_id: 57)
    # Order is not relevant
    assert_equal ['BaseDistro', 'BaseDistro2.0'], s.search.map(&:name).sort
    # Attrib + included text
    s.text = 'another'
    assert_equal ['BaseDistro2.0'], s.search.map(&:name)
  end

  test 'searching for a hidden project' do
    s = FullTextSearch.new(text: 'HiddenProject')
    assert_equal 0, s.search.total_entries
    User.current = users(:adrian)
    assert_equal 1, s.search.total_entries
    User.current = users(:fred)
    assert_equal 0, s.search.total_entries
  end

  test 'searching for a hidden package' do
    s = FullTextSearch.new(text: 'packcopy')
    assert_equal 0, s.search.total_entries
    User.current = users(:adrian)
    assert_equal 1, s.search.total_entries
    User.current = users(:fred)
    assert_equal 0, s.search.total_entries
  end
end
