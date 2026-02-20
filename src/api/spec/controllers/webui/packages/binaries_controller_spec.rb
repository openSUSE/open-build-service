require 'webmock/rspec'

RSpec.describe Webui::Packages::BinariesController, :vcr do
  let(:tom) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:home_tom) { tom.home_project }
  let(:toms_package) { create(:package, name: 'my_package', project: home_tom) }
  let(:repo_for_home_tom) do
    repo = create(:repository, project: home_tom, architectures: ['x86_64'], name: 'source_repo')
    home_tom.store(login: tom)
    repo
  end

  describe 'GET #index' do
    before do
      login tom
    end

    context 'with a failure in the backend' do
      before do
        allow(Backend::Api::BuildResults::Status).to receive(:result_swiss_knife).and_raise(Backend::Error, 'fake message')
        get :index, params: { package_name: toms_package, project_name: home_tom, repository_name: repo_for_home_tom }
      end

      it { expect(flash[:error]).to eq('There has been an internal error. Please try again.') }
      it { expect(response).to redirect_to(root_path) }
    end

    context 'without build results' do
      before do
        allow(Backend::Api::BuildResults::Status).to receive(:result_swiss_knife).and_raise(Backend::NotFoundError)
      end

      let(:set_binaries) { get :index, params: { package_name: toms_package, project_name: home_tom, repository_name: repo_for_home_tom } }

      it { expect { set_binaries }.to raise_error(ActiveRecord::RecordNotFound) }
    end

    context 'with valid build results' do
      let(:fake_buildresult) do
        Xmlhash.parse(
          "<resultlist state='123'>
             <result project='#{home_tom.name}' repository='#{repo_for_home_tom.name}' arch='x86_64' state='succeeded'>
               <binarylist>
                 <binary filename='test1.rpm' size='1024'/>
                 <binary filename='_statistics' size='0'/>
               </binarylist>
             </result>
             <result project='#{home_tom.name}' repository='#{repo_for_home_tom.name}' arch='i586' state='building'>
               <binarylist>
                 <binary filename='test2.rpm' size='2048'/>
               </binarylist>
             </result>
           </resultlist>"
        )
      end

      before do
        allow(Buildresult).to receive(:find_hashed).and_return(fake_buildresult)
        allow(Backend::Api::BuildResults::Binaries).to receive(:download_url_for_file).and_return('http://test.host/download')
        get :index, params: { package_name: toms_package, project_name: home_tom, repository_name: repo_for_home_tom }
      end

      it { expect(response).to have_http_status(:success) }

      it 'assigns @binaries' do
        expect(assigns(:binaries).first[:filename]).to eq('test1.rpm')
        expect(assigns(:binaries).last[:filename]).to eq('test2.rpm')
      end

      it 'assigns @binaries_by_arch correctly' do
        expect(assigns(:binaries_by_arch)['x86_64'].first[:filename]).to eq('test1.rpm')
        expect(assigns(:binaries_by_arch)['i586'].first[:filename]).to eq('test2.rpm')
      end

      it 'assigns @repository_statistics correctly' do
        expect(assigns(:repository_statistics)['x86_64'][:has_statistics]).to be true
        expect(assigns(:repository_statistics)['i586'][:has_statistics]).to be false
      end

      it 'ensures binary size is an integer' do
        expect(assigns(:binaries).first[:size]).to be_an(Integer)
        expect(assigns(:binaries).first[:size]).to eq(1024)
      end
    end
  end

  describe 'GET #show' do
    let(:architecture) { 'x86_64' }
    let(:package_binaries_page) { project_package_repository_binaries_path(package_name: toms_package, project_name: home_tom, repository_name: repo_for_home_tom) }
    let(:fake_fileinfo) { { sumary: 'fileinfo', description: 'fake' } }

    before do
      login tom
    end

    context 'with a failure in the backend' do
      subject do
        get :show, params: { package_name: toms_package,
                             project_name: home_tom,
                             repository_name: repo_for_home_tom,
                             arch: 'x86_64',
                             filename: 'filename.txt' }
      end

      before do
        allow(Backend::Api::BuildResults::Binaries).to receive(:fileinfo).and_raise(Backend::Error, 'fake message')
      end

      it { expect(response).to have_http_status(:success) }

      it 'shows an error message' do
        subject
        expect(flash[:error]).to eq('There has been an internal error. Please try again.')
      end
    end

    context 'without file info' do
      subject do
        get :show, params: { package_name: toms_package,
                             project_name: home_tom,
                             repository_name: repo_for_home_tom,
                             arch: 'x86_64',
                             filename: 'filename.txt' }
      end

      before do
        allow(Backend::Api::BuildResults::Binaries).to receive(:fileinfo).and_return(nil)
      end

      it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
    end

    context 'with a valid download url' do
      before do
        # We want to use the backend path here
        allow(Backend::Api::BuildResults::Binaries).to receive_messages(fileinfo: fake_fileinfo, download_url_for_file: nil)
      end

      context 'and normal html request' do
        before do
          get :show, params: { package_name: toms_package, project_name: home_tom, repository_name: repo_for_home_tom, arch: 'x86_64', filename: 'filename.txt', format: :html }
        end

        it { expect(response).to have_http_status(:success) }
        it { expect(assigns(:download_url)).to eq('/build/home:tom/source_repo/x86_64/my_package/filename.txt') }
      end

      context 'and a non html request' do
        before do
          get :show, params: { package_name: toms_package, project_name: home_tom, repository_name: repo_for_home_tom, arch: 'x86_64', filename: 'filename.txt' }
        end

        it { expect(response).to have_http_status(:redirect) }
        it { is_expected.to redirect_to('http://test.host/build/home:tom/source_repo/x86_64/my_package/filename.txt') }
      end
    end
  end

  describe 'GET #dependencies' do
    let(:fake_fileinfo) { { summary: 'fileinfo', description: 'fake', provides_ext: [], requires_ext: [] } }

    before do
      login tom
    end

    context 'with valid params' do
      before do
        allow(Backend::Api::BuildResults::Binaries).to receive(:fileinfo_ext).and_return(fake_fileinfo)
        get :dependencies, params: { package_name: toms_package, project_name: home_tom, repository_name: repo_for_home_tom, arch: 'x86_64', binary_filename: 'test.rpm' }
      end

      it { expect(response).to have_http_status(:success) }
      it { expect(assigns(:fileinfo)).to eq(fake_fileinfo) }
    end

    context 'without file info' do
      subject do
        get :dependencies, params: { package_name: toms_package, project_name: home_tom, repository_name: repo_for_home_tom, arch: 'x86_64', binary_filename: 'nonexistent.rpm' }
      end

      before do
        allow(Backend::Api::BuildResults::Binaries).to receive(:fileinfo_ext).and_return(nil)
      end

      it { expect { subject }.to raise_error(ActiveRecord::RecordNotFound) }
    end
  end
end
