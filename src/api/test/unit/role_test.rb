require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class RoleTest < ActiveSupport::TestCase
  fixtures :roles

  def test_something
    norole = Role.create :title => 'norole'
    norole.title = 'thisrole'
    norole.save
    norole.destroy
  end
  
end
