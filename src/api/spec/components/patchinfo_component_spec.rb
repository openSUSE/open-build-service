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
      </patchinfo>'
    end

    before do
      render_inline(described_class.new(patchinfo_text, 'path-to-request-changes'))
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
        <category>recommended</category>
        <rating>low</rating>
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

    it do
      expect(rendered_content).not_to have_text('Affected binaries')
    end

    it do
      expect(rendered_content).not_to have_text('Affected packages')
    end

    it do
      expect(rendered_content).not_to have_text('Issues related to the patch')
    end

    it do
      expect(rendered_content).not_to have_text('Targeted for release in the following projects')
    end
  end
end
