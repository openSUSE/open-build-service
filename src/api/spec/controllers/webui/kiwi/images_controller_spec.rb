RSpec.describe Webui::Kiwi::ImagesController, :vcr do
  let(:project) { create(:project, name: 'fake_project') }
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:kiwi_image_with_package_with_kiwi_file) do
    create(:kiwi_image_with_package, name: 'package_with_valid_kiwi_file', project: user.home_project, with_kiwi_file: true)
  end

  describe 'GET #import_from_package' do
    include_context 'a kiwi image xml'
    include_context 'an invalid kiwi image xml'

    before do
      login user
    end

    context 'without a kiwi file' do
      let(:package) { create(:package, name: 'package_without_kiwi_file', project: project) }

      before do
        get :import_from_package, params: { package_id: package.id }
      end

      it { expect(response).to redirect_to(root_path) }
      it { expect(flash[:error]).to eq('There is no KIWI file') }
    end

    context 'with a kiwi file' do
      context 'that is a valid kiwi file' do
        let(:kiwi_image) do
          create(:kiwi_image_with_package, name: 'package_with_valid_kiwi_file', project: project, with_kiwi_file: true)
        end

        before do
          get :import_from_package, params: { package_id: kiwi_image.package.id }
        end

        it { expect(response).to redirect_to(kiwi_image_path(kiwi_image)) }
      end

      context 'that is an invalid kiwi file' do
        let(:package_with_kiwi_file) do
          create(:package_with_kiwi_file, name: 'package_with_invalid_kiwi_file', project: project, kiwi_file_content: invalid_kiwi_xml)
        end

        before do
          get :import_from_package, params: { package_id: package_with_kiwi_file.id }
        end

        it 'redirect to project_package_file_path' do
          expect(response).to redirect_to(project_package_file_path(project_name: package_with_kiwi_file.project,
                                                                    package_name: package_with_kiwi_file,
                                                                    filename: "#{package_with_kiwi_file.name}.kiwi"))
        end

        it { expect(flash[:error]).not_to be_nil }
      end

      context 'with source_path' do
        context 'with obsrepository' do
          let(:package_with_kiwi_file) do
            create(:package_with_kiwi_file, name: 'package_with_a_kiwi_file',
                                            project: project, kiwi_file_content: kiwi_xml_with_obsrepositories)
          end

          before do
            get :import_from_package, params: { package_id: package_with_kiwi_file.id }
          end

          it 'redirect to kiwi image show' do
            package_with_kiwi_file.reload
            expect(response).to redirect_to(kiwi_image_path(package_with_kiwi_file.kiwi_image))
          end
        end

        context 'with obsrepository and others' do
          let(:package_with_kiwi_file) do
            create(:package_with_kiwi_file, name: 'package_with_invalid_kiwi_file',
                                            project: project, kiwi_file_content: invalid_kiwi_xml_with_obsrepositories)
          end
          let(:errors) do
            {
              'Image Errors:' => [
                'A repository with source_path "obsrepositories:/" has been set. If you want to use it, please remove the other repositories',
                "Preferences can't be blank"
              ],
              title: "Kiwi File 'package_with_invalid_kiwi_file.kiwi' has errors:"
            }
          end

          before do
            get :import_from_package, params: { package_id: package_with_kiwi_file.id }
          end

          it 'redirect to project_package_file_path' do
            expect(response).to redirect_to(project_package_file_path(project_name: package_with_kiwi_file.project,
                                                                      package_name: package_with_kiwi_file,
                                                                      filename: "#{package_with_kiwi_file.name}.kiwi"))
          end

          it { expect(flash[:error]).to eq(errors) }
        end
      end

      context 'with multiple package_groups' do
        context 'with the same type' do
          let(:package_with_kiwi_file) do
            create(:package_with_kiwi_file, name: 'package_with_invalid_kiwi_file',
                                            project: project, kiwi_file_content: invalid_kiwi_xml_with_multiple_package_groups)
          end

          let(:errors) do
            [
              [:title, "Kiwi File 'package_with_invalid_kiwi_file.kiwi' has errors:"],
              [
                'Image Errors:',
                [
                  'Multiple package groups with same type and profiles are not allowed',
                  "Preferences can't be blank"
                ]
              ]
            ]
          end

          before do
            get :import_from_package, params: { package_id: package_with_kiwi_file.id }
          end

          it 'redirect to project_package_file_path' do
            expect(response).to redirect_to(project_package_file_path(project_name: package_with_kiwi_file.project,
                                                                      package_name: package_with_kiwi_file,
                                                                      filename: "#{package_with_kiwi_file.name}.kiwi"))
          end

          it { expect(flash[:error]).to match_array(errors) }
        end
      end
    end
  end

  describe 'GET #show' do
    before do
      login user
    end

    context 'json' do
      subject { get :show, params: { format: :json, id: kiwi_image_with_package_with_kiwi_file.id } }

      it { expect(subject.media_type).to eq('application/json') }
      it { expect(subject).to have_http_status(:success) }
    end

    context 'html' do
      subject { get :show, params: { id: kiwi_image_with_package_with_kiwi_file.id } }

      it { expect(subject).to have_http_status(:success) }
      it { expect(subject).to render_template(:show) }
    end
  end

  describe 'POST #update' do
    let(:kiwi_repository) { create(:kiwi_repository, image: kiwi_image_with_package_with_kiwi_file) }
    let(:kiwi_package_group) { create(:kiwi_package_group, kiwi_type: 'image', image: kiwi_image_with_package_with_kiwi_file) }
    let!(:kiwi_package) { create(:kiwi_package, package_group: kiwi_package_group, image: kiwi_image_with_package_with_kiwi_file) }

    before do
      login user
    end

    context 'with invalid repositories data' do
      subject! { post :update, params: invalid_repositories_update_params }

      let(:invalid_repositories_update_params) do
        {
          id: kiwi_image_with_package_with_kiwi_file.id,
          kiwi_image: {
            repositories_attributes: {
              '0' => {
                id: kiwi_repository.id,
                repo_type: 'apt2-deb',
                source_path: 'htt://example.com'
              }
            }
          }
        }
      end
      let(:errors) do
        {
          'Repository: htt://example.com' => [
            'Source path has an invalid format',
            "Repo type 'apt2-deb' is not included in the list"
          ],
          title: 'Cannot update KIWI Image:'
        }
      end

      it { expect(subject.request.flash[:error]).to eq(errors) }
      it { expect(subject).to have_http_status(:success) }
      it { expect(subject).to render_template(:edit) }
    end

    context 'with valid repositories data' do
      context 'without use_project_repositories' do
        let(:update_params) do
          {
            id: kiwi_image_with_package_with_kiwi_file.id,
            kiwi_image: { repositories_attributes: { '0' => {
              id: kiwi_repository.id,
              repo_type: 'apt-deb',
              priority: '',
              alias: '',
              source_path: 'http://',
              username: '',
              password: '',
              prefer_license: 0,
              imageinclude: 0,
              replaceable: 0
            } }, use_project_repositories: '0' }
          }
        end

        before do
          post :update, params: update_params
        end

        it { expect(response).to redirect_to(action: :edit) }
        it { expect(flash[:error]).to be_nil }
      end

      context 'with use_project_repositories' do
        let(:update_params) do
          {
            id: kiwi_image_with_package_with_kiwi_file.id,
            kiwi_image: { repositories_attributes: { '0' => {
              id: kiwi_repository.id,
              repo_type: 'apt-deb',
              priority: '',
              alias: '',
              source_path: 'http://',
              username: '',
              password: '',
              prefer_license: 0,
              imageinclude: 0,
              replaceable: 0
            } }, use_project_repositories: '1' }
          }
        end

        before do
          kiwi_repository
          post :update, params: update_params
        end

        it { expect(response).to redirect_to(action: :edit) }
        it { expect(kiwi_image_with_package_with_kiwi_file.repositories.count).to eq(0) }
        it { expect(flash[:error]).to be_nil }
      end
    end

    context 'with invalid package: empty name' do
      subject { post :update, params: invalid_packages_update_params }

      let(:invalid_packages_update_params) do
        {
          id: kiwi_image_with_package_with_kiwi_file.id,
          kiwi_image: {
            package_groups_attributes: {
              '0' => {
                id: kiwi_package.package_group.id,
                packages_attributes: {
                  '0' => {
                    id: kiwi_package.id,
                    name: '',
                    arch: 'x86'
                  }
                }
              }
            }
          }
        }
      end

      let(:errors) do
        {
          'Package: ' => ["Name can't be blank"],
          title: 'Cannot update KIWI Image:'
        }
      end

      it { expect(subject.request.flash[:error]).to eq(errors) }
      it { expect(subject).to have_http_status(:success) }
      it { expect(subject).to render_template(:edit) }
    end

    context 'with valid packages data' do
      let(:update_params) do
        {
          id: kiwi_image_with_package_with_kiwi_file.id,
          kiwi_image: {
            package_groups_attributes: {
              '0' => {
                id: kiwi_package.package_group.id,
                packages_attributes: {
                  '0' => {
                    id: kiwi_package.id,
                    name: kiwi_package.name,
                    arch: 'x86-876'
                  }
                }
              }
            }
          }
        }
      end

      before do
        post :update, params: update_params
        kiwi_package.reload
      end

      it { expect(response).to redirect_to(action: :edit) }
      it { expect(flash[:error]).to be_nil }
      it { expect(kiwi_package.arch).to eq('x86-876') }
    end
  end

  describe 'GET #autocomplete_binaries' do
    subject do
      get :autocomplete_binaries, params: { format: :json, id: kiwi_image_with_package_with_kiwi_file.id, term: term }
    end

    let(:binaries_available_sample) do
      { 'apache' => %w[i586 x86_64], 'apache2' => ['x86_64'],
        'appArmor' => %w[i586 x86_64], 'bcrypt' => ['x86_64'] }
    end

    let(:term) { '' }

    before do
      login user
      allow(Kiwi::Image).to receive(:binaries_available).and_return(binaries_available_sample)
    end

    it { expect(subject.media_type).to eq('application/json') }
    it { expect(subject).to have_http_status(:success) }

    it do
      expect(JSON.parse(subject.body)).to eq([{ 'id' => 'apache', 'label' => 'apache', 'value' => 'apache' },
                                              { 'id' => 'apache2', 'label' => 'apache2', 'value' => 'apache2' },
                                              { 'id' => 'appArmor', 'label' => 'appArmor', 'value' => 'appArmor' },
                                              { 'id' => 'bcrypt', 'label' => 'bcrypt', 'value' => 'bcrypt' }])
    end

    context 'for the term "ap"' do
      let(:term) { 'ap' }

      it do
        expect(JSON.parse(subject.body)).to eq([{ 'id' => 'apache', 'label' => 'apache', 'value' => 'apache' },
                                                { 'id' => 'apache2', 'label' => 'apache2', 'value' => 'apache2' },
                                                { 'id' => 'appArmor', 'label' => 'appArmor', 'value' => 'appArmor' }])
      end
    end

    context 'for the term "app"' do
      let(:term) { 'app' }

      it { expect(JSON.parse(subject.body)).to eq([{ 'id' => 'appArmor', 'label' => 'appArmor', 'value' => 'appArmor' }]) }
    end

    context 'for the term "b"' do
      let(:term) { 'b' }

      it { expect(JSON.parse(subject.body)).to eq([{ 'id' => 'bcrypt', 'label' => 'bcrypt', 'value' => 'bcrypt' }]) }
    end

    context 'for the term "c"' do
      let(:term) { 'c' }

      it { expect(JSON.parse(subject.body)).to be_empty }
    end
  end
end
