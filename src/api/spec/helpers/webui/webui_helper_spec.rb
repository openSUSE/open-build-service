require 'rails_helper'

RSpec.describe Webui::WebuiHelper do
  let(:input) { 'Rocking the Open Build Service' }

  describe '#elide' do
    it 'does not elide' do
      expect(input).to eq(elide(input, input.length))
    end

    it 'does elide 20 character by default in the middle' do
      expect('Rocking t... Service').to eq(elide(input))
    end

    it 'does elide from the left' do
      expect('...the Open Build Service').to eq(elide(input, 25, :left))
    end

    it 'does elide from the right' do
      expect('R...').to eq(elide(input, 4, :right))
    end

    it 'returns three dots for eliding two characters' do
      expect('...').to eq(elide(input, 2, :right))
    end

    it 'returns three dots for eliding three characters' do
      expect('...').to eq(elide(input, 3, :right))
    end

    it 'reduces a string to 10 characters and elides in the middle by default' do
      expect('Rock...ice').to eq(elide(input, 10))
    end
  end

  describe '#elide_two' do
    it 'elides two strings with the proper overall length' do
      input2 = "don't shorten"
      expect([input2, 'Rocking the ...uild Service']).to eq(elide_two(input2, input, 40))
    end
  end

  describe '#valid_xml_id' do
    it 'replaces invalid characters with underscores' do
      expect('a___________').to eq(valid_xml_id('a+&: ./~()@#'))
    end

    it 'prepends an underscore if id does not start with a valid character' do
      expect('_10_2').to eq(valid_xml_id('10.2'))
    end
  end

  describe '#repo_status_icon' do
    it 'renders icon' do
      blocked = repo_status_icon('blocked')
      expect(blocked).to include("icons-time")
      expect(blocked).to include("No build possible atm")
    end

    it 'renders outdated icon' do
      outdated_scheduling = repo_status_icon('outdated_scheduling')
      expect(outdated_scheduling).to include("icons-cog_error")
      expect(outdated_scheduling).to include("state is being calculated")
      expect(outdated_scheduling).to include("needs recalculations")
    end

    it 'renders unknown icon' do
      undefined_icon = repo_status_icon('undefined')
      expect(undefined_icon).to include("icons-eye")
      expect(undefined_icon).to include("Unknown state")
    end
  end

  describe '#get_frontend_url_for' do
    it 'generates a url' do
      url = get_frontend_url_for(controller: 'foo', host: 'bar.com', port: 80, protocol: 'http')
      expect(url).to eq("http://bar.com:80/foo")
    end
  end

  describe '#bugzilla_url' do
    before do
      @configuration = { 'bugzilla_url' => 'https://bugzilla.example.org' }
      @expected_attributes = {
        classification: 7340,
        product:        'openSUSE.org',
        component:      '3rd%20party%20software',
        assigned_to:    '',
        short_desc:     ''
      }
    end

    it 'returns link to a prefilled bugzilla enter bug form' do
      expected_url = "https://bugzilla.example.org/enter_bug.cgi?" +
                       @expected_attributes.map { |key, value| "#{key}=#{value}" }.join('&')
      expect(bugzilla_url).to eq(expected_url)
    end

    it 'adds an assignee and description if parameters where given' do
      expected_attributes = @expected_attributes.clone
      expected_attributes[:short_desc] = 'some_description'
      expected_attributes[:assigned_to] = 'assignee@example.org'

      expected_url = "https://bugzilla.example.org/enter_bug.cgi?" +
                       expected_attributes.map { |key, value| "#{key}=#{value}" }.join('&')
      expect(bugzilla_url(['assignee@example.org'], 'some_description')).to eq(expected_url)
    end
  end

  describe '#valid_xml_id' do
    it "ensures that xml_id starts with '_' or a character" do
      expect(valid_xml_id('123')).to eq('_123')
      expect(valid_xml_id('abc')).to eq('abc')
    end

    it 'substitutes invalid characters with underscores' do
      expect(valid_xml_id('abc+&: .()~@#')).to eq('abc__________')
    end

    it 'html escapes the input' do
      expect(valid_xml_id('foo<bar&>?')).to eq('foo&lt;bar_&gt;?')
    end

    it 'leaves valid characters untouched' do
      expect(valid_xml_id('aA1-?%$§{}[]\=|')).to eq('aA1-?%$§{}[]\=|')
    end
  end

  describe '#format_projectname' do
    it "shortens project pathes by replacing home projects with '~'" do
      expect(format_projectname("home:bob", "bob")).to eq("~")
      expect(format_projectname("home:alice", "bob")).to eq("~alice")
      expect(format_projectname("home:bob:foo", "bob")).to eq("~:foo")
      expect(format_projectname("home:alice:foo", "bob")).to eq("~alice:foo")
    end

    it "leaves projects that are no home projects untouched" do
      expect(format_projectname("some:project:foo:bar", "bob")).to eq("some:project:foo:bar")
    end
  end

  describe '#escape_nested_list' do
    it 'html escapes a string' do
      input = [['<p>home:Iggy</p>', '<p>This is a paragraph</p>'], ['<p>home:Iggy</p>', '<p>"This is a paragraph"</p>']]
      output = "['&lt;p&gt;home:Iggy&lt;\\/p&gt;', '&lt;p&gt;This is a paragraph&lt;\\/p&gt;'],\n"
      output += "['&lt;p&gt;home:Iggy&lt;\\/p&gt;', '&lt;p&gt;\\&quot;This is a paragraph\\&quot;&lt;\\/p&gt;']"

      expect(escape_nested_list(input)).to eq(output)
    end
  end
end
