require 'rails_helper'
require Rails.root.join('db/data/20190116105222_sanitize_reviews.rb')

RSpec.describe SanitizeReviews, type: :migration do
  let(:data_migration) { SanitizeReviews.new }

  describe 'up' do
    let(:package_a) { create(:package) }
    let(:package_b) { create(:package) }
    let(:package_c) { create(:package) }
    let(:group_a) { create(:group) }
    let(:group_c) { create(:group) }
    let(:user_b) { create(:confirmed_user) }
    let(:user_c) { create(:confirmed_user) }
    let!(:review_a) do
      review = build(:review,
                     by_package: package_a.name, package: package_a,
                     by_project: package_a.project.name, project: package_a.project,
                     by_group: group_a.title, group: group_a)
      review.save(validate: false)
      review
    end
    let!(:review_b) do
      review = build(:review,
                     by_package: package_b.name, package: package_b,
                     by_project: package_b.project.name, project: package_b.project,
                     by_user: user_b.login, user: user_b)
      review.save(validate: false)
      review
    end
    let!(:review_c) do
      review = build(:review,
                     by_package: package_c.name, package: package_c,
                     by_project: package_c.project.name, project: package_c.project,
                     by_group: group_c.title, group: group_c,
                     by_user: user_c.login, user: user_c)
      review.save(validate: false)
      review
    end

    subject { data_migration.up }

    it 'migrates all data' do
      expect { subject }.to change(Review, :count).by(4)
      expect(Review.where(package: package_a, project: package_a.project, group: nil, user: nil)).to exist
      expect(Review.where(package: nil, project: nil, group: group_a, user: nil)).to exist
      expect(Review.where(package: package_b, project: package_b.project, group: nil, user: nil)).to exist
      expect(Review.where(package: nil, project: nil, group: nil, user: user_b)).to exist
      expect(Review.where(package: package_c, project: package_c.project, group: nil, user: nil)).to exist
      expect(Review.where(package: nil, project: nil, group: nil, user: user_c)).to exist
      expect(Review.where(package: nil, project: nil, group: group_c, user: nil)).to exist
    end
  end
end
