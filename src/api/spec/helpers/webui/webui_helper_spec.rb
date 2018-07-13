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

  describe '#word_break' do
    it 'continuously adds tag after N characters' do
      expect(word_break('0123456789012345678901234567890123456789', 10)).to \
        eq('0123456789<wbr>0123456789<wbr>0123456789<wbr>0123456789')
    end

    it 'adds no tag if string is shorter than N characters' do
      expect(word_break('0123456789', 10)).to eq('0123456789')
    end

    it 'adds one tag if string is longer than N characters' do
      expect(word_break('01234567890', 10)).to eq('0123456789<wbr>0')
    end

    it 'does not evaluate HTML tags' do
      expect(word_break('01234<b>567</b>890', 3)).to eq('012<wbr>34&lt;<wbr>b&gt;5<wbr>67&lt;<wbr>/b&gt;<wbr>890')
    end

    it 'returns blank if no string given' do
      expect(word_break(nil, 3)).to eq('')
    end
  end

  describe '#repo_status_icon' do
    it 'renders icon' do
      blocked = repo_status_icon('blocked')
      expect(blocked).to include('icons-time')
      expect(blocked).to include('No build possible atm')
    end

    it 'renders outdated icon' do
      outdated_scheduling = repo_status_icon('outdated_scheduling')
      expect(outdated_scheduling).to include('icons-cog_error')
      expect(outdated_scheduling).to include('state is being calculated')
      expect(outdated_scheduling).to include('needs recalculations')
    end

    it 'renders unknown icon' do
      undefined_icon = repo_status_icon('undefined')
      expect(undefined_icon).to include('icons-eye')
      expect(undefined_icon).to include('Unknown state')
    end
  end

  describe '#get_frontend_url_for' do
    it 'generates a url' do
      url = get_frontend_url_for(controller: 'foo', host: 'bar.com', port: 80, protocol: 'http')
      expect(url).to eq('http://bar.com:80/foo')
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
      expected_url = 'https://bugzilla.example.org/enter_bug.cgi?' +
                     @expected_attributes.map { |key, value| "#{key}=#{value}" }.join('&')
      expect(bugzilla_url).to eq(expected_url)
    end

    it 'adds an assignee and description if parameters where given' do
      expected_attributes = @expected_attributes.clone
      expected_attributes[:short_desc] = 'some_description'
      expected_attributes[:assigned_to] = 'assignee@example.org'

      expected_url = 'https://bugzilla.example.org/enter_bug.cgi?' +
                     expected_attributes.map { |key, value| "#{key}=#{value}" }.join('&')
      expect(bugzilla_url(['assignee@example.org'], 'some_description')).to eq(expected_url)
    end
  end

  describe '#format_projectname' do
    it "shortens project pathes by replacing home projects with '~'" do
      expect(format_projectname('home:bob', 'bob')).to eq('~')
      expect(format_projectname('home:alice', 'bob')).to eq('~alice')
      expect(format_projectname('home:bob:foo', 'bob')).to eq('~:foo')
      expect(format_projectname('home:alice:foo', 'bob')).to eq('~alice:foo')
    end

    it 'leaves projects that are no home projects untouched' do
      expect(format_projectname('some:project:foo:bar', 'bob')).to eq('some:project:foo:bar')
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

  describe '#sprited_text' do
    it 'returns a img element with a matching icon class and title attribute and text' do
      expect(sprited_text('brick_edit', 'Edit description')).to eq('<img title="Edit description" ' \
                       'class="icons-brick_edit" alt="Edit description" src="/images/s.gif" /> Edit description')
      expect(sprited_text('user_add', 'Request role addition')).to eq('<img title="Request role addition" ' \
                       'class="icons-user_add" alt="Request role addition" src="/images/s.gif" /> Request role addition')
    end
  end

  describe '#remove_dialog_tag' do
    it "generates a link element and uses it's parameter as text field" do
      expect(remove_dialog_tag('Some text')).to eq(
        '<a title="Close" id="remove_dialog" class="close-dialog" href="#">Some text</a>'
      )
      expect(remove_dialog_tag('Some other text')).to eq(
        '<a title="Close" id="remove_dialog" class="close-dialog" href="#">Some other text</a>'
      )
    end
  end

  describe '#remove_dialog_tag' do
    it "generates a 'pre' element and uses it's parameter as text field" do
      expect(description_wrapper('some description')).to eq(
        '<pre id="description-text" class="plain">some description</pre>'
      )
      expect(description_wrapper('some other description')).to eq(
        '<pre id="description-text" class="plain">some other description</pre>'
      )
    end
  end

  describe '#possibly_empty_ul' do
    context 'if the block is not blank' do
      before do
        @cont = proc { 'some content' }
      end

      it "embeds content returned by a block in an 'ul' element" do
        expect(possibly_empty_ul({}, &@cont)).to eq('<ul>some content</ul>')
      end

      it "applies parameters as attributes to an 'ul' element" do
        html_options = { class: 'list', id: 'my-list' }
        expect(possibly_empty_ul(html_options, &@cont)).to eq('<ul class="list" id="my-list">some content</ul>')
      end

      it 'ignores a possible fallback parameter' do
        html_options = { class: 'list', fallback: '<p><i>fallback</i></p>' }
        expect(possibly_empty_ul(html_options, &@cont)).to eq('<ul class="list">some content</ul>')
      end
    end

    context 'if the block is blank' do
      before do
        @cont = proc { '' }
      end

      context 'and a fallback option is given' do
        before do
          @html_options = { class: 'list', fallback: '<p><i>fallback</i></p>' }
        end

        it { expect(possibly_empty_ul(@html_options, &@cont)).to eq('<p><i>fallback</i></p>') }
      end

      context 'and no fallback option is given' do
        it { expect(possibly_empty_ul({}, &@cont)).to be nil }
      end
    end
  end

  describe '#is_advanced_tab?' do
    advanced_tabs = ['prjconf', 'index', 'meta', 'status']
    advanced_tabs.each do |action|
      context "current action is '#{action}'" do
        before do
          allow(controller).to receive(:action_name).and_return(action)
        end

        it { expect(is_advanced_tab?).to be true }
      end
    end

    context "current action is not within #{advanced_tabs}" do
      before do
        allow(controller).to receive(:action_name).and_return('some_action')
      end

      it { expect(is_advanced_tab?).to be false }
    end
  end

  describe '#next_codemirror_uid' do
    before do
      @codemirror_editor_setup = 0
    end

    after do
      @codemirror_editor_setup = 0
    end

    it { expect(next_codemirror_uid).to be_instance_of(Integer) }

    context "if next_codemirror_uid get's called the first time" do
      it { expect(next_codemirror_uid).to eq(1) }
    end

    context 'if next_codemirror_uid has been called before' do
      before do
        next_codemirror_uid
      end

      it 'increases @codemirror_editor_setup by 1' do
        expect(next_codemirror_uid).to eq(2)
        expect(next_codemirror_uid).to eq(3)
      end
    end
  end

  describe '#can_register' do
    context 'current user is admin' do
      before do
        User.current = create(:admin_user)
      end

      it { expect(can_register).to be(true) }
    end

    context 'user is not registered' do
      before do
        User.current = create(:user)
        allow(UnregisteredUser).to receive(:can_register?).and_raise(APIException)
      end

      it { expect(can_register).to be(false) }
    end

    context 'user is registered' do
      it { expect(can_register).to be(true) }
    end
  end

  describe '#repo_status_icon' do
    skip('Please add some tests')
  end

  describe '#tab' do
    skip('Please add some tests')
  end

  describe '#render_dialog' do
    skip('Please add some tests')
  end

  describe '#project_or_package_link' do
    skip('Please add some tests')
  end

  describe '#creator_intentions' do
    it 'do not show the requester if he is the same as the creator' do
      expect(creator_intentions(nil)).to eq 'become bugowner (previous bugowners will be deleted)'
    end

    it 'show the requester if he is different as the creator' do
      expect(creator_intentions('bugowner')).to eq 'get the role bugowner'
    end
  end

  describe '#codemirror_style' do
    context 'option height' do
      it 'uses auto as default value' do
        expect(codemirror_style).not_to include('height')
      end

      it 'get set properly' do
        expect(codemirror_style(height: '250px')).to include('height: 250px;')
      end
    end

    context 'option width' do
      it 'uses auto as default value' do
        expect(codemirror_style).not_to include('width')
      end

      it 'get set properly' do
        expect(codemirror_style(width: '250px')).to include('width: 250px;')
      end
    end

    context 'option border' do
      it 'does not remove border' do
        expect(codemirror_style).not_to include('border-width')
      end

      it 'removes the border if in read-only mode' do
        expect(codemirror_style(read_only: true)).to include('border-width')
      end

      it 'removes the border if no_border is set' do
        expect(codemirror_style(no_border: true)).to include('border-width')
      end
    end
  end

  describe '#package_link' do
    skip('Please add some tests')
  end

  describe '#replace_jquery_meta_characters' do
    context 'with meta character in string' do
      it { expect(replace_jquery_meta_characters('openSUSE_Leap_42.2')).to eq('openSUSE_Leap_42_2') }
      it { expect(replace_jquery_meta_characters('openSUSE.Leap.42.2')).to eq('openSUSE_Leap_42_2') }
      it { expect(replace_jquery_meta_characters('openSUSE_Leap_42\2')).to eq('openSUSE_Leap_42_2') }
      it { expect(replace_jquery_meta_characters('openSUSE_Leap_42/2')).to eq('openSUSE_Leap_42_2') }
    end

    context 'without meta character in string' do
      it { expect(replace_jquery_meta_characters('openSUSE_Tumbleweed')).to eq('openSUSE_Tumbleweed') }
    end
  end

  describe '#toggle_sliced_text' do
    let(:short_text) { 'short_text' }
    let(:big_text) { 'big_text_' * 100 }
    let(:sliced_text) { big_text.slice(0, 50) }

    context 'with nil as text' do
      it { expect(toggle_sliced_text(nil)).to be_nil }
    end

    context 'with a short text' do
      it { expect(toggle_sliced_text(short_text)).to eq(short_text) }
    end

    context 'with a big text' do
      it { expect(toggle_sliced_text(big_text)).to match(/(.+)#{sliced_text}(.+)\[\+\](.+)#{big_text}(.+)\[\-\](.+)/) }
    end
  end
end
