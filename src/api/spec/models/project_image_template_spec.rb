require 'webmock/rspec'

RSpec.describe Project do
  describe '.remote_image_templates' do
    subject { Project.remote_image_templates }

    let!(:remote_instance) { create(:project, name: 'RemoteProject', remoteurl: 'http://example.com/public') }

    before do
      stub_request(:get, 'http://example.com/public/image_templates.xml')
        .and_return(body: %(<image_template_projects>
                              <image_template_project name='Images'>
                                <image_template_package>
                                  <name>leap-42-1-jeos</name>
                                   <title/>
                                    <description/>
                                </image_template_package>
                              </image_template_project>
                          </image_template_projects>
                         ))
    end

    it { expect(subject.class).to eq(Array) }

    context 'with one remote instance' do
      context 'and one package' do
        it { expect(subject.length).to eq(1) }
        it { expect(subject.first.name).to eq('RemoteProject:Images') }
        it { expect(subject.first.packages.first.name).to eq('leap-42-1-jeos') }
      end

      context 'and two projects' do
        before do
          stub_request(:get, 'http://example.com/public/image_templates.xml')
            .and_return(body: %(<image_template_projects>
                              <image_template_project name='Images'>
                                <image_template_package>
                                  <name>leap-42-1-jeos</name>
                                   <title/>
                                    <description/>
                                </image_template_package>
                              </image_template_project>
                              <image_template_project name='Foobar'>
                                <image_template_package>
                                  <name>leap-42-2-jeos</name>
                                   <title/>
                                    <description/>
                                </image_template_package>
                              </image_template_project>
                          </image_template_projects>
                         ))
        end

        it { expect(subject.length).to eq(2) }
        it { expect(subject.second.name).to eq('RemoteProject:Foobar') }
        it { expect(subject.second.packages.first.name).to eq('leap-42-2-jeos') }
      end

      context 'and two packages' do
        before do
          stub_request(:get, 'http://example.com/public/image_templates.xml')
            .and_return(body: %(<image_template_projects>
                              <image_template_project name='Images'>
                                <image_template_package>
                                  <name>leap-42-1-jeos</name>
                                   <title/>
                                    <description/>
                                </image_template_package>
                                <image_template_package>
                                  <name>leap-42-2-jeos</name>
                                   <title/>
                                    <description/>
                                </image_template_package>
                              </image_template_project>
                          </image_template_projects>
                         ))
        end

        it { expect(subject.first.packages.length).to eq(2) }
        it { expect(subject.first.packages.second.name).to eq('leap-42-2-jeos') }
      end
    end

    context 'with two remote instances' do
      # The AnotherRemoteProject will simply take the request of RemoteInstance defined in the first before filter
      let!(:another_remote_instance) { create(:project, name: 'AnotherRemoteProject', remoteurl: 'http://example.com/public') }

      it { expect(subject.length).to eq(2) }
      it { expect(subject.second.name).to eq('AnotherRemoteProject:Images') }
      it { expect(subject.second.packages.first.name).to eq('leap-42-1-jeos') }
    end
  end
end
