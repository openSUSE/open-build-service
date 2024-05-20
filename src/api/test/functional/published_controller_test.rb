require File.expand_path(File.dirname(__FILE__) + '/..') + '/test_helper'

class PublishedControllerTest < ActionDispatch::IntegrationTest
  fixtures :all

  def setup
    Backend::Test.start(wait_for_scheduler: true)
    run_publisher
    reset_auth
  end

  # FRONTEND: Test published api
  def test_index
    get '/published'
    assert_response :unauthorized

    get '/published/HiddenProject'
    assert_response :unauthorized

    get '/published/kde4'
    assert_response :unauthorized

    get '/published/kde4/openSUSE_11.3'
    assert_response :unauthorized

    get '/published/kde4/openSUSE_11.3/i586'
    assert_response :unauthorized

    login_tom
    get '/published'
    assert_response :success
    assert_no_match(/entry name="HiddenProject"/, @response.body)

    get '/published/HiddenProject'
    assert_response :not_found

    get '/published/kde4'
    assert_response :ok

    get '/published/kde4/openSUSE_11.3'
    assert_response :ok

    get '/published/kde4/openSUSE_11.3/i586'
    assert_response :ok

    # FIXME: these error 404 are caused by incomplete test data, not by correct handling
    #    get "/published/kde4/openSUSE_11.3/i586/kdelibs"
    #    assert_response 404
    #
    #    get "/published/kde4/openSUSE_11.3/i586/kdelibs-3.2.1-1.5.i586.rpm"
    #    assert_response 404
    #
    #    get "/published/home:Iggy/10.2/i586/package-1.0-1.i586.rpm"
    #    assert_response 404
  end

  def test_ymp_as_used_on_software_o_o
    login_adrian
    get '/published/home:Iggy/10.2/TestPack?view=ymp'
    assert_response :success
    assert_xml_tag parent: { tag: 'repository', attributes: { recommended: 'true' } },
                   tag: 'url', content: 'http://example.com/download/home:/Iggy/10.2/'
    assert_xml_tag parent: { tag: 'repository', attributes: { recommended: 'false' } },
                   tag: 'url', content: 'http://example.com/download/BaseDistro/BaseDistro_repo/'

    # software description
    assert_xml_tag tag: 'name', content: 'TestPack'
    assert_xml_tag tag: 'summary', content: 'The TestPack package'
    assert_xml_tag tag: 'description', content: 'The TestPack package'
  end

  def test_binary_view
    get '/published/kde4/openSUSE_11.3/i586/kdelibs-3.2.1-1.5.i586.rpm'
    assert_response :unauthorized

    login_tom
    get '/published/kde4/openSUSE_11.3/i586/kdelibs-3.2.1-1.5.i586.rpm'
    assert_response :not_found # does not exist
  end
  # FIXME: this needs to be extended, when we have added binaries and bs_publisher to the test suite

  def test_rpm_md_formats
    # OBS is doing this usually right, but createrepo is quite flaky ...
    login_adrian
    # default configured rpm-md
    get '/published/home:adrian:ProtectionTest/repo/repodata'
    assert_response :success
    assert_no_xml_tag tag: 'entry', attributes: { name: 'filelists.xml.gz' }
    assert_no_xml_tag tag: 'entry', attributes: { name: 'other.xml.gz' }
    assert_no_xml_tag tag: 'entry', attributes: { name: 'primary.xml.gz' }
    assert_xml_tag tag: 'entry', attributes: { name: 'repomd.xml' }
    assert_match(/-filelists.xml.gz"/, @response.body)
    assert_match(/-other.xml.gz"/, @response.body)
    assert_match(/-primary.xml.gz"/, @response.body)
    # legacy configured rpm-md
    get '/published/home:Iggy/10.2/repodata'
    assert_response :success
    assert_xml_tag tag: 'entry', attributes: { name: 'filelists.xml.gz' }
    assert_xml_tag tag: 'entry', attributes: { name: 'other.xml.gz' }
    assert_xml_tag tag: 'entry', attributes: { name: 'primary.xml.gz' }
    assert_xml_tag tag: 'entry', attributes: { name: 'repomd.xml' }

    # verify meta data created by create_package_descr
    package_seen = {}
    IO.popen("gunzip -cd #{ENV.fetch('OBS_BACKEND_TEMP', nil)}/data/repos/BaseDistro3/BaseDistro3_repo/repodata/*-primary.xml.gz") do |io|
      hashed = Xmlhash.parse(io.read)
      hashed.elements('package').each do |p|
        next unless (p['name'] == 'package' && p['arch'] == 'i586') || (p['name'] == 'package_newweaktags' && p['arch'] == 'x86_64')

        package_seen[p['name']] = true
        assert_not_nil p
        assert_equal 'GPLv2+', p['format']['rpm:license']
        assert_equal 'Development/Tools/Building', p['format']['rpm:group']
        assert_equal '280', p['format']['rpm:header-range']['start']
        assert_equal 'bash', p['format']['rpm:requires']['rpm:entry']['name']
        assert_equal 'myself', p['format']['rpm:provides']['rpm:entry'][0]['name']
        assert_equal 'something', p['format']['rpm:conflicts']['rpm:entry']['name']
        assert_equal 'old_crap', p['format']['rpm:obsoletes']['rpm:entry']['name']
        case p['name']
        when 'package'
          assert_equal 'package-1.0-1.src.rpm', p['format']['rpm:sourcerpm']
          assert_equal '2156', p['format']['rpm:header-range']['end']
          assert_equal 'package', p['format']['rpm:provides']['rpm:entry'][1]['name']
          assert_equal 'package(x86-32)', p['format']['rpm:provides']['rpm:entry'][2]['name']
        when 'package_newweaktags'
          assert_equal 'package_newweaktags-1.0-1.src.rpm', p['format']['rpm:sourcerpm']
          assert_equal '2300', p['format']['rpm:header-range']['end']
          assert_equal 'package_newweaktags', p['format']['rpm:provides']['rpm:entry'][1]['name']
          assert_equal 'package_newweaktags(x86-64)', p['format']['rpm:provides']['rpm:entry'][2]['name']
        else
          assert nil # unhandled src rpm
        end
        next unless File.exist?('/var/adm/fillup-templates') || File.exist?('/usr/share/fillup-templates/')

        # seems to be a SUSE system
        print 'createrepo seems not to create week dependencies, we need this at least on SUSE systems' if p['format']['rpm:suggests'].nil?
        assert_equal 'pure_optional', p['format']['rpm:suggests']['rpm:entry']['name']
        assert_equal 'would_be_nice', p['format']['rpm:recommends']['rpm:entry']['name']
        assert_equal 'other_package_likes_it', p['format']['rpm:supplements']['rpm:entry']['name']
        assert_equal 'other_package', p['format']['rpm:enhances']['rpm:entry']['name']
      end
    end
    assert package_seen['package']
    assert package_seen['package_newweaktags']

    # master tags
    hashed = nil
    IO.popen("cat #{ENV.fetch('OBS_BACKEND_TEMP', nil)}/data/repos/BaseDistro3/BaseDistro3_repo/repodata/repomd.xml") do |io|
      hashed = Xmlhash.parse(io.read)
    end
    if File.exist?('/var/adm/fillup-templates') || File.exist?('/usr/share/fillup-templates/')
      # seems to be a SUSE system
      assert_equal hashed['tags']['repo'][0], 'obsrepository://obstest/BaseDistro3/BaseDistro3_repo'
      assert hashed['tags']['repo'][1].match(/^obsbuildid:.*/)
    else
      puts 'WARNING: some tests are skipped on non-SUSE systems. rpmmd meta data may not be complete.'
    end
  end

  def test_suse_format
    # Ensure that it doesn't fail in non SUSE platforms TODO: Move this to a method
    return unless File.exist?('/var/adm/fillup-templates') || File.exist?('/usr/share/fillup-templates/')

    login_adrian

    # BACKEND: Test that tooling used in the backend produce correct content via the api in the frontend
    get '/published/BaseDistro3/BaseDistro3_repo/content'
    assert_response :success
    assert_match(/PRODUCT Open Build Service BaseDistro3 BaseDistro3_repo\n/, @response.body)
    assert_match(/\nVERSION 1.0-0/, @response.body)
    assert_match(/\nLABEL This is another base distro, without update project/, @response.body)
    assert_match(/\nVENDOR Open Build Service/, @response.body)
    assert_match(/\nARCH.x86_64 x86_64 i686 i586 i486 i386 noarch/, @response.body)
    assert_match(/\nARCH.i586 i586 i486 i386 noarch/, @response.body)
    assert_match(/\nARCH.k1om k1om noarch/, @response.body)
    assert_match(/\nDEFAULTBASE i586\n/, @response.body)
    assert_match(/\nDESCRDIR descr\n/, @response.body)
    assert_match(/\nDATADIR .\n/, @response.body)

    # BACKEND: Test that the content generated by the backend tooling is creating some subdirectory in a concrete way
    # FRONTEND: Test that the subdirectories created by the backend can be accessed thought the API in the frontend
    get '/published/BaseDistro3/BaseDistro3_repo/media.1/directory.yast'
    assert_response :success
    get '/published/BaseDistro3/BaseDistro3_repo/media.1/media'
    assert_response :success
    assert_match(/^Open Build Service/, @response.body)
    get '/published/BaseDistro3/BaseDistro3_repo/descr/packages.en'
    assert_response :success
    get '/published/BaseDistro3/BaseDistro3_repo/descr/packages.DU'
    assert_response :success
    get '/published/BaseDistro3/BaseDistro3_repo/descr/packages'
    assert_response :success
  end
end
