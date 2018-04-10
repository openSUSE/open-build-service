# frozen_string_literal: true
require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class DebuginfoFlagTest < ActiveSupport::TestCase
  fixtures :all

  def setup
    @project = projects(:home_Iggy)
    assert_kind_of Project, @project
    @package = packages(:home_Iggy_TestPack)
    assert_kind_of Package, @package
    @arch = architectures(:i586)
    assert_kind_of Architecture, @arch
  end

  # Replace this with your real tests.
  def test_add_debug_flag_to_project
    # checking precondition
    assert_equal 2, @project.flags.of_type('debuginfo').size

    # create two new flags and save it.
    for i in 1..2 do
      f = Flag.new(repo: "10.#{i}", status: 'enable', position: i + 2, flag: 'debuginfo')
      f.architecture = @arch
      @project.flags << f
    end

    @project.reload

    # check the result
    assert_equal 4, @project.flags.of_type('debuginfo').size

    f = @project.flags.of_type('debuginfo')[2]
    assert_kind_of Flag, f

    assert_equal '10.1', f.repo
    assert_equal @arch.id, f.architecture_id
    assert_equal 'enable', f.status
    assert_equal @project.id, f.project_id
    assert_nil f.package_id
    assert_equal 3, f.position

    f = @project.flags.of_type('debuginfo')[3]
    assert_kind_of Flag, f

    assert_equal '10.2', f.repo
    assert_equal @arch.id, f.architecture_id
    assert_equal 'enable', f.status
    assert_equal @project.id, f.project_id
    assert_nil f.package_id
    assert_equal 4, f.position
  end

  def test_add_debug_flag_to_package
    # checking precondition
    assert_equal 1, @package.flags.of_type('debuginfo').size

    # create two new flags and save it.
    for i in 1..2 do
      f = Flag.new(repo: "10.#{i}", status: 'disable', position: i + 1, flag: 'debuginfo')
      f.architecture = @arch
      @package.flags << f
    end

    @package.reload

    # check the result
    assert_equal 3, @package.flags.of_type('debuginfo').size

    f = @package.flags.of_type('debuginfo')[1]
    assert_kind_of Flag, f

    assert_equal '10.1', f.repo
    assert_equal @arch.id, f.architecture_id
    assert_equal 'disable', f.status
    assert_equal @package.id, f.package_id
    assert_nil f.project_id
    assert_equal 2, f.position

    f = @package.flags.of_type('debuginfo')[2]
    assert_kind_of Flag, f

    assert_equal '10.2', f.repo
    assert_equal @arch.id, f.architecture_id
    assert_equal 'disable', f.status
    assert_equal @package.id, f.package_id
    assert_nil f.project_id
    assert_equal 3, f.position
  end

  def test_delete_debuginfo_flags_from_project
    # checking precondition
    assert_equal 2, @project.flags.of_type('debuginfo').size
    # checking total number of flags stored in the database
    count = Flag.all.size

    # destroy flags
    @project.flags.of_type('debuginfo')[1].destroy
    # reload required!
    @project.reload
    assert_equal 1, @project.flags.of_type('debuginfo').size
    assert_equal 1, count - Flag.all.size

    @project.flags.of_type('debuginfo')[0].destroy
    # reload required
    @project.reload
    assert_equal 0, @project.flags.of_type('debuginfo').size
    assert_equal 2, count - Flag.all.size
  end

  def test_delete_debuginfo_flags_from_package
    # checking precondition
    assert_equal 1, @package.flags.of_type('debuginfo').size
    # checking total number of flags stored in the database
    count = Flag.all.size

    # destroy flags
    @package.flags.of_type('debuginfo')[0].destroy
    # reload required!
    @package.reload
    assert_equal 0, @package.flags.of_type('debuginfo').size
    assert_equal 1, count - Flag.all.size
  end

  def test_position
    # Because of each flag belongs_to architecture AND project|package for the
    # position calculation it is important in which order the assignments
    # flag -> architecture and flag -> project|package are done.
    # If flag -> architecture is be done first, no flag position (in the list of
    # flags assigned to a object) can be calculated. This is because of no reference
    # (project_id or package_id) is set, which is needed for position calculation.
    # The models should take this circumstances into consideration.

    # checking precondition
    assert_equal 2, @project.flags.of_type('debuginfo').size
    # checking total number of flags stored in the database
    count = Flag.all.size

    # create new flag and save it.
    f = Flag.new(repo: '10.3', status: 'enable', position: 3, flag: 'debuginfo')
    f.architecture = @arch
    @project.flags << f

    @project.reload
    assert_equal 3, @project.flags.of_type('debuginfo').size
    assert_equal 1, Flag.all.size - count

    f.reload
    assert_equal 3, f.position

    # a flag update should not alter the flag position
    f.repo = '10.0'
    f.save

    f.reload
    assert_equal '10.0', f.repo
    assert_equal 3, f.position

    # create new flag and save it, but set the references in different order as above.
    # The result should be the same.
    f = Flag.new(repo: '10.2', status: 'enable', position: 4, flag: 'debuginfo')
    f.architecture = @arch
    @project.flags << f

    @project.reload
    assert_equal 4, @project.flags.of_type('debuginfo').size
    assert_equal 2, Flag.all.size - count

    f.reload
    assert_equal 4, f.position

    # a flag update should not alter the flag position
    f.repo = '10.1'
    f.save

    f.reload
    assert_equal '10.1', f.repo
    assert_equal 4, f.position
  end
end
