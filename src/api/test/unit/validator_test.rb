require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

class ValidatorTest < ActiveSupport::TestCase

  def test_validator
     exception = assert_raise ArgumentError do
       Suse::Validator.validate 'notthere'
     end
     assert_match("wrong number of arguments (1 for 2)", exception.message)

     exception = assert_raise RuntimeError do
       # passing garbage
       Suse::Validator.validate [], ''
     end
     assert_match(/illegal option/, exception.message)

     exception = assert_raise ArgumentError do
       # no action, no schema
       Suse::Validator.validate :controller => :project
     end
     assert_match("wrong number of arguments (1 for 2)", exception.message)

     request = ActionController::TestRequest.new
     exception = assert_raise Suse::ValidationError do
       Suse::Validator.validate 'link', request.raw_post.to_s
     end
     assert_match(/Document is empty/, exception.message)

     request.env['RAW_POST_DATA'] = '<link test="invalid"/>'
     exception = assert_raise Suse::ValidationError do
       Suse::Validator.validate 'link', request.raw_post.to_s
     end
     assert_match(/Invalid attribute test for element link/, exception.message)

     request.env['RAW_POST_DATA'] = '<link test"invalid"/>'
     exception = assert_raise Suse::ValidationError do
       Suse::Validator.validate 'link', request.raw_post.to_s
     end
     assert_match(/Extra content at the end of the document/, exception.message)

     request.env['RAW_POST_DATA'] = '<link test="invalid">'
     exception = assert_raise Suse::ValidationError do
       Suse::Validator.validate 'link', request.raw_post.to_s
     end
     assert_match(/Premature end of data in tag link/, exception.message)

     request.env['RAW_POST_DATA'] = '<link test="invalid"></ink>'
     exception = assert_raise Suse::ValidationError do
       Suse::Validator.validate 'link', request.raw_post.to_s
     end
     assert_match(/Opening and ending tag mismatch/, exception.message)

     request.env['RAW_POST_DATA'] = '<link test="invalid" fun="foo"/>'
     exception = assert_raise Suse::ValidationError do
       Suse::Validator.validate 'link', request.raw_post.to_s
     end
     assert_match(/Invalid attribute test for element link/, exception.message)

     request.env['RAW_POST_DATA'] = '<link test="invalid">foo</link>'
     exception = assert_raise Suse::ValidationError do
       Suse::Validator.validate 'link', request.raw_post.to_s
     end
     assert_match(/Did not expect text in element link content/, exception.message)

     request.env['RAW_POST_DATA'] = '<link test="invalid"><foo/></link>'
     exception = assert_raise Suse::ValidationError do
       Suse::Validator.validate 'link', request.raw_post.to_s
     end
     assert_match(/Did not expect element foo there/, exception.message)

     # projects can be anything
     request.env['RAW_POST_DATA'] = '<link project="invalid"/>'
     assert_equal true, Suse::Validator.validate('link', request.raw_post.to_s)
  end
  
end
