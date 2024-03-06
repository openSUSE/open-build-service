RSpec.describe PatchinfoComponent, type: :component do
  let!(:user) { create(:user, :with_home, login: 'tom') }

  context 'with one tag per type' do
    let(:patchinfo_text) do
      '<patchinfo>
        <category>recommended</category>
        <rating>low</rating>
        <packager>tom</packager>
        <summary/>
        <description/>
        <binary>binary_001</binary>
        <package>package_a</package>
        <issue tracker="cve" id="2023-1111"/>
        <releasetarget project="openSUSE:Factory" repository="15.4" />
        <retracted>1</retracted>
        <stopped>1</stopped>
        <reboot_needed>1</reboot_needed>
        <relogin_needed></relogin_needed>
        <zypp_restart_needed/>
      </patchinfo>'
    end

    before do
      render_inline(described_class.new(patchinfo_text, 'path-to-request-changes'))
    end

    it 'displays a badge for the category' do
      expect(rendered_content).to have_css('span.badge.text-bg-info', text: 'Recommended')
    end

    it 'displays a badge for the rating' do
      expect(rendered_content).to have_css('span.badge.text-bg-secondary', text: 'Low priority')
    end

    it 'displays a badge for the retracted element when it is present' do
      expect(rendered_content).to have_css('span.badge.text-bg-danger', text: 'Retracted')
    end

    it 'displays a badge for the stopped element when it is present' do
      expect(rendered_content).to have_css('span.badge.text-bg-danger', text: 'Stopped')
    end

    it 'displays a badge for properties' do
      %w[reboot_needed relogin_needed zypp_restart_needed].each do |property|
        expect(rendered_content).to have_css('span.badge.text-bg-info', text: property)
      end
    end

    it do
      expect(rendered_content).to have_text('Affected binaries')
    end

    it do
      expect(rendered_content).to have_css('li', text: 'binary_001')
    end

    it do
      expect(rendered_content).to have_text('2023-1111')
    end

    it do
      expect(rendered_content).to have_text('Affected packages')
    end

    it do
      expect(rendered_content).to have_text('package_a')
    end

    it do
      expect(rendered_content).to have_text('Targeted for release in the following projects')
    end

    it do
      expect(rendered_content).to have_text('openSUSE:Factory')
    end

    it do
      expect(rendered_content).to have_text('15.4')
    end
  end

  context 'with multiple tags per type' do
    let(:patchinfo_text) do
      '<patchinfo>
        <category>feature</category>
        <rating>critical</rating>
        <packager>tom</packager>
        <summary/>
        <description/>
        <package>package_a</package>
        <package>package_b</package>
        <binary>binary_001</binary>
        <binary>binary_002</binary>
        <issue tracker="cve" id="2023-1111"/>
        <issue tracker="cve" id="2023-2222"/>
        <releasetarget project="openSUSE:Factory" repository="15.4" />
        <releasetarget project="openSUSE:Factory" repository="15.5" />
      </patchinfo>'
    end

    before do
      render_inline(described_class.new(patchinfo_text, 'path-to-request-changes'))
    end

    it 'displays a badge for the category' do
      expect(rendered_content).to have_css('span.badge.text-bg-success', text: 'Feature')
    end

    it 'displays a badge for the rating' do
      expect(rendered_content).to have_css('span.badge.text-bg-danger', text: 'Critical priority')
    end

    it do
      expect(rendered_content).to have_text('Affected binaries')
    end

    it do
      expect(rendered_content).to have_text('binary_001').and(have_text('binary_002'))
    end

    it do
      expect(rendered_content).to have_text('Issues related to the patch')
    end

    it do
      expect(rendered_content).to have_text('2023-1111').and(have_text('2023-2222'))
    end

    it do
      expect(rendered_content).to have_text('Affected packages')
    end

    it do
      expect(rendered_content).to have_text('package_a').and(have_text('package_b'))
    end

    it do
      expect(rendered_content).to have_text('Targeted for release in the following projects')
    end

    it do
      expect(rendered_content).to have_text('openSUSE:Factory')
    end

    it do
      expect(rendered_content).to have_text('15.4').and(have_text('15.5'))
    end
  end

  context 'with missing tags' do
    let(:patchinfo_text) do
      '<patchinfo>
        <category>recommended</category>
        <rating>low</rating>
        <packager>tom</packager>
        <summary/>
        <description/>
      </patchinfo>'
    end

    before do
      render_inline(described_class.new(patchinfo_text, 'path-to-request-changes'))
    end

    it 'does not display a badge for the retracted element when it is missing' do
      expect(rendered_content).to have_no_css('span.badge.text-bg-danger', text: 'Retracted')
    end

    it 'does not display a badge for the stopped element when it is missing' do
      expect(rendered_content).to have_no_css('span.badge.text-bg-danger', text: 'Stopped')
    end

    it 'does not display a badge for properties when they are missing' do
      %w[reboot_needed relogin_needed zypp_restart_needed].each do |property|
        expect(rendered_content).to have_no_css('span.badge.text-bg-info', text: property)
      end
    end

    it do
      expect(rendered_content).to have_no_text('Affected binaries')
    end

    it do
      expect(rendered_content).to have_no_text('Affected packages')
    end

    it do
      expect(rendered_content).to have_no_text('Issues related to the patch')
    end

    it do
      expect(rendered_content).to have_no_text('Targeted for release in the following projects')
    end
  end
end
