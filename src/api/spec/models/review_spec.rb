RSpec.shared_context 'some assigned reviews and some unassigned reviews' do
  let(:review_assigned1)   { create(:review, by_user: user.login, bs_request: bs_request) }
  let(:review_assigned2)   { create(:review, by_user: user.login, bs_request: bs_request) }
  let(:review_unassigned1) { create(:review, by_user: user.login, bs_request: bs_request) }
  let(:review_unassigned2) { create(:review, by_user: user.login, bs_request: bs_request) }

  let!(:history_element1) do
    create(:history_element_review_assigned, op_object_id: review_assigned1.id, user_id: user.id)
  end
  let!(:history_element2) do
    create(:history_element_review_assigned, op_object_id: review_assigned2.id, user_id: user.id)
  end
  let!(:history_element3) do
    create(:history_element_review_accepted, op_object_id: review_assigned2.id, user_id: user.id)
  end
  let!(:history_element4) do
    create(:history_element_review_accepted, op_object_id: review_unassigned1.id, user_id: user.id)
  end
end

RSpec.describe Review do
  let(:project) { create(:project_with_package, name: 'Apache', package_name: 'apache2') }
  let(:package) { project.packages.first }
  let(:user) { create(:user, login: 'King') }
  let(:group) { create(:group, title: 'Staff') }
  let(:confirmed_user) { create(:confirmed_user) }
  let(:bs_request) { create(:bs_request_with_submit_action, creator: confirmed_user) }

  it { is_expected.to belong_to(:bs_request).touch(true).optional }

  describe 'validations' do
    it 'is not allowed to specify by_user and any other reviewable' do
      %i[by_group by_project by_package].each do |reviewable|
        review = Review.create(:by_user => user.login, reviewable => 'not-existent-reviewable')
        expect(review.errors.messages[:base])
          .to eq(['it is not allowed to have more than one reviewer entity: by_user, by_group, by_project'])
      end
    end

    it 'is not allowed to specify by_group and any other reviewable' do
      %i[by_project by_package].each do |reviewable|
        review = Review.create(:by_group => group.title, reviewable => 'not-existent-reviewable')
        expect(review.errors.messages[:base])
          .to eq(['it is not allowed to have more than one reviewer entity: by_user, by_group, by_project'])
      end
    end
  end

  describe '.assigned' do
    subject { Review.assigned }

    include_context 'some assigned reviews and some unassigned reviews'

    it { is_expected.to contain_exactly(review_assigned1, review_assigned2) }
  end

  describe '.unassigned' do
    subject { Review.unassigned }

    include_context 'some assigned reviews and some unassigned reviews'

    it { is_expected.to contain_exactly(review_unassigned1, review_unassigned2) }
  end

  describe '.set_associations' do
    before do
      bs_request
    end

    context 'with valid attributes' do
      it 'sets user association when by_user object exists' do
        review = create(:review, by_user: user.login, bs_request: bs_request)
        expect(review.user).to eq(user)
        expect(review.by_user).to eq(user.login)
      end

      it 'sets group association when by_group object exists' do
        review = create(:review, by_group: group.title, bs_request: bs_request)
        expect(review.group).to eq(group)
        expect(review.by_group).to eq(group.title)
      end

      it 'sets project association when by_project object exists' do
        review = create(:review, by_project: project.name, bs_request: bs_request)
        expect(review.project).to eq(project)
        expect(review.by_project).to eq(project.name)
      end

      it 'sets package and project associations when by_package and by_project object exists' do
        review = create(:review, by_project: project.name, by_package: package.name, bs_request: bs_request)
        expect(review.package).to eq(package)
        expect(review.by_package).to eq(package.name)
        expect(review.project).to eq(project)
        expect(review.by_project).to eq(project.name)
      end

      it 'sets package and project associations when by_package and by_project object exists. remove package. Review should be invalid' do
        User.session = user
        review = create(:review, by_project: project.name, by_package: package.name, bs_request: bs_request)
        expect(review.package).to eq(package)
        expect(review.by_package).to eq(package.name)
        expect(review.project).to eq(project)
        expect(review.by_project).to eq(project.name)
        package.destroy
        expect(review).to be_valid
        expect(review.errors.messages[:package]).not_to include('can\'t be blank')
      end
    end

    context 'with invalid attributes' do
      let!(:nobody) { create(:user_nobody) }

      it 'does not set user association when by_user object does not exist' do
        review = Review.new(by_user: 'not-existent')
        expect(review.user).to be_nil
        expect(review.valid?).to be(false)
      end

      it 'does not set user association when by_user object is _nobody_' do
        review = Review.new(by_user: nobody)
        expect(review.user).to be_nil
        expect(review.valid?).to be(false)
        expect(review.errors.messages[:base])
          .to eq(["Couldn't find user #{nobody.login}"])
      end

      it 'does not set group association when by_group object does not exist' do
        review = Review.new(by_group: 'not-existent')
        expect(review.group).to be_nil
        expect(review.valid?).to be(false)
      end

      it 'does not set project association when by_project object does not exist' do
        review = Review.new(by_project: 'not-existent')
        expect(review.project).to be_nil
        expect(review.valid?).to be(false)
      end

      it 'does not set project and package associations when by_project and by_package object does not exist' do
        review = Review.new(by_project: 'not-existent', by_package: 'not-existent')
        expect(review.package).to be_nil
        expect(review.valid?).to be(false)
      end

      it 'does not set package association when by_project parameter is missing' do
        review = Review.new(by_package: package.name)
        expect(review.package).to be_nil
        expect(review).not_to be_valid
        expect(review.errors.messages[:package]).to include('can\'t be blank')
      end
    end
  end

  describe '#accepted_at' do
    let(:review_state) { :accepted }
    let(:review) { create(:review, by_user: user.login, state: review_state, bs_request: bs_request) }
    let!(:history_element_review_accepted) do
      create(
        :history_element_review_accepted,
        review: review,
        user: user,
        created_at: Faker::Time.forward(days: 1)
      )
    end

    context 'with a review assigned to and assigned to state = accepted' do
      subject { review.accepted_at }

      let(:review2) { create(:review, by_user: user.login, review_id: review.id, state: :accepted, bs_request: bs_request) }
      let!(:history_element_review_accepted2) do
        create(
          :history_element_review_accepted,
          review: review2,
          user: user,
          created_at: Faker::Time.forward(days: 2)
        )
      end

      it { is_expected.to eq(history_element_review_accepted2.created_at) }
    end

    context 'with a review assigned to and assigned to state != accepted' do
      subject { review.accepted_at }

      let!(:review2) { create(:review, by_user: user.login, review_id: review.id, updated_at: Faker::Time.forward(days: 2), state: :new, bs_request: bs_request) }

      it { is_expected.to be_nil }
    end

    context 'with no reviewed assigned to and state = accepted' do
      subject { review.accepted_at }

      it { is_expected.to eq(history_element_review_accepted.created_at) }
    end

    context 'with no reviewed assigned to and state != accepted' do
      subject { review.accepted_at }

      let(:review_state) { :new }

      it { is_expected.to be_nil }
    end
  end

  describe '#declined_at' do
    let(:review_state) { :declined }
    let(:review) { create(:review, by_user: user.login, state: review_state, bs_request: bs_request) }
    let!(:history_element_review_declined) do
      create(
        :history_element_review_declined,
        review: review,
        user: user,
        created_at: Faker::Time.forward(days: 1)
      )
    end

    context 'with a review assigned to and assigned to state = declined' do
      subject { review.declined_at }

      let(:review2) { create(:review, by_user: user.login, review_id: review.id, state: :declined, bs_request: bs_request) }
      let!(:history_element_review_declined2) do
        create(
          :history_element_review_declined,
          review: review2,
          user: user,
          created_at: Faker::Time.forward(days: 2)
        )
      end

      it { is_expected.to eq(history_element_review_declined2.created_at) }
    end

    context 'with a review assigned to and assigned to state != declined' do
      subject { review.declined_at }

      let!(:review2) { create(:review, by_user: user.login, review_id: review.id, updated_at: Faker::Time.forward(days: 2), state: :new, bs_request: bs_request) }

      it { is_expected.to be_nil }
    end

    context 'with no reviewed assigned to and state = declined' do
      subject { review.declined_at }

      it { is_expected.to eq(history_element_review_declined.created_at) }
    end

    context 'with no reviewed assigned to and state != declined' do
      subject { review.declined_at }

      let(:review_state) { :new }

      it { is_expected.to be_nil }
    end
  end

  describe '#validate_not_self_assigned' do
    let!(:review) { create(:review, by_user: user.login, bs_request: bs_request) }

    context 'assigned to itself' do
      before do
        review.review_id = review.id

        review.valid?
      end

      it { expect(review.errors[:review_id].count).to eq(1) }
    end

    context 'assigned to a different review' do
      let!(:review2) { create(:review, by_user: user.login, bs_request: bs_request) }

      before do
        review.review_id = review2.id

        review.valid?
      end

      it { expect(review.errors[:review_id].count).to eq(0) }
    end
  end

  describe '#validate_non_symmetric_assignment' do
    let!(:review) { create(:review, by_user: user.login, bs_request: bs_request) }
    let!(:review2) { create(:review, by_user: user.login, review_id: review.id, bs_request: bs_request) }

    context 'review1 is assigned to review2 which is already assigned to review1' do
      before do
        review.review_id = review2.id

        review.valid?
      end

      it { expect(review.errors[:review_id].count).to eq(1) }
    end

    context 'review1 is assigned to review3' do
      let!(:review3) { create(:review, by_user: user.login, bs_request: bs_request) }

      before do
        review.review_id = review3.id

        review.valid?
      end

      it { expect(review.errors[:review_id].count).to eq(0) }
    end
  end

  describe '#update_caches' do
    RSpec.shared_examples "the subject's cache is reset when it's review changes" do
      let!(:cache_key) { subject.cache_key_with_version }

      before do
        review.state = :accepted
        review.save
        subject.reload
      end

      it { expect(subject.cache_key_with_version).not_to eq(cache_key) }
    end

    context 'by_user' do
      subject { review.user }

      let!(:review) { create(:user_review, bs_request: bs_request) }

      it_behaves_like "the subject's cache is reset when it's review changes"
    end

    context 'by_group' do
      let(:groups_user) { create(:groups_user) }
      let(:group) { groups_user.group }
      let(:user) { groups_user.user }
      let!(:review) { create(:review, by_group: group, bs_request: bs_request) }

      it_behaves_like "the subject's cache is reset when it's review changes" do
        subject { user }
      end
      it_behaves_like "the subject's cache is reset when it's review changes" do
        subject { group }
      end
    end

    context 'by_package with a direct relationship' do
      subject { relationship_package_user.user }

      let(:relationship_package_user) { create(:relationship_package_user) }
      let(:package) { relationship_package_user.package }
      let!(:review) { create(:review, by_package: package, by_project: package.project, bs_request: bs_request) }

      it_behaves_like "the subject's cache is reset when it's review changes"
    end

    context 'by_package with a group relationship' do
      let(:relationship_package_group) { create(:relationship_package_group) }
      let(:package) { relationship_package_group.package }
      let(:group) { relationship_package_group.group }
      let(:groups_user) { create(:groups_user, group: group) }
      let!(:user) { groups_user.user }
      let!(:review) { create(:review, by_package: package, by_project: package.project, bs_request: bs_request) }

      it_behaves_like "the subject's cache is reset when it's review changes" do
        subject { user }
      end
      it_behaves_like "the subject's cache is reset when it's review changes" do
        subject { group }
      end
    end

    context 'by_project with a direct relationship' do
      subject { relationship_project_user.user }

      let(:relationship_project_user) { create(:relationship_project_user) }
      let(:project) { relationship_project_user.project }
      let!(:review) { create(:review, by_project: project, bs_request: bs_request) }

      it_behaves_like "the subject's cache is reset when it's review changes"
    end

    context 'by_project with a group relationship' do
      let(:relationship_project_group) { create(:relationship_project_group) }
      let(:project) { relationship_project_group.project }
      let(:group) { relationship_project_group.group }
      let(:groups_user) { create(:groups_user, group: group) }
      let!(:user) { groups_user.user }
      let!(:review) { create(:review, by_project: project, bs_request: bs_request) }

      it_behaves_like "the subject's cache is reset when it's review changes" do
        subject { user }
      end
      it_behaves_like "the subject's cache is reset when it's review changes" do
        subject { group }
      end
    end
  end

  describe '#reviewable_by?' do
    let(:other_user)    { create(:user, login: 'bob') }
    let(:other_group)   { create(:group, title: 'my_group') }
    let(:other_project) { create(:project_with_package, name: 'doc:things', package_name: 'less') }
    let(:other_package) { other_project.packages.first }
    let(:other_package_with_same_name) { create(:package, name: package.name) }

    let(:review_by_user)    { create(:review, bs_request: bs_request, by_user:    user.login) }
    let(:review_by_group)   { create(:review, bs_request: bs_request, by_group:   group.title) }
    let(:review_by_project) { create(:review, bs_request: bs_request, by_project: project.name) }
    let(:review_by_package) { create(:review, bs_request: bs_request, by_project: project.name, by_package: package.name) }

    it 'returns true if review configuration matches provided hash' do
      expect(review_by_user.reviewable_by?(by_user:       user.login)).to be(true)
      expect(review_by_group.reviewable_by?(by_group:     group.title)).to be(true)
      expect(review_by_project.reviewable_by?(by_project: project.name)).to be(true)
      expect(review_by_package.reviewable_by?(by_package: package.name, by_project: package.project.name)).to be(true)
    end

    it 'returns false if review configuration does not match provided hash' do
      expect(review_by_user).not_to be_reviewable_by(by_user:       other_user.login)
      expect(review_by_group).not_to be_reviewable_by(by_group:     other_group.title)
      expect(review_by_project).not_to be_reviewable_by(by_project: other_project.name)
      expect(review_by_package).not_to be_reviewable_by(by_package: other_package.name, by_project: other_package.project.name)
      expect(review_by_package).not_to be_reviewable_by(by_package: other_package_with_same_name.name, by_project: other_package_with_same_name.project.name)
    end
  end

  describe '.new_from_xml_hash' do
    subject { Review.new_from_xml_hash(review_hash) }

    let(:request_xml) do
      "<request>
        <review state='accepted' by_user='#{user}'/>
      </request>"
    end
    let(:request_hash) { Xmlhash.parse(request_xml) }
    let(:review_hash) { request_hash['review'] }

    it 'initalizes the review in state :new' do
      expect(subject.state).to eq(:new)
    end
  end
end
