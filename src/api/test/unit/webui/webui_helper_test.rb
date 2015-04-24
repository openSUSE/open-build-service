require 'test_helper'

include Webui::WebuiHelper


# TODO
# inject it per test as needed
module Webui::WebuiHelper 
	@configuration = {}
	@configuration['bugzilla_url'] = "https://bugzilla.example.org"
	@codemirror_editor_setup = 0
end

class Webui::WebuiHelperTest < ActiveSupport::TestCase


	def test_get_frontend_url_for_with_controller
		url = Webui::WebuiHelper.get_frontend_url_for({:controller=>"foo",:host=>"bar.com",:port=>80,:protocol=>"http"})
		assert_equal url,"http://bar.com:80/foo"
	end

	def test_bugzilla_url
		assert_not_nil Webui::WebuiHelper.bugzilla_url(["foo@example.org"],"foobar")
	end

	def test_plural
		assert_equal "car",  Webui::WebuiHelper.plural(1,"car","cars")
		assert_equal "cars", Webui::WebuiHelper.plural(5,"car","cars")
	end
	
	def test_valid_xml_id
		assert_equal "_123_456", Webui::WebuiHelper.valid_xml_id("123 456")
	end

	def test_elide
		assert_empty  Webui::WebuiHelper.elide("")
		assert_equal "...", Webui::WebuiHelper.elide("aaa",3)
		assert_equal "aaa...aaa", Webui::WebuiHelper.elide("aaaaaaaaaa",9)
		assert_equal "...aaaaaa", Webui::WebuiHelper.elide("aaaaaaaaaa",9,:left)
		assert_equal "aaaaaa...", Webui::WebuiHelper.elide("aaaaaaaaaa",9,:right)
	end

	def test_elide_two
		assert_equal ["aaa","bbb"], Webui::WebuiHelper.elide_two("aaa","bbb")
	end

	def test_next_codemirror_uid
		assert_kind_of Fixnum,Webui::WebuiHelper.next_codemirror_uid
	end

	def test_array_cachekey
		assert_not_nil array_cachekey([1,2,3])
	end
end
