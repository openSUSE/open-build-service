require 'rails_helper'

RSpec.describe WorkerStatus do
  describe '.hidden' do
    before do
      allow(Backend::Api::BuildResults::Worker).to receive(:status).and_return(xml_response)
    end

    subject { Xmlhash.parse(WorkerStatus.hidden.to_xml) }

    context 'no hidden project' do
      let(:project) { create(:project_with_repository, name: 'openSUSE:Factory') }
      let(:xml_response) do
        <<-HEREDOC
          <workerstatus clients="1">
          <building workerid="build01/2" hostarch="i586" project="#{project.name}" repository="nada" package="bdpack" arch="i586" starttime="0" />
          <waiting arch="i586" jobs="1" />
          <buildavg arch="i586" buildavg="1200" />
          <partition>
            <daemon type="scheduler" arch="i586" state="dead">
            <queue high="0" med="0" low="3" next="0" />
            </daemon>
            <daemon type="publisher" state="dead" />
          </partition>
          </workerstatus>
        HEREDOC
      end

      it { expect(subject['building']['project']).to eq(project.name) }
    end

    context 'XPATH filter matches more projects' do
      let(:xml_response) do
        <<-HEREDOC
          <workerstatus clients="1">
          <building workerid="build01/2" hostarch="i586" project="BinaryprotectedProject" repository="nada" package="bdpack" arch="i586" starttime="0" />
          <waiting arch="i586" jobs="1" />
          <buildavg arch="i586" buildavg="1200" />
          <partition>
            <daemon type="scheduler" arch="i586" state="dead">
            <queue high="0" med="0" low="3" next="0" />
            </daemon>
            <daemon type="publisher" state="dead" />
          </partition>
          </workerstatus>
        HEREDOC
      end

      it { expect(subject['building']['project']).to eq('---') }
    end

    context 'project name is hidden' do
      let(:xml_response) do
        <<-HEREDOC
          <workerstatus clients="1">
          <building workerid="build01/2" hostarch="i586" project="BinaryprotectedProject" repository="nada" package="bdpack" arch="i586" starttime="0" />
          <building workerid="build01/3" hostarch="i586" project="BinaryprotectedProject" repository="nada" package="bdpack" arch="i586" starttime="0" />
          <building workerid="build01/4" hostarch="i586" project="BinaryprotectedProject" repository="nada" package="bdpack" arch="i586" starttime="0" />
          <building workerid="build01/5" hostarch="i586" project="BinaryprotectedProject" repository="nada" package="bdpack" arch="i586" starttime="0" />
          <waiting arch="i586" jobs="1" />
          <buildavg arch="i586" buildavg="1200" />
          <partition>
            <daemon type="scheduler" arch="i586" state="dead">
            <queue high="0" med="0" low="3" next="0" />
            </daemon>
            <daemon type="publisher" state="dead" />
          </partition>
          </workerstatus>
        HEREDOC
      end

      it { expect(subject['building'].count).to eq(4) }
      it { expect(subject['building'].map { |x| x['project'] }).to all(eq('---')) }
    end
  end
end
