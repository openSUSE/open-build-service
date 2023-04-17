require_relative '../test_helper'

class ValidatorTest < ActiveSupport::TestCase
  def test_arguments
    exception = assert_raise(ArgumentError) do
      Suse::Validator.validate 'notthere'
    end
    assert_match('wrong number of arguments (given 1, expected 2)', exception.message)

    exception = assert_raise(RuntimeError) do
      # passing garbage
      Suse::Validator.validate [], ''
    end
    assert_match(/illegal option/, exception.message)

    exception = assert_raise(ArgumentError) do
      # no action, no schema
      Suse::Validator.validate controller: :project
    end
    assert_match('wrong number of arguments (given 1, expected 2)', exception.message)
  end

  def test_empty_data
    request = ActionController::TestRequest.create({})
    assert_raise(Suse::ValidationError) do
      Suse::Validator.validate 'link', request.raw_post.to_s
    end
  end

  def test_invalid_attribute_name
    request = ActionController::TestRequest.create({})
    request.env['RAW_POST_DATA'] = '<link test="invalid"/>'
    assert_raise(Suse::ValidationError) do
      Suse::Validator.validate 'link', request.raw_post.to_s
    end
  end

  def test_invalid_attribute_syntax
    request = ActionController::TestRequest.create({})
    request.env['RAW_POST_DATA'] = '<link project"invalid"/>'
    assert_raise(Suse::ValidationError) do
      Suse::Validator.validate 'link', request.raw_post.to_s
    end
  end

  def test_unclosed_element
    request = ActionController::TestRequest.create({})
    request.env['RAW_POST_DATA'] = '<link test="invalid">'
    assert_raise(Suse::ValidationError) do
      Suse::Validator.validate 'link', request.raw_post.to_s
    end
  end

  def test_ending_tag_mismatch
    request = ActionController::TestRequest.create({})
    request.env['RAW_POST_DATA'] = '<link test="invalid"></ink>'
    assert_raise(Suse::ValidationError) do
      Suse::Validator.validate 'link', request.raw_post.to_s
    end
  end

  def test_unexpected_text_content
    request = ActionController::TestRequest.create({})
    request.env['RAW_POST_DATA'] = '<link project="invalid">foo</link>'
    assert_raise(Suse::ValidationError) do
      Suse::Validator.validate 'link', request.raw_post.to_s
    end
  end

  def test_unexpected_element
    request = ActionController::TestRequest.create({})
    request.env['RAW_POST_DATA'] = '<link test="invalid"><foo/></link>'
    assert_raise(Suse::ValidationError) do
      Suse::Validator.validate 'link', request.raw_post.to_s
    end
  end

  def test_valid_data
    request = ActionController::TestRequest.create({})
    request.env['RAW_POST_DATA'] = '<link project="some:project"/>'
    assert_equal true, Suse::Validator.validate('link', request.raw_post.to_s)
  end
end
