require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class DistributionsControllerTest < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    reset_auth
  end

  def test_should_show_distribution
    login_tom
    get distribution_path(id: distributions(:two).to_param)
    assert_response :success
    # the default XML renderer just s***s
    assert_equal({ 'id'            => { 'type' => 'integer', '_content' => '2' },
                   'link'          => 'http://www.openbuildservice.org/',
                   'name'          => 'OBS Base 2.0',
                   'project'       => 'BaseDistro2.0',
                   'reponame'      => 'Base_repo',
                   'repository'    => 'BaseDistro2_repo',
                   'vendor'        => 'OBS',
                   'version'       => 'Base',
                   'architectures' =>
                                      { 'type'         => 'array',
                                        'architecture' => %w[i586 x86_64] },
                   'icons'         =>
                                      { 'type' => 'array',
                                        'icon' =>
                                                  [{ 'id'     => { 'type' => 'integer', '_content' => '72' },
                                                     'url'    =>
                                                                 'https://static.opensuse.org/distributions/logos/opensuse-Factory-8.png',
                                                     'width'  => { 'type' => 'integer', '_content' => '8' },
                                                     'height' => { 'type' => 'integer', '_content' => '8' } },
                                                   { 'id'     => { 'type' => 'integer', '_content' => '73' },
                                                     'url'    =>
                                                                 'https://static.opensuse.org/distributions/logos/opensuse-Factory-16.png',
                                                     'width'  => { 'type' => 'integer', '_content' => '16' },
                                                     'height' => { 'type' => 'integer', '_content' => '16' } }] } }, Xmlhash.parse(@response.body))
  end

  def test_should_destroy_distribution
    login_king
    assert_difference('Distribution.count', -1) do
      delete distribution_path(id: distributions(:one).to_param)
      assert_response :success
    end
  end

  def test_the_old_interface_works
    data = '<distributions>
               <distribution vendor="openSUSE" version="Factory" id="opensuse-Factory">
                 <name>openSUSE Factory</name>
                 <project>openSUSE:Factory</project>
                 <reponame>openSUSE_Factory</reponame>
                 <repository>snapshot</repository>
                 <icon width="8" height="8" url="https://static.opensuse.org/distributions/logos/opensuse-Factory-8.png"/>
                 <icon width="16" height="16" url="https://static.opensuse.org/distributions/logos/opensuse-Factory-16.png"/>
                 <link>http://www.opensuse.org/</link>
                 <architecture>i586</architecture>
               </distribution>
             </distributions>
             '

    put '/distributions', params: data
    assert_response 401

    login_tom
    put '/distributions', params: data
    assert_response 403

    login_king
    put '/distributions', params: data
    assert_response 200

    login_tom
    get '/distributions'
    assert_response :success
    assert_no_xml_tag tag: 'project', content: 'RemoteInstance:openSUSE:12.2'
    assert_xml_tag tag: 'name', content: 'openSUSE Factory'
    assert_xml_tag tag: 'project', content: 'openSUSE:Factory'
    assert_xml_tag tag: 'reponame', content: 'openSUSE_Factory'
    assert_xml_tag tag: 'repository', content: 'snapshot'
    assert_xml_tag tag: 'link', content: 'http://www.opensuse.org/'
    assert_xml_tag tag: 'architecture', content: 'i586'
  end

  def test_remotes_work
    login_tom

    fake_distribution_body = File.open(Rails.root.join('test/fixtures/backend/distributions.xml')).read

    # using mocha has the disadvantage of not testing the complete function
    # Distribution.stubs(:load_distributions_from_remote).returns(fake_distribution_body)

    stub_request(:get, "http://localhost:#{CONFIG['source_port']}/distributions.xml").
      with(headers: { 'Accept' => '*/*', 'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'User-Agent' => 'Ruby' }).
      to_return(status: 200, body: fake_distribution_body, headers: {})

    get '/distributions/include_remotes'
    assert_response :success

    # validate rendering and modifications of a remote repo
    assert_xml_tag tag: 'name', content: 'openSUSE 12.2' # remote 1
    assert_xml_tag tag: 'name', content: 'openSUSE Factory' # remote 2
    assert_xml_tag tag: 'name', content: 'OBS Base 2.0' # local only
    assert_xml_tag tag: 'project', content: 'RemoteInstance:openSUSE:12.2'
    assert_xml_tag tag: 'reponame', content: 'openSUSE_12.2'
    assert_xml_tag tag: 'repository', content: 'standard'
    assert_xml_tag tag: 'link', content: 'http://www.opensuse.org/'
    assert_xml_tag tag: 'icon', attributes: { url: 'https://static.opensuse.org/distributions/logos/opensuse-12.2-8.png',
                                                    width: '8', height: '8' }
    # local repos
    assert_no_xml_tag parent: { tag: 'distribution', attributes: { vendor: 'openSUSE', version: '1.0' } },
                   tag: 'architecture'
    assert_xml_tag parent: { tag: 'distribution', attributes: { vendor: 'OBS', version: 'Base' } },
                   tag: 'architecture', content: 'x86_64'
    # remote repos
    assert_no_xml_tag parent: { tag: 'distribution', attributes: { vendor: 'openSUSE', version: 'Factory' } },
                   tag: 'architecture'
    assert_xml_tag parent: { tag: 'distribution', attributes: { vendor: 'openSUSE', version: '12.2' } },
                   tag: 'architecture', content: 'aarch64'
  end

  def test_we_survive_remote_instances_timeouts
    login_tom
    stub_request(:get, "http://localhost:#{CONFIG['source_port']}/distributions.xml").to_timeout
    get '/distributions/include_remotes'
    assert_response :success
    # only the one local is included
    assert_xml_tag tag: 'distributions', children: { count: 2 }
  end
end
