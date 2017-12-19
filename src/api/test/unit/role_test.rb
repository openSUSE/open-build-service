require_relative '../test_helper'

class RoleTest < ActiveSupport::TestCase
  def test_something
    norole = Role.create title: 'norole'
    norole.title = 'thisrole'
    norole.save
    norole.destroy
  end

  def test_role
    r = Role.create title: 'maintainer'
    assert !r.valid?
  end
end
