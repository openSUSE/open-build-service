# frozen_string_literal: true

RSpec.shared_examples 'makes a user a maintainer of the subject' do
  let(:other_user) { create(:confirmed_user, login: 'bob') }
  let(:maintainer_role) { Role.where(title: 'maintainer') }

  before do
    object = (subject.is_a?(Project) ? subject : subject.project)
    login(object.relationships.maintainers.first.user)

    subject.add_maintainer(other_user)
  end

  it 'makes a user a maintainer of the package' do
    expect(
      subject.relationships.where(user: other_user, role: maintainer_role)
    ).to exist
  end
end
