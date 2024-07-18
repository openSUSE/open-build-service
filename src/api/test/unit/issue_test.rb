require_relative '../test_helper'

class IssueTest < ActiveSupport::TestCase
  fixtures :all

  BUG_GET_0815 = '<?xml version="1.0" ?><methodCall><methodName>Bug.get</methodName><params><param><value><struct>' \
                 '<member><name>ids</name><value><array><data><value><string>1234</string></value><value><string>0815</string></value></data></array></value></member>' \
                 '<member><name>permissive</name><value><i4>1</i4></value></member>' \
                 "</struct></value></param></params></methodCall>\n".freeze

  def test_parse
    bnc = IssueTracker.find_by_name('bnc')
    url = bnc.show_url_for('0815')
    assert_equal url, 'https://bugzilla.novell.com/show_bug.cgi?id=0815'
  end

  def test_create_and_destroy
    stub_request(:post, 'http://bugzilla.novell.com/xmlrpc.cgi')
      .with(body: BUG_GET_0815)
      .to_return(status: 200,
                 body: load_backend_file('bugzilla_get_0815.xml'),
                 headers: {})

    # pkg = Package.find( 10095 )
    iggy = User.find_by_email('Iggy@pop.org')
    bnc = IssueTracker.find_by_name('bnc')
    issue = Issue.create(name: '0815', issue_tracker: bnc)
    issue.save
    issue.summary = 'This unit test is not working'
    issue.state = Issue.bugzilla_state('NEEDINFO')
    issue.owner = iggy
    issue.save
    issue.destroy
  end

  BUG_SEARCH = "<?xml version=\"1.0\" ?><methodCall><methodName>Bug.search</methodName>
               <params><param><value><struct><member><name>last_change_time</name><value>
               <dateTime.iso8601>20110729T14:00:21</dateTime.iso8601></value></member></struct>
               </value></param></params></methodCall>\n".freeze
  BUG_GET = "<?xml version=\"1.0\" ?><methodCall><methodName>Bug.get</methodName><params><param>
            <value><struct><member><name>ids</name><value><array><data><value><i4>838932</i4></value>
            <value><i4>838933</i4></value><value><i4>838970</i4></value></data></array></value></member>
            <member><name>permissive</name><value><i4>1</i4></value></member>
            </struct></value></param></params></methodCall>\n".freeze

  test 'fetch issues' do
    stub_request(:post, 'http://bugzilla.novell.com/xmlrpc.cgi')
      .with(body: BUG_SEARCH)
      .to_return(status: 200,
                 body: load_backend_file('bugzilla_response_search.xml'),
                 headers: {})

    stub_request(:post, 'http://bugzilla.novell.com/xmlrpc.cgi')
      .with(body: BUG_GET)
      .to_return(status: 200,
                 body: load_backend_file('bugzilla_get_response.xml'),
                 headers: {})

    IssueTracker.update_all_issues
  end

  test 'fetch cve' do
    # erase all the bugzilla fixtures
    Issue.destroy_all
    IssueTracker.find_by_kind('bugzilla').destroy

    cve = IssueTracker.find_by_name('cve')
    cve.enable_fetch = 1
    Backend::Test.without_global_write_through do
      cve.save
    end
    cve.issues.create(name: 'CVE-1999-0001')

    stub_request(:head, 'https://cve.mitre.org/data/downloads/allitems.xml.gz')
      .to_return(status: 200, headers: { 'Last-Modified' => 2.days.ago })

    stub_request(:get, 'https://cve.mitre.org/data/downloads/allitems.xml.gz')
      .to_return(status: 200, body: load_backend_file('allitems.xml.gz'),
                 headers: { 'Last-Modified' => 2.days.ago })

    IssueTracker.update_all_issues
  end

  test 'fetch fate' do
    # erase all the bugzilla fixtures
    Issue.destroy_all
    IssueTracker.find_by_kind('bugzilla').destroy

    stub_request(:get, 'https://features.opensuse.org//fate')
      .to_return(status: 200, body: '', headers: {})

    fate = IssueTracker.find_by_name('fate')
    fate.enable_fetch = 1
    Backend::Test.without_global_write_through do
      fate.save
    end
    fate.issues.create(name: 'fate#2282')

    IssueTracker.update_all_issues
  end
end
