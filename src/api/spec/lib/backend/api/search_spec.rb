RSpec.describe Backend::Api::Search, :vcr do
  describe '.projects' do
    context 'with projects' do
      subject { Backend::Api::Search.projects(project_names) }

      let(:project_names) { create_list(:project, 2) { |prj, i| prj.name = "foo_#{i}" }.map(&:name) }

      it { expect(Nokogiri::XML(subject).xpath('//collection//project').count).to eq(2) }
    end

    context 'no projects' do
      subject { Backend::Api::Search.projects([]) }

      it { expect(Nokogiri::XML(subject).xpath('//collection//project').count).to eq(0) }
    end

    context 'with unexistent projects' do
      subject { Backend::Api::Search.projects(%w[xaa xee]) }

      it { expect(Nokogiri::XML(subject).xpath('//collection//project').count).to eq(0) }
    end
  end
end
