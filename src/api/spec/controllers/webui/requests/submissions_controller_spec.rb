RSpec.describe Webui::Requests::SubmissionsController, :vcr do
  let(:user) { create(:confirmed_user, :with_home, login: 'tom') }
  let(:source_project) { user.home_project }
  let(:source_package) { create(:package_with_file, name: 'package_with_file', project: source_project) }
  let(:target_project) { create(:project) }

  describe 'POST #create' do
    let(:target_package) { source_package.name }
    let(:bs_request_action) do
      BsRequestActionSubmit.where(target_project: target_project.name, target_package: target_package)
    end

    RSpec.shared_examples 'a response of a successful submit request' do
      # it { expect(flash[:success]).to match("Created .+submit request \\d.+to .+#{target_project}") }
      it { expect(response).to redirect_to(request_show_path(bs_request_action.first.bs_request.number)) }
      it { expect(bs_request_action).to exist }
    end

    before do
      login(user)
    end

    context 'sending a valid submit request' do
      before do
        post :create, params: {
          project_name: source_project.name,
          package_name: source_package.name,
          bs_request: {
            bs_request_actions_attributes: {
              '0' => {
                target_project: target_project.name,
                source_project: source_project.name,
                target_package: source_package.name,
                source_package: source_package.name,
                type: 'submit'
              }
            }
          }
        }
      end

      it_behaves_like 'a response of a successful submit request'
    end

    context 'sending a valid submit request with targetpackage as parameter' do
      let(:target_package) { 'different_package' }

      before do
        post :create, params: {
          project_name: source_project.name,
          package_name: source_package.name,
          bs_request: {
            bs_request_actions_attributes: {
              '0' => {
                target_project: target_project.name,
                source_project: source_project.name,
                target_package: target_package,
                source_package: source_package.name,
                type: 'submit'
              }
            }
          }
        }
      end

      it_behaves_like 'a response of a successful submit request'
    end

    context "sending a valid submit request with 'sourceupdate' parameter" do
      before do
        post :create, params: {
          project_name: source_project.name,
          package_name: source_package.name,
          bs_request: {
            bs_request_actions_attributes: {
              '0' => {
                target_project: target_project.name,
                source_project: source_project.name,
                target_package: source_package.name,
                source_package: source_package.name,
                type: 'submit',
                sourceupdate: 'update'
              }
            }
          }
        }
      end

      it_behaves_like 'a response of a successful submit request'

      it 'creates a submit request with correct sourceupdate attibute' do
        created_request = BsRequestActionSubmit.where(target_project: target_project.name, target_package: target_package).first
        expect(created_request.sourceupdate).to eq('update')
      end
    end

    context 'superseeding a request that does not exist' do
      before do
        post :create, params: {
          project_name: source_project.name,
          package_name: source_package.name,
          bs_request: {
            bs_request_actions_attributes: {
              '0' => {
                target_project: target_project.name,
                source_project: source_project.name,
                target_package: source_package.name,
                source_package: source_package.name,
                type: 'submit'
              }
            }
          },
          supersede_request_numbers: [42]
        }
      end

      it { expect(flash[:error]).to match("Superseding failed: Couldn't find request with id '42'") }
    end

    context 'having whitespaces in parameters' do
      before do
        post :create, params: {
          project_name: " #{source_project} ",
          package_name: " #{source_package} ",
          bs_request: {
            bs_request_actions_attributes: {
              '0' => {
                source_project: " #{source_project} ",
                source_package: " #{source_package} ",
                target_project: " #{target_project} ",
                type: 'submit'
              }
            }
          }
        }
      end

      it_behaves_like 'a response of a successful submit request'
    end

    context 'sending a submit request for an older submission' do
      before do
        3.times { |i| Backend::Connection.put("/source/#{source_project}/#{source_package}/somefile.txt", i.to_s) }
        post :create, params: {
          project_name: source_project.name,
          package_name: source_package.name,
          bs_request: {
            bs_request_actions_attributes: {
              '0' => {
                source_project: source_project.name,
                source_package: source_package.name,
                target_project: target_project,
                type: 'submit',
                source_rev: 2
              }
            }
          }
        }
      end

      it_behaves_like 'a response of a successful submit request'

      it 'creates a submit request for the correct revision' do
        expect(BsRequestActionSubmit.where(
                 source_project: source_project.name,
                 source_package: source_package.name,
                 target_project: target_project.name,
                 target_package: source_package.name,
                 type: 'submit',
                 source_rev: 2
               )).to exist
      end
    end

    context 'not successful' do
      before do
        Backend::Connection.put("/source/#{source_project}/#{source_package}/_link", "<link project='/Invalid'/>")
        post :create, params: {
          project_name: source_project.name,
          package_name: source_package.name,
          bs_request: {
            bs_request_actions_attributes: {
              '0' => {
                source_project: source_project.name,
                source_package: source_package.name,
                target_project: target_project,
                type: 'submit'
              }
            }
          }
        }
      end

      it { expect(flash[:error]).to eq("Unable to submit. The project '#{source_project}' was not found") }
      it { expect(response).to redirect_to(package_show_path(project: source_project, package: source_package)) }
      it { expect(BsRequestActionSubmit.where(target_project: target_project.name, target_package: source_package.name)).not_to exist }
    end

    context 'a submit request that fails due to validation errors' do
      before do
        login(user)
        post :create, params: {
          project_name: source_project,
          package_name: source_package,
          bs_request: {
            bs_request_actions_attributes: {
              '0' => {
                target_project: target_project
              }
            }
          }
        }
      end

      it do
        expect(flash[:error]).to eq('Validation failed: Bs request actions type can\'t be blank, ' \
                                    'Bs request actions Type can\'t be blank')
      end

      it { expect(response).to redirect_to(package_show_path(project: source_project.name, package: source_package.name)) }
      it { expect(BsRequestActionSubmit.where(target_project: target_project.name, target_package: source_package.name)).not_to exist }
    end

    context 'unchanged sources' do
      before do
        post :create, params: {
          project_name: source_project,
          package_name: source_package,
          bs_request: {
            bs_request_actions_attributes: {
              '0' => {
                source_project: source_project,
                source_package: source_package,
                target_project: source_project,
                target_package: source_package,
                type: 'submit'
              }
            }
          }
        }
      end

      it { expect(flash[:error]).to eq('Unable to submit, sources are unchanged') }
      it { expect(response).to redirect_to(package_show_path(project: source_project, package: source_package)) }
      it { expect(BsRequestActionSubmit.where(target_project: source_project.name, target_package: source_package.name)).not_to exist }
    end
  end
end
