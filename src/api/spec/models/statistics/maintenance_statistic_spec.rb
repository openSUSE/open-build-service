RSpec.describe Statistics::MaintenanceStatistic do
  describe '.find_by_project' do
    context 'with a review assigned by a user' do
      subject(:maintenance_statistics) { Statistics::MaintenanceStatistic.find_by_project(project) }

      include_context 'a project with maintenance statistics'

      it 'contains issue_created' do
        expect(maintenance_statistics[-6].type).to eq(:issue_created)
        expect(maintenance_statistics[-6].when).to eq(issue.created_at)
      end

      it 'contains review_declined' do
        expect(maintenance_statistics[-5].type).to eq(:review_declined)
        expect(maintenance_statistics[-5].when).to eq(history_element_review_declined.created_at)
      end

      it 'contains review_opened' do
        expect(maintenance_statistics[-4].type).to eq(:review_opened)
        expect(maintenance_statistics[-4].when).to eq(review.created_at)
      end

      it 'contains release_request_request_accepted' do
        expect(maintenance_statistics[-3].type).to eq('release_request_accepted')
        expect(maintenance_statistics[-3].when).to eq(history_element_request_accepted.created_at)
        expect(maintenance_statistics[-3].request).to eq(bs_request.number)
      end

      it 'contains release_request_created' do
        expect(maintenance_statistics[-2].type).to eq(:release_request_created)
        expect(maintenance_statistics[-2].when).to eq(bs_request.created_at)
        expect(maintenance_statistics[-2].request).to eq(bs_request.number)
      end

      it 'contains project_created' do
        expect(maintenance_statistics[-1].type).to eq(:project_created)
        expect(maintenance_statistics[-1].when).to eq(project.created_at)
      end
    end

    context 'with a revoked bs_request' do
      subject(:maintenance_statistics) { Statistics::MaintenanceStatistic.find_by_project(project) }

      let(:user) { create(:confirmed_user) }
      let!(:project) do
        travel_to(10.days.ago) do
          create(
            :project_with_repository,
            name: 'ProjectWithRepo'
          )
        end
      end
      let!(:revoked_bs_request) do
        travel_to(9.days.ago) do
          create(
            :bs_request,
            source_project: project,
            type: 'maintenance_release'
          )
        end
      end
      let!(:revoked_history_element) do
        travel_to(8.days.ago) do
          create(
            :history_element_request_revoked,
            request: revoked_bs_request,
            user: user
          )
        end
      end
      let!(:accepted_bs_request) do
        travel_to(7.days.ago) do
          create(
            :bs_request,
            source_project: project,
            type: 'maintenance_release'
          )
        end
      end
      let!(:accepted_history_element) do
        travel_to(6.days.ago) do
          create(
            :history_element_request_accepted,
            request: accepted_bs_request,
            user: user
          )
        end
      end

      it 'contains release_request_request_accepted for accepted request' do
        expect(maintenance_statistics[0].type).to eq('release_request_accepted')
        expect(maintenance_statistics[0].when).to eq(accepted_history_element.created_at)
        expect(maintenance_statistics[0].request).to eq(accepted_bs_request.number)
      end

      it 'contains release_request_request_created for accepted request' do
        expect(maintenance_statistics[1].type).to eq(:release_request_created)
        expect(maintenance_statistics[1].when).to eq(accepted_bs_request.created_at)
        expect(maintenance_statistics[1].request).to eq(accepted_bs_request.number)
      end

      it 'contains release_request_revoked for revoked request' do
        expect(maintenance_statistics[2].type).to eq('release_request_revoked')
        expect(maintenance_statistics[2].when).to eq(revoked_history_element.created_at)
        expect(maintenance_statistics[2].request).to eq(revoked_bs_request.number)
      end

      it 'contains release_request_created for revoked request' do
        expect(maintenance_statistics[3].type).to eq(:release_request_created)
        expect(maintenance_statistics[3].when).to eq(revoked_bs_request.created_at)
        expect(maintenance_statistics[3].request).to eq(revoked_bs_request.number)
      end
    end

    context 'with a review by a group assigned to a user' do
      subject(:maintenance_statistics) { Statistics::MaintenanceStatistic.find_by_project(project) }

      let!(:user) { create(:confirmed_user) }
      let!(:group) { create(:group) }

      let!(:project) do
        travel_to(10.days.ago) do
          create(
            :project_with_repository,
            name: 'ProjectWithRepo'
          )
        end
      end
      let(:package) { create(:package, :as_submission_source, project: project) }
      let(:target_project) { create(:project) }
      let!(:bs_request) do
        travel_to(9.days.ago) do
          create(
            :bs_request,
            source_package: package,
            target_project: target_project,
            type: 'maintenance_release',
            creator: user
          )
        end
      end
      let!(:review) do
        travel_to(6.days.ago) do
          create(
            :review,
            bs_request: bs_request,
            by_group: group.title,
            state: :accepted
          )
        end
      end

      before do
        login(user)
        bs_request.assignreview(by_group: group.title, reviewer: user.login)
        new_review = Review.last
        create(
          :history_element_review_accepted,
          review: new_review,
          user: user,
          created_at: Faker::Time.forward(days: 2)
        )
        new_review.state = :accepted
        new_review.save!
      end

      it 'contains review_accepted for the review assigned to the user' do
        new_review = Review.last
        expect(maintenance_statistics[-4].type).to eq(:review_accepted)
        expect(maintenance_statistics[-4].when).to eq(new_review.accepted_at)
        expect(maintenance_statistics[-4].who).to eq(user.login)
      end

      it 'contains review_opened for the original review assigned to the group' do
        expect(maintenance_statistics[-3].type).to eq(:review_opened)
        expect(maintenance_statistics[-3].when).to eq(review.created_at)
        expect(maintenance_statistics[-3].who).to eq(user.login)
      end

      it 'contains release_request_created' do
        expect(maintenance_statistics[-2].type).to eq(:release_request_created)
        expect(maintenance_statistics[-2].when).to eq(bs_request.created_at)
      end

      it 'contains project_created' do
        expect(maintenance_statistics[-1].type).to eq(:project_created)
        expect(maintenance_statistics[-1].when).to eq(project.created_at)
      end
    end
  end
end
