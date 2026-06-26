RSpec.describe Distribution do
  let(:admin) { create(:admin_user) }
  let(:distribution) { create(:distribution) }
  let(:distribution_xml) do
    '<distribution vendor="opensuse" version="Tumbleweed" id="90409">
      <name>openSUSE Tumbleweed</name>
      <project>openSUSE:Factory</project>
      <reponame>openSUSE_Tumbleweed</reponame>
      <repository>snapshot</repository>
      <link>http://www.opensuse.org/</link>
      <icon width="8" height="8" url="https://static.opensuse.org/distributions/logos/opensuse.png"/>
      <icon width="16" height="16" url="https://static.opensuse.org/distributions/logos/opensuse.png"/>
      <architecture>i586</architecture>
      <architecture>x86_64</architecture>
    </distribution>'
  end

  describe '#new_from_xmlhash' do
    subject { Distribution.new_from_xmlhash(xmlhash) }

    context 'parses xml' do
      let(:xmlhash) { Xmlhash.parse(distribution_xml) }

      it { is_expected.to be_a(Distribution) }
      it { expect(subject.vendor).to eq('opensuse') }
    end

    context 'returns an empty instance without input' do
      let(:xmlhash) { nil }

      it { is_expected.to be_a(Distribution) }
      it { expect(subject.vendor).to be_nil }
    end
  end

  describe '.update_from_xmlhash' do
    subject { distribution.update_from_xmlhash(xmlhash) }

    let(:distribution_id) { distribution.id }
    let(:xmlhash) { Xmlhash.parse(distribution_xml) }

    it 'updates other attributes' do
      subject
      expect(distribution.vendor).to eq('opensuse')
    end

    it 'never updates the id attribute' do
      subject
      expect(distribution.id).to eq(distribution_id)
    end
  end
end
