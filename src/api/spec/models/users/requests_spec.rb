# frozen_string_literal: true
require 'rails_helper'

RSpec.describe User do
  let(:admin_user) { create(:admin_user, login: 'king') }
  let(:user) { create(:user, login: 'eisendieter') }
  let(:confirmed_user) { create(:confirmed_user, login: 'confirmed_user') }
  let(:input) { { 'Event::RequestCreate' => { source_maintainer: '1' } } }
  let(:project_with_package) { create(:project_with_package, name: 'project_b') }

  describe '#requests' do
    shared_examples 'all_my_requests' do
      let(:source_package) { create(:package) }

      let!(:maintained_request) do
        create(:bs_request_with_submit_action,
               target_project: target_package.project,
               target_package: target_package,
               source_project: source_package.project,
               source_package: source_package,
               creator: admin_user.login)
      end

      let!(:not_maintained_request) do
        create(:bs_request_with_submit_action,
               target_project: not_maintained_target_package.project,
               target_package: not_maintained_target_package,
               source_project: source_package.project,
               source_package: source_package,
               creator: admin_user.login)
      end

      let(:target_package) { create(:package) }
      let!(:relationship_project_user) { create(:relationship_project_user, user: confirmed_user, project: target_package.project) }
      let!(:relationship_package_user) { create(:relationship_package_user, user: confirmed_user, package: target_package) }

      let(:not_maintained_target_package) { create(:package) }
      let!(:relationship_project_admin) { create(:relationship_project_user, user: admin_user, project: target_package.project) }

      subject { confirmed_user.requests }

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
        let(:subject_request) { create(:bs_request, creator: admin_user.login) }
        let!(:subject_review) { create(:review, by_user: confirmed_user.login, bs_request: subject_request) }

        let(:request_with_same_creator_and_reviewer) { create(:bs_request, creator: confirmed_user.login) }
        let!(:review_with_same_creator_and_reviewer) do
          create(:review, by_user: confirmed_user.login, bs_request: request_with_same_creator_and_reviewer)
        end

        let(:other_project) { create(:project) }
        let(:request_of_another_subject) { create(:bs_request, creator: confirmed_user.login) }
        let!(:review_of_another_subject) { create(:review, by_user: admin_user.login, bs_request: request_of_another_subject) }

        it 'Include reviews where the user is the creator of the request' do
          expect(subject).to include(request_of_another_subject)
        end
      end
    end

    context 'with by_group reviews' do
      it_behaves_like 'all_my_requests' do
        let(:group) { create(:group) }
        let!(:groups_user) { create(:groups_user, user: confirmed_user, group: group) }

        let(:subject_request) { create(:bs_request, creator: admin_user.login) }
        let!(:subject_review) { create(:review, by_group: group.title, bs_request: subject_request) }

        let(:request_with_same_creator_and_reviewer) { create(:bs_request, creator: confirmed_user.login) }
        let!(:review_with_same_creator_and_reviewer) { create(:review, by_group: group.title, bs_request: request_with_same_creator_and_reviewer) }

        let(:other_group) { create(:group) }
        let(:request_of_another_subject) { create(:bs_request, creator: admin_user.login) }
        let!(:review_of_another_subject) { create(:review, by_group: other_group.title, bs_request: request_of_another_subject) }

        it 'not include reviews where the user is the creator of the request' do
          expect(subject).not_to include(request_of_another_subject)
        end
      end
    end

    context 'with by_project reviews' do
      it_behaves_like 'all_my_requests' do
        let(:project) { create(:project) }
        let!(:relationship_project_user) { create(:relationship_project_user, user: confirmed_user, project: project) }

        let(:subject_request) { create(:bs_request, creator: admin_user.login) }
        let!(:subject_review) { create(:review, by_project: project.name, bs_request: subject_request) }

        let(:request_with_same_creator_and_reviewer) { create(:bs_request, creator: confirmed_user.login) }
        let!(:review_with_same_creator_and_reviewer) { create(:review, by_project: project.name, bs_request: request_with_same_creator_and_reviewer) }

        let(:other_project) { create(:project) }
        let(:request_of_another_subject) { create(:bs_request, creator: admin_user.login) }
        let!(:review_of_another_subject) { create(:review, by_project: other_project.name, bs_request: request_of_another_subject) }

        it 'not include reviews where the user is the creator of the request' do
          expect(subject).not_to include(request_of_another_subject)
        end
      end
    end

    context 'with by_package reviews' do
      it_behaves_like 'all_my_requests' do
        let(:package) { create(:package) }
        let!(:relationship_package_user) { create(:relationship_package_user, user: confirmed_user, package: package) }

        let(:subject_request) { create(:bs_request, creator: admin_user.login) }
        let!(:subject_review) { create(:review, by_project: package.project.name, by_package: package.name, bs_request: subject_request) }

        let(:request_with_same_creator_and_reviewer) { create(:bs_request, creator: confirmed_user.login) }
        let!(:review_with_same_creator_and_reviewer) do
          create(:review, by_project: package.project.name, by_package: package.name, bs_request: request_with_same_creator_and_reviewer)
        end

        let(:other_package) { create(:package) }
        let(:request_of_another_subject) { create(:bs_request, creator: admin_user.login) }
        let!(:review_of_another_subject) do
          create(:review, by_project: other_package.project.name, by_package: other_package.name, bs_request: request_of_another_subject)
        end

        it 'not include reviews where the user is the creator of the request' do
          expect(subject).not_to include(request_of_another_subject)
        end
      end
    end
  end

  describe '#declined_requests' do
    let(:target_package) { create(:package) }
    let(:source_package) { create(:package) }
    let(:confirmed_user) { create(:confirmed_user, login: 'confirmed_user') }
    let!(:new_bs_request) { create(:bs_request, creator: confirmed_user) }
    let!(:declined_bs_request) do
      create(:declined_bs_request,
             target_project: target_package.project,
             target_package: target_package,
             source_project: source_package.project,
             source_package: source_package,
             creator: confirmed_user)
    end
    let!(:admin_bs_request) do
      create(:declined_bs_request,
             target_project: target_package.project,
             target_package: target_package,
             source_project: source_package.project,
             source_package: source_package,
             creator: admin_user)
    end

    subject { confirmed_user.declined_requests }

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
    let(:target_package) { create(:package) }
    let(:source_package) { create(:package) }
    let(:confirmed_user) { create(:confirmed_user, login: 'confirmed_user') }
    let!(:new_bs_request) { create(:bs_request, creator: confirmed_user) }
    let!(:review_bs_request) do
      create(:review_bs_request,
             target_project: target_package.project,
             target_package: target_package,
             source_project: source_package.project,
             source_package: source_package,
             creator: confirmed_user,
             reviewer: admin_user)
    end
    let!(:declined_bs_request) do
      create(:declined_bs_request,
             target_project: target_package.project,
             target_package: target_package,
             source_project: source_package.project,
             source_package: source_package,
             creator: confirmed_user)
    end
    let!(:admin_bs_request) do
      create(:bs_request,
             target_project: target_package.project,
             target_package: target_package,
             source_project: source_package.project,
             source_package: source_package,
             creator: admin_user)
    end

    subject { confirmed_user.outgoing_requests }

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
    let(:confirmed_user) { create(:confirmed_user, login: 'confirmed_user') }

    shared_examples 'incoming_requests' do
      let(:source_package) { create(:package) }

      let!(:maintained_request) do
        create(:bs_request_with_submit_action,
               target_project: target_package.project,
               target_package: target_package,
               source_project: source_package.project,
               source_package: source_package,
               creator: admin_user.login)
      end

      let!(:not_maintained_request) do
        create(:bs_request_with_submit_action,
               target_project: not_maintained_target_package.project,
               target_package: not_maintained_target_package,
               source_project: source_package.project,
               source_package: source_package,
               creator: admin_user.login)
      end

      subject { confirmed_user.incoming_requests }

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

  describe '#requests' do
    shared_examples 'all_my_requests' do
      let(:source_package) { create(:package) }

      let!(:maintained_request) do
        create(:bs_request_with_submit_action,
               target_project: target_package.project,
               target_package: target_package,
               source_project: source_package.project,
               source_package: source_package,
               creator: admin_user.login)
      end

      let!(:not_maintained_request) do
        create(:bs_request_with_submit_action,
               target_project: not_maintained_target_package.project,
               target_package: not_maintained_target_package,
               source_project: source_package.project,
               source_package: source_package,
               creator: admin_user.login)
      end

      let(:target_package) { create(:package) }
      let!(:relationship_project_user) { create(:relationship_project_user, user: confirmed_user, project: target_package.project) }
      let!(:relationship_package_user) { create(:relationship_package_user, user: confirmed_user, package: target_package) }

      let(:not_maintained_target_package) { create(:package) }
      let!(:relationship_project_admin) { create(:relationship_project_user, user: admin_user, project: target_package.project) }

      subject { confirmed_user.requests }

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
        let(:subject_request) { create(:bs_request, creator: admin_user.login) }
        let!(:subject_review) { create(:review, by_user: confirmed_user.login, bs_request: subject_request) }

        let(:request_with_same_creator_and_reviewer) { create(:bs_request, creator: confirmed_user.login) }
        let!(:review_with_same_creator_and_reviewer) do
          create(:review, by_user: confirmed_user.login, bs_request: request_with_same_creator_and_reviewer)
        end

        let(:other_project) { create(:project) }
        let(:request_of_another_subject) { create(:bs_request, creator: confirmed_user.login) }
        let!(:review_of_another_subject) { create(:review, by_user: admin_user.login, bs_request: request_of_another_subject) }

        it 'Include reviews where the user is the creator of the request' do
          expect(subject).to include(request_of_another_subject)
        end
      end
    end

    context 'with by_group reviews' do
      it_behaves_like 'all_my_requests' do
        let(:group) { create(:group) }
        let!(:groups_user) { create(:groups_user, user: confirmed_user, group: group) }

        let(:subject_request) { create(:bs_request, creator: admin_user.login) }
        let!(:subject_review) { create(:review, by_group: group.title, bs_request: subject_request) }

        let(:request_with_same_creator_and_reviewer) { create(:bs_request, creator: confirmed_user.login) }
        let!(:review_with_same_creator_and_reviewer) { create(:review, by_group: group.title, bs_request: request_with_same_creator_and_reviewer) }

        let(:other_group) { create(:group) }
        let(:request_of_another_subject) { create(:bs_request, creator: admin_user.login) }
        let!(:review_of_another_subject) { create(:review, by_group: other_group.title, bs_request: request_of_another_subject) }

        it 'not include reviews where the user is the creator of the request' do
          expect(subject).not_to include(request_of_another_subject)
        end
      end
    end

    context 'with by_project reviews' do
      it_behaves_like 'all_my_requests' do
        let(:project) { create(:project) }
        let!(:relationship_project_user) { create(:relationship_project_user, user: confirmed_user, project: project) }

        let(:subject_request) { create(:bs_request, creator: admin_user.login) }
        let!(:subject_review) { create(:review, by_project: project.name, bs_request: subject_request) }

        let(:request_with_same_creator_and_reviewer) { create(:bs_request, creator: confirmed_user.login) }
        let!(:review_with_same_creator_and_reviewer) { create(:review, by_project: project.name, bs_request: request_with_same_creator_and_reviewer) }

        let(:other_project) { create(:project) }
        let(:request_of_another_subject) { create(:bs_request, creator: admin_user.login) }
        let!(:review_of_another_subject) { create(:review, by_project: other_project.name, bs_request: request_of_another_subject) }

        it 'not include reviews where the user is the creator of the request' do
          expect(subject).not_to include(request_of_another_subject)
        end
      end
    end

    context 'with by_package reviews' do
      it_behaves_like 'all_my_requests' do
        let(:package) { create(:package) }
        let!(:relationship_package_user) { create(:relationship_package_user, user: confirmed_user, package: package) }

        let(:subject_request) { create(:bs_request, creator: admin_user.login) }
        let!(:subject_review) { create(:review, by_project: package.project.name, by_package: package.name, bs_request: subject_request) }

        let(:request_with_same_creator_and_reviewer) { create(:bs_request, creator: confirmed_user.login) }
        let!(:review_with_same_creator_and_reviewer) do
          create(:review, by_project: package.project.name, by_package: package.name, bs_request: request_with_same_creator_and_reviewer)
        end

        let(:other_package) { create(:package) }
        let(:request_of_another_subject) { create(:bs_request, creator: admin_user.login) }
        let!(:review_of_another_subject) do
          create(:review, by_project: other_package.project.name, by_package: other_package.name, bs_request: request_of_another_subject)
        end

        it 'not include reviews where the user is the creator of the request' do
          expect(subject).not_to include(request_of_another_subject)
        end
      end
    end
  end
end
