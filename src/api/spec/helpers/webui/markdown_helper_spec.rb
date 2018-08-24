require 'rails_helper'

RSpec.describe Webui::MarkdownHelper do
  describe '#render_as_markdown' do
    it 'renders markdown links to html links' do
      expect(render_as_markdown('[my link](https://github.com/openSUSE/open-build-service/issues/5091)')).to eq(
        "<p><a href='https://github.com/openSUSE/open-build-service/issues/5091'>my link</a></p>\n"
      )
    end

    it 'adds the OBS domain to relative links' do
      expect(render_as_markdown('[my link](/here)')).to eq(
        "<p><a href='#{::Configuration.obs_url}/here'>my link</a></p>\n"
      )
    end

    it 'does not crash due to invalid URIs' do
      expect(render_as_markdown("anbox[400000+22d000]\r\n(the number)")).to eq(
        "<p>anbox<a href='the number'>400000+22d000</a></p>\n"
      )
    end
  end
end
