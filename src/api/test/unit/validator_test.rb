require File.expand_path(File.dirname(__FILE__) + "/..") + "/test_helper"

require 'opensuse/validator'

class ValidatorTest < ActiveSupport::TestCase
  def test_validator
    exception = assert_raise ArgumentError do
      Suse::Validator.validate 'notthere'
    end
    assert_match("wrong number of arguments (given 1, expected 2)", exception.message)

    exception = assert_raise RuntimeError do
      # passing garbage
      Suse::Validator.validate [], ''
    end
    assert_match(/illegal option/, exception.message)

    exception = assert_raise ArgumentError do
      # no action, no schema
      Suse::Validator.validate controller: :project
    end
    assert_match("wrong number of arguments (given 1, expected 2)", exception.message)

    request = ActionController::TestRequest.create({})
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

  def test_assert_xml
    xml = <<-EOS
      <services>
        <service name="download_url">
          <param name="host">blahfasel</param>
        </service>
        <service name="download_files" />
        <service name="set_version">
          <param name="version">0815</param>
        </service>
      </services>
    EOS
    assert_xml_tag xml, tag: "service", attributes: { name: "download_url", not_present_tag: nil }
    assert_xml_tag xml, before: { attributes: { name: "set_version" } }, attributes: { name: "download_files" }
    assert_xml_tag xml, after: { attributes: { name: "download_url" } }, attributes: { name: "download_files" }
    assert_xml_tag xml, sibling: { attributes: { name: "download_url" } }, attributes: { name: "set_version" }
    assert_xml_tag xml, ancestor: { tag: "services" }, content: "0815"
    assert_xml_tag xml, descendant: { content: "0815" }
    assert_no_xml_tag xml, descendant: { content: "0815" }, tag: "param", attributes: { name: "host" }
    assert_xml_tag xml, tag: "services", children: { count: 3, only: { tag: "service" } }
    assert_xml_tag xml, tag: "service", attributes: { name: "download_files" }
    assert_xml_tag xml, parent: { tag: "service", attributes: { name: "download_url" } },
                        tag: "param", attributes: { name: "host" },
                        content: "blahfasel"
    assert_xml_tag xml, parent: { tag: "service", attributes: { name: "set_version" } },
                        tag: "param", attributes: { name: "version" },
                        content: "0815"
    assert_no_xml_tag xml, parent: { tag: "service", attributes: { name: "set_version" } },
                           tag: "param", attributes: { name: "version" },
                           content: "0816"
    assert_xml_tag xml, child: { tag: "param" }, attributes: { name: "download_url" }

    xml = <<-EOS
      <project name="home:Iggy:branches:BaseDistro">
        <package project="home:Iggy:branches:BaseDistro" name="pack1">
        </package>
        <package project="home:Iggy:branches:BaseDistro" name="pack_new">
        </package>
      </project>
    EOS
    assert_no_xml_tag xml, parent: { tag: 'issue' }

    xml = <<-EOS
      <person>
        <login>tom</login>
        <email>tschmidt@example.com</email>
        <realname>Freddy Cool</realname>
        <watchlist>
        </watchlist>
      </person>
    EOS
    assert_no_xml_tag xml, { tag: "person", child: { tag: "globalrole", content: "Admin" } }
  end
end
