RSpec.describe Staging::StagedRequests, :vcr do
  subject do
    Staging::StagedRequests.new(request_numbers: [bs_request.number],
                                staging_workflow: staging_workflow,
                                staging_project: staging_project,
                                user_login: factory_manager.login)
  end

  let(:submitter) { create(:confirmed_user) }
  let(:maintainer) { create(:confirmed_user, login: 'dimstar') }
  let(:source_project) { create(:project, name: 'devel:something', maintainer: submitter) }
  let(:target_project) { create(:project, name: 'openSUSE:Factory', reviewer: managers_group, maintainer: maintainer) }
  let(:source_package) { create(:package_with_file, name: 'source_package', project: source_project, file_content: 'b') }
  let(:target_package) { create(:package_with_file, name: 'target_package', project: target_project, file_content: 'a') }

  let(:managers_group) do
    group = create(:group, title: 'factory-staging')
    group.add_user(create(:confirmed_user, login: 'ana'))
    group
  end
  let(:factory_manager) { managers_group.users.first }
  let(:staging_project) { create(:project, name: 'openSUSE:Factory:Staging:A', maintainer: managers_group) }
  let!(:staging_workflow) { create(:staging_workflow, project: target_project, managers_group: managers_group, staging_projects: [staging_project]) }
  let!(:bs_request) { create(:bs_request_with_submit_action, creator: submitter, source_package: source_package, target_package: target_package) }

  describe '#create' do
    before do
      User.session = factory_manager
    end

    it 'does not change the state of the request' do
      expect { subject.destroy }.not_to(change(bs_request, :state))
    end

    it 'creates a package in the staging project' do
      expect { subject.create! }.to change { staging_project.packages.count }.from(0).to(1)
    end

    it 'adds the request to the staging project' do
      expect { subject.create! }.to change { staging_project.staged_requests.count }.from(0).to(1)
      expect(staging_project.staged_requests).to include(bs_request)
    end

    it 'adds a review for the staging project' do
      expect { subject.create! }.to change { bs_request.reviews.count }.from(1).to(2)
      expect(bs_request.reviews.find_by(by_project: staging_project.name).state).to eq(:new)
    end

    it 'accepts the review for the staging managers' do
      expect { subject.create! }.not_to(change { bs_request.reviews.where(by_group: managers_group.title).count })
      expect(bs_request.reviews.find_by(by_group: managers_group.title).state).to eq(:accepted)
    end
  end

  describe '#destroy' do
    before do
      User.session = factory_manager
      subject.create!
    end

    it 'does not change the state of the request' do
      expect { subject.destroy }.not_to(change(bs_request, :state))
    end

    it 'deletes the package in the staging project' do
      expect { subject.destroy }.to change { staging_project.packages.count }.from(1).to(0)
    end

    it 'removes the request from the staging project' do
      expect { subject.destroy }.to change { staging_project.staged_requests.count }.from(1).to(0)
    end

    it 'accepts the review for the staging project' do
      expect { subject.destroy }.to change { bs_request.reviews.find_by(by_project: staging_project.name).state }.from(:new).to(:accepted)
    end

    it 'creates the review for the staging managers' do
      expect { subject.destroy }.to change { bs_request.reviews.count }.from(2).to(3)
      expect(bs_request.reviews.find_by(by_group: managers_group.title).state).to eq(:accepted)
    end

    context 'for a declined request' do
      before do
        User.session = maintainer
        bs_request.change_state(newstate: 'declined', comment: 'I do not like this request')
        User.session = factory_manager
      end

      it 'does not change the state of the request' do
        expect { subject.destroy }.not_to(change(bs_request, :state))
      end

      it 'accepts the review for the staging project' do
        expect { subject.destroy }.to change { bs_request.reviews.find_by(by_project: staging_project.name).state }.from(:new).to(:accepted)
      end

      it 'creates the review for the staging managers' do
        expect { subject.destroy }.to change { bs_request.reviews.count }.from(2).to(3)
        expect(bs_request.reviews.find_by(by_group: managers_group.title).state).to eq(:accepted)
      end
    end
  end
end
