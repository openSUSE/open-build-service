require File.dirname(__FILE__) + '/../test_helper'

class ValidatorTest < ActiveSupport::TestCase

  def test_validator
     exception = assert_raise RuntimeError do
       Suse::Validator.new 'notthere'
     end
     assert_match /unable to read schema file/, exception.message

     exception = assert_raise RuntimeError do
       # passing garbage
       Suse::Validator.new []
     end
     assert_match /illegal initialization option/, exception.message

     # just a debug function
     assert_match /"packagelist"=>"directory"/, Suse::Validator.dump_map

     exception = assert_raise RuntimeError do 
       # no action, no schema
       Suse::Validator.new :controller => :project
     end
     assert_match /option hash needs keys/, exception.message

     validator = Suse::Validator.new 'link'
     request = ActionController::TestRequest.new
     exception = assert_raise Suse::ValidationError do
       validator.validate( request )
     end
     assert_match /Document is empty/, exception.message
  
     request.env['RAW_POST_DATA'] = '<link test="invalid"/>'
     exception = assert_raise Suse::ValidationError do
       validator.validate( request )
     end
     assert_match /The attribute 'test' is not allowed/, exception.message

     # projects can be anything
     request.env['RAW_POST_DATA'] = '<link project="invalid"/>'
     assert_equal true, validator.validate( request )
  end
  
end
