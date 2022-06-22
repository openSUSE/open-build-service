require 'rails_helper'

RSpec.describe Token::RssPolicy do
  let(:user) { create(:user) }
  let(:other_user) { build(:user) }
  let(:user_nobody) { build(:user_nobody) }
  let(:rss_token_user) { create(:rss_token, executor: user) }

  subject { described_class }

  permissions :create? do
    it { is_expected.to permit(user, rss_token_user) }
    it { is_expected.not_to permit(other_user, rss_token_user) }
  end

  it "doesn't permit anonymous user" do
    expect { described_class.new(user_nobody, rss_token_user) }
      .to raise_error(an_instance_of(Pundit::NotAuthorizedError).and(having_attributes(reason: :anonymous_user)))
  end
end
