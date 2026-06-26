# We monkey patch ActiveSupport::TestCase in test/test_helper.rb
# This test covers the added methods
class ActiveSupportTestCaseTest < ActiveSupport::TestCase
  def test_assert_xml_tag
    xml = <<-XML
      <services>
        <service name="download_url">
          <param name="host">blahfasel</param>
        </service>
        <service name="download_files" />
        <service name="set_version">
          <param name="version">0815</param>
        </service>
      </services>
    XML
    assert_xml_tag xml, tag: 'service', attributes: { name: 'download_url', not_present_tag: nil }
    assert_xml_tag xml, before: { attributes: { name: 'set_version' } }, attributes: { name: 'download_files' }
    assert_xml_tag xml, after: { attributes: { name: 'download_url' } }, attributes: { name: 'download_files' }
    assert_xml_tag xml, sibling: { attributes: { name: 'download_url' } }, attributes: { name: 'set_version' }
    assert_xml_tag xml, ancestor: { tag: 'services' }, content: '0815'
    assert_xml_tag xml, descendant: { content: '0815' }
    assert_no_xml_tag xml, descendant: { content: '0815' }, tag: 'param', attributes: { name: 'host' }
    assert_xml_tag xml, tag: 'services', children: { count: 3, only: { tag: 'service' } }
    assert_xml_tag xml, tag: 'service', attributes: { name: 'download_files' }
    assert_xml_tag xml, parent: { tag: 'service', attributes: { name: 'download_url' } },
                        tag: 'param', attributes: { name: 'host' },
                        content: 'blahfasel'
    assert_xml_tag xml, parent: { tag: 'service', attributes: { name: 'set_version' } },
                        tag: 'param', attributes: { name: 'version' },
                        content: '0815'
    assert_no_xml_tag xml, parent: { tag: 'service', attributes: { name: 'set_version' } },
                           tag: 'param', attributes: { name: 'version' },
                           content: '0816'
    assert_xml_tag xml, child: { tag: 'param' }, attributes: { name: 'download_url' }
  end

  def test_assert_no_xml_tag
    xml = <<-XML
      <project name="home:Iggy:branches:BaseDistro">
        <package project="home:Iggy:branches:BaseDistro" name="pack1">
        </package>
        <package project="home:Iggy:branches:BaseDistro" name="pack_new">
        </package>
      </project>
    XML
    assert_no_xml_tag xml, parent: { tag: 'issue' }

    xml = <<-XML
      <person>
        <login>tom</login>
        <email>tschmidt@example.com</email>
        <realname>Freddy Cool</realname>
        <watchlist>
        </watchlist>
      </person>
    XML
    assert_no_xml_tag xml, tag: 'person', child: { tag: 'globalrole', content: 'Admin' }
  end
end
