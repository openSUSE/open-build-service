require 'rails_helper'
include Webui::UserHelper

RSpec.describe Webui::SearchHelper, type: :helper do
  describe '#search_owners_list' do
    let(:user) { create(:user) }
    let(:maintainer) { create_list(:user, 3).map(&:login) }
    let(:foo_user) { create_list(:user, 2).map(&:login) }
    let(:list) { { maintainer: maintainer, foo: foo_user } }

    it 'returns an empty list when first parameter is empty' do
      expect(search_owners_list([])).to eq([])
    end

    it 'creates an icon with link for each user' do
      User.current = user
      expected_result = maintainer.map { |user| user_and_role(user, 'maintainer') }
      expected_result.concat(foo_user.map { |user| user_and_role(user, 'foo') })

      expect(search_owners_list(list)).to match_array(expected_result)
    end

    context "when second parameter is ':group'" do
      it 'creates a label for each user that contains user name and role' do
        expected_result = maintainer.map { |user| "#{user} as maintainer" }
        expected_result.concat(foo_user.map { |user| "#{user} as foo" })

        expect(search_owners_list(list, :group)).to match_array(expected_result)
      end
    end
  end
end
