RSpec.describe WorkerStatus do
  before do
    Rails.cache.write('workerstatus', xml_response)
  end

  describe '.hidden' do
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
      it { expect(subject['building'].pluck('project')).to all(eq('---')) }
    end
  end

  describe '#save' do
    subject { WorkerStatus.new.save }

    let(:xml_response) do
      <<-HEREDOC
      <workerstatus clients="285">
        <idle workerid="build24/7" hostarch="x86_64"/>
        <building repository="openSUSE_11.3_Update" arch="x86_64" project="home:enzokiel" package="android-sdk" starttime="1289838671" workerid="build03/1" hostarch="x86_64"/>
        <building repository="openSUSE_11.2" arch="i586" project="KDE:KDE3" package="desktoptext-config" starttime="1289899573" workerid="build03/2" hostarch="x86_64"/>
        <building repository="openSUSE_11.1" arch="i586" project="home:frispete:gimp" package="xsane" starttime="1289918108" workerid="build03/3" hostarch="x86_64"/>
        <waiting jobs="2160" arch="i586"/>
        <waiting jobs="1" arch="local"/>
        <waiting jobs="2013" arch="x86_64"/>
        <blocked jobs="7215" arch="i586"/>
        <blocked jobs="3" arch="local"/>
        <blocked jobs="5855" arch="x86_64"/>
        <buildavg arch="i586" buildavg="7853.49900157855"/>
        <buildavg arch="local" buildavg="6706.03274513389"/>
        <buildavg arch="x86_64" buildavg="6313.8886610886"/>
        <partition>
        <daemon type="scheduler" arch="i586" starttime="1288252359" state="running">
        <queue med="68" high="4" next="9730" low="760"/>
        </daemon>
        <daemon type="scheduler" arch="local" starttime="1288252359" state="running">
        <queue med="0" high="0" next="0" low="0"/>
        </daemon>
        <daemon type="scheduler" arch="x86_64" starttime="1288252359" state="running">
        <queue med="69" high="0" next="7409" low="4690"/>
        </daemon>
        <daemon type="dispatcher" starttime="1289593678" state="running"/>
        <daemon type="publisher" starttime="1287910270" state="running"/>
        <daemon type="signer" starttime="1289913427" state="running"/>
        <daemon type="warden" starttime="1287910269" state="running"/>
        </partition>
      </workerstatus>
      HEREDOC
    end

    it { expect { subject }.to change(StatusHistory, :count).from(0).to(23) }
  end
end
