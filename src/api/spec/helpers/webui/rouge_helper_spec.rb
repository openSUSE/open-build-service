require 'rails_helper'

RSpec.describe Webui::RougeHelper do
  describe '#rouge_markdown' do
    it 'renders markdown links to html links' do
      expect(rouge_markdown('[my link](https://github.com/openSUSE/open-build-service/issues/5091)')).to eq(
                                                                                                                 "<p><a href='https://github.com/openSUSE/open-build-service/issues/5091'>my link</a></p>\n"
                                                                                                             )
    end

    it 'adds the OBS domain to relative links' do
      expect(rouge_markdown('[my link](/here)')).to eq(
                                                            "<p><a href='#{::Configuration.obs_url}/here'>my link</a></p>\n"
                                                        )
    end

    it 'detects all the mentions to users' do
      expect(rouge_markdown('@alfie @milo and @Admin, please review. Also you, @test1.')).to eq(
                                                                                                     "<p><a href='https://unconfigured.openbuildservice.org/users/alfie'>@alfie</a> \
<a href='https://unconfigured.openbuildservice.org/users/milo'>@milo</a> \
and <a href='https://unconfigured.openbuildservice.org/users/Admin'>@Admin</a>, \
please review. Also you, <a href='https://unconfigured.openbuildservice.org/users/test1'>@test1</a>.</p>\n"
                                                                                                 )
    end

    it "doesn't render users inside the text of html links" do
      expect(rouge_markdown('Group [openSUSE Leap 15.0 Incidents@DVD-Incidents](https://openqa.opensuse.org/tests/overview)')).to eq(
                                                                                                                                          "<p>Group <a href='https://openqa.opensuse.org/tests/overview'>openSUSE Leap 15.0 Incidents@DVD-Incidents</a></p>\n"
                                                                                                                                      )
    end

    it 'does not crash due to invalid URIs' do
      expect(rouge_markdown("anbox[400000+22d000]\r\n(the number)")).to eq(
                                                                                "<p>anbox<a href='the number'>400000+22d000</a></p>\n"
                                                                            )
    end

    it 'does not crash due to a missing language in a code block' do
      expect(rouge_markdown("```\ntext\n```").gsub("\n",'')).to eq("<div class=\"highlight\"><pre class=\"highlight plaintext\"><code>text</code></pre></div>")
    end

    it 'does apply a class to a code block with a language' do
      expect(rouge_markdown("```ruby\ndef\n```").gsub("\n", '')).to eq('<div class="highlight"><pre class="highlight ruby"><code><span class="k">def</span></code></pre></div>')
    end

    it 'does remove dangerous html from the view' do
      expect(rouge_markdown('<script></script>')).to eq("\n")
    end

    it 'does remove dangerous html from inside the code blocks with a language' do
      expect(rouge_markdown("```html\n<script></script>\n```").gsub("\n", '')).to eq(
                                                                       '<div class="highlight"><pre class="highlight html"><code><span class="nt">&lt;script&gt;&lt;/script&gt;</span></code></pre></div>'
                                                                   )
    end

    it 'does remove dangerous html from inside the code blocks without a language' do
      expect(rouge_markdown("```\n<script></script>\n```").gsub("\n", '')).to eq('<div class="highlight"><pre class="highlight plaintext"><code>&lt;script&gt;&lt;/script&gt;</code></pre></div>')
    end

    it 'does remove dangerous html from inside the links' do
      # rubocop:disable Layout/LineLength
      expect(rouge_markdown('[<script></script>](https://build.opensuse.org)')).to eq("<p><a href='https://build.opensuse.org'>&amp;lt;script&amp;gt;&amp;lt;/script&amp;gt;</a></p>\n")
      # rubocop:enable Layout/LineLength
    end
  end

end