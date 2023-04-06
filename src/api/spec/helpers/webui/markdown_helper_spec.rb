require 'rails_helper'

RSpec.describe Webui::MarkdownHelper do
  describe '#render_as_markdown' do
    it 'renders markdown links to html links' do
      expect(render_as_markdown('[my link](https://github.com/openSUSE/open-build-service/issues/5091)')).to eq(
        "<p><a href=\"https://github.com/openSUSE/open-build-service/issues/5091\">my link</a></p>\n"
      )
    end

    it 'adds the OBS domain to relative links' do
      expect(render_as_markdown('[my link](/here)')).to eq(
        "<p><a href=\"#{Configuration.obs_url}/here\">my link</a></p>\n"
      )
    end

    it 'detects all the mentions to users' do
      expect(render_as_markdown('@alfie @milo and @Admin, please review. Also you, @test1 and @user.name.')).to eq(
        '<p><a href="https://unconfigured.openbuildservice.org/users/alfie">@alfie</a> ' \
        '<a href="https://unconfigured.openbuildservice.org/users/milo">@milo</a> ' \
        'and <a href="https://unconfigured.openbuildservice.org/users/Admin">@Admin</a>, ' \
        'please review. Also you, <a href="https://unconfigured.openbuildservice.org/users/test1">@test1</a> ' \
        "and <a href=\"https://unconfigured.openbuildservice.org/users/user.name\">@user.name</a>.</p>\n"
      )
    end

    it "doesn't render users inside the text of html links" do
      expect(render_as_markdown('Group [openSUSE Leap 15.0 Incidents@DVD-Incidents](https://openqa.opensuse.org/tests/overview)')).to eq(
        "<p>Group <a href=\"https://openqa.opensuse.org/tests/overview\">openSUSE Leap 15.0 Incidents@DVD-Incidents</a></p>\n"
      )
    end

    it 'does not crash due to invalid URIs' do
      expect(render_as_markdown("anbox[400000+22d000]\r\n(the number)")).to eq(
        "<p>anbox<a href=\"the%20number\">400000+22d000</a></p>\n"
      )
    end

    it 'does not crash due to a missing language in a code block' do
      expect(render_as_markdown("```\ntext\n```")).to eq("<div class=\"CodeRay\">\n  <div class=\"code\"><pre>text\n</pre></div>\n</div>\n")
    end

    it 'does apply a class to a code block with a language' do
      expect(render_as_markdown("```ruby\ndef\n```")).to eq("<div class=\"CodeRay\">\n  <div class=\"code\"><pre><span class=\"keyword\">def</span>\n</pre></div>\n</div>\n")
    end

    it 'does remove dangerous html from the view' do
      expect(render_as_markdown('<script></script>')).to eq("\n")
    end

    it 'does remove dangerous html from inside the code blocks with a language' do
      expect(render_as_markdown("```html\n<script></script>\n```")).to eq(
        "<div class=\"CodeRay\">\n  <div class=\"code\"><pre><span class=\"tag\">&lt;script&gt;</span><span class=\"tag\">&lt;/script&gt;</span>\n</pre></div>\n</div>\n"
      )
    end

    it 'does remove dangerous html from inside the code blocks without a language' do
      expect(render_as_markdown("```\n<script></script>\n```")).to eq("<div class=\"CodeRay\">\n  <div class=\"code\"><pre>&lt;script&gt;&lt;/script&gt;\n</pre></div>\n</div>\n")
    end

    it 'does remove dangerous html from inside the links' do
      expect(render_as_markdown('[<script></script>](https://build.opensuse.org)')).to eq(
        "<p><a href=\"https://build.opensuse.org\">&amp;lt;script&amp;gt;&amp;lt;/script&amp;gt;</a></p>\n"
      )
    end

    it 'just returns the original content on empty URIs' do
      expect(render_as_markdown('installed_ver = self.core.version_func[deps_info[6]]()')).to eq(
        "<p>installed_ver = self.core.version_func[deps_info[6]]()</p>\n"
      )
    end
  end
end
