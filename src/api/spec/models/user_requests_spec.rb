RSpec.describe User do
  let(:admin_user) { create(:admin_user, login: 'king') }
  let(:user) { create(:user, login: 'eisendieter') }
  let(:confirmed_user) { create(:confirmed_user, login: 'confirmed_user') }
  let(:input) { { 'Event::RequestCreate' => { source_maintainer: '1' } } }
  let(:project_with_package) { create(:project_with_package, name: 'project_b') }

  describe '#requests' do
    shared_examples 'all_my_requests' do
      subject { confirmed_user.requests }

      let(:source_package) { create(:package, :as_submission_source) }

      let!(:maintained_request) do
        create(:bs_request_with_submit_action,
               target_package: target_package,
               source_package: source_package,
               creator: admin_user)
      end

      let!(:not_maintained_request) do
        create(:bs_request_with_submit_action,
               target_package: not_maintained_target_package,
               source_package: source_package,
               creator: admin_user)
      end

      let(:target_package) { create(:package) }
      let!(:relationship_project_user) { create(:relationship_project_user, user: confirmed_user, project: target_package.project) }
      let!(:relationship_package_user) { create(:relationship_package_user, user: confirmed_user, package: target_package) }

      let(:not_maintained_target_package) { create(:package) }
      let!(:relationship_project_admin) { create(:relationship_project_user, user: admin_user, project: target_package.project) }

      before do
        # Setting state in create will be overwritten by BsRequest#sanitize!
        # so we need to set it to review afterwards
        [subject_request, request_with_same_creator_and_reviewer, request_of_another_subject].each do |request|
          request.state = BsRequest::VALID_REQUEST_STATES.sample
          request.save
        end
      end

      it 'Include reviews where the user is not the creator of the request' do
        expect(subject).to include(subject_request)
      end

      it 'Include reviews where the user is the creator of the request' do
        expect(subject).to include(request_with_same_creator_and_reviewer)
      end

      it 'does include requests of maintained subject' do
        expect(subject).to include(maintained_request)
      end

      it 'does not include requests of not maintained subject' do
        expect(subject).not_to include(not_maintained_request)
      end

      it 'does include requests of not maintained subject by created by the same' do
        expect(admin_user.requests).to include(maintained_request) # not maintained for admin_user
      end

      it 'returns the request if the search does match' do
        expect(confirmed_user.requests(admin_user.login)).to include(subject_request)
      end

      it 'returns no request if the search does not match' do
        expect(confirmed_user.requests('does not exist')).not_to include(subject_request)
      end

      it 'does include requests if search does match' do
        expect(confirmed_user.requests(admin_user.login)).to include(maintained_request)
      end

      it 'does nots include requests if search does not match' do
        expect(confirmed_user.requests('does not exist')).not_to include(maintained_request)
      end
    end

    context 'with by_user reviews' do
      it_behaves_like 'all_my_requests' do
        let!(:subject_request) { create(:set_bugowner_request, creator: admin_user, review_by_user: confirmed_user) }
        let!(:request_with_same_creator_and_reviewer) { create(:set_bugowner_request, creator: confirmed_user, review_by_user: confirmed_user) }

        let(:other_project) { create(:project) }
        let!(:request_of_another_subject) { create(:set_bugowner_request, creator: confirmed_user, review_by_user: admin_user) }

        it 'Include reviews where the user is the creator of the request' do
          expect(subject).to include(request_of_another_subject)
        end
      end
    end

    context 'with by_group reviews' do
      it_behaves_like 'all_my_requests' do
        let(:group) { create(:group) }
        let!(:groups_user) { create(:groups_user, user: confirmed_user, group: group) }

        let!(:subject_request) { create(:set_bugowner_request, creator: admin_user, review_by_group: group) }
        let!(:request_with_same_creator_and_reviewer) { create(:set_bugowner_request, creator: confirmed_user, review_by_group: group) }

        let(:other_group) { create(:group) }
        let!(:request_of_another_subject) { create(:set_bugowner_request, creator: admin_user, review_by_group: other_group) }

        it 'not include reviews where the user is the creator of the request' do
          expect(subject).not_to include(request_of_another_subject)
        end
      end
    end

    context 'with by_project reviews' do
      it_behaves_like 'all_my_requests' do
        let(:project) { create(:project) }
        let!(:relationship_project_user) { create(:relationship_project_user, user: confirmed_user, project: project) }

        let!(:subject_request) { create(:set_bugowner_request, creator: admin_user, review_by_project: project) }

        let!(:request_with_same_creator_and_reviewer) { create(:set_bugowner_request, creator: confirmed_user, review_by_project: project) }

        let(:other_project) { create(:project) }
        let!(:request_of_another_subject) { create(:set_bugowner_request, creator: admin_user, review_by_project: other_project) }

        it 'not include reviews where the user is the creator of the request' do
          expect(subject).not_to include(request_of_another_subject)
        end
      end
    end

    context 'with by_package reviews' do
      it_behaves_like 'all_my_requests' do
        let(:package) { create(:package) }
        let!(:relationship_package_user) { create(:relationship_package_user, user: confirmed_user, package: package) }

        let!(:subject_request) { create(:set_bugowner_request, creator: admin_user, review_by_package: package) }

        let!(:request_with_same_creator_and_reviewer) { create(:set_bugowner_request, creator: confirmed_user, review_by_package: package) }

        let(:other_package) { create(:package) }
        let!(:request_of_another_subject) { create(:set_bugowner_request, creator: admin_user, review_by_package: other_package) }

        it 'not include reviews where the user is the creator of the request' do
          expect(subject).not_to include(request_of_another_subject)
        end
      end
    end
  end

  describe '#declined_requests' do
    subject { confirmed_user.declined_requests }

    let(:target_package) { create(:package) }
    let(:source_package) { create(:package, :as_submission_source) }
    let!(:new_bs_request) { create(:set_bugowner_request, creator: confirmed_user) }
    let!(:declined_bs_request) do
      create(:declined_bs_request,
             target_package: target_package,
             source_package: source_package,
             creator: confirmed_user)
    end
    let!(:admin_bs_request) do
      create(:declined_bs_request,
             target_package: target_package,
             source_package: source_package,
             creator: admin_user)
    end

    it 'does include requests created by the user and in state :declined' do
      expect(subject).to include(declined_bs_request)
    end

    it 'does include requests with matching search parameter' do
      expect(confirmed_user.declined_requests('confirmed_user')).to include(declined_bs_request)
    end

    it 'does not include requests with not matching search parameter' do
      expect(confirmed_user.declined_requests('not-existent')).not_to include(declined_bs_request)
    end

    it 'does not include requests created by any other user' do
      expect(subject).not_to include(admin_bs_request)
    end

    it 'does not include requests in any other state except :declined' do
      expect(subject).not_to include(new_bs_request)
    end
  end

  describe '#outgoing_requests' do
    subject { confirmed_user.outgoing_requests }

    let(:target_package) { create(:package) }
    let(:source_package) { create(:package) }
    let!(:new_bs_request) { create(:set_bugowner_request, creator: confirmed_user) }
    let!(:review_bs_request) do
      create(:bs_request_with_submit_action,
             target_package: target_package,
             source_package: source_package,
             creator: confirmed_user,
             review_by_user: admin_user)
    end
    let!(:declined_bs_request) do
      create(:declined_bs_request,
             target_package: target_package,
             source_package: source_package,
             creator: confirmed_user)
    end
    let!(:admin_bs_request) do
      create(:bs_request_with_submit_action,
             target_package: target_package,
             source_package: source_package,
             creator: admin_user)
    end

    it 'does include requests created by the user and in state :new' do
      expect(subject).to include(new_bs_request)
    end

    it 'does include requests created by the user and in state :review' do
      expect(subject).to include(review_bs_request)
    end

    it 'does include requests with matching search parameter' do
      expect(confirmed_user.outgoing_requests('confirmed_user')).to include(new_bs_request)
    end

    it 'does not include requests with not matching search parameter' do
      expect(confirmed_user.outgoing_requests('not-existent')).not_to include(new_bs_request)
    end

    it 'does not include requests created by any other user' do
      expect(subject).not_to include(admin_bs_request)
    end

    it 'does not include requests in any other state except :new or :review' do
      expect(subject).not_to include(declined_bs_request)
    end
  end

  describe '#incoming_requests' do
    shared_examples 'incoming_requests' do
      subject { confirmed_user.incoming_requests }

      let(:source_package) { create(:package, :as_submission_source) }

      let!(:maintained_request) do
        create(:bs_request_with_submit_action,
               target_package: target_package,
               source_package: source_package,
               creator: admin_user)
      end

      let!(:declined_bs_request) do
        create(:declined_bs_request,
               target_package: target_package,
               source_package: source_package,
               creator: admin_user)
      end

      let!(:not_maintained_request) do
        create(:bs_request_with_submit_action,
               target_package: not_maintained_target_package,
               source_package: source_package,
               creator: admin_user)
      end

      it 'does include requests of maintained subject' do
        expect(subject).to include(maintained_request)
      end

      it 'does not include requests of not maintained subject' do
        expect(subject).not_to include(not_maintained_request)
      end

      it 'does not include requests in any other state expect new' do
        maintained_request.state = :review
        maintained_request.save
        expect(subject).not_to include(maintained_request)
      end

      it 'does include requests if search does match' do
        expect(confirmed_user.incoming_requests(admin_user.login)).to include(maintained_request)
      end

      it 'does nots include requests if search does not match' do
        expect(confirmed_user.incoming_requests('does not exist')).not_to include(maintained_request)
      end
    end

    context 'with maintained project' do
      it_behaves_like 'incoming_requests' do
        let(:target_package) { create(:package) }
        let!(:relationship_project_user) { create(:relationship_project_user, user: confirmed_user, project: target_package.project) }

        let(:not_maintained_target_package) { create(:package) }
        let!(:relationship_project_admin) { create(:relationship_project_user, user: admin_user, project: target_package.project) }
      end
    end

    context 'with maintained package' do
      it_behaves_like 'incoming_requests' do
        let(:target_package) { create(:package) }
        let!(:relationship_package_user) { create(:relationship_package_user, user: confirmed_user, package: target_package) }

        let(:not_maintained_target_package) { create(:package) }
        let!(:relationship_package_admin) { create(:relationship_package_user, user: admin_user, package: target_package) }
      end
    end
  end
end
