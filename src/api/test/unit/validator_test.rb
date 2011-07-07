require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class ValidatorTest < ActiveSupport::TestCase

  def test_validator
     exception = assert_raise RuntimeError do
       Suse::Validator.new 'notthere'
     end
     assert_match(/unable to read schema file/, exception.message)

     exception = assert_raise RuntimeError do
       # passing garbage
       Suse::Validator.new []
     end
     assert_match(/illegal initialization option/, exception.message)

     exception = assert_raise RuntimeError do 
       # no action, no schema
       Suse::Validator.new :controller => :project
     end
     assert_match(/option hash needs keys/, exception.message)

     validator = Suse::Validator.new 'link'
     request = ActionController::TestRequest.new
     exception = assert_raise Suse::ValidationError do
       validator.validate( request.raw_post.to_s )
     end
     assert_match(/Document is empty/, exception.message)
  
     request.env['RAW_POST_DATA'] = '<link test="invalid"/>'
     exception = assert_raise Suse::ValidationError do
       validator.validate( request.raw_post.to_s )
     end
     assert_match(/Invalid attribute test for element link/, exception.message)

     # projects can be anything
     request.env['RAW_POST_DATA'] = '<link project="invalid"/>'
     assert_equal true, validator.validate( request.raw_post.to_s )
  end
  
end
