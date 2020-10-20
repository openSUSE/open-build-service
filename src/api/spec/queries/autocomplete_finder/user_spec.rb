require 'rails_helper'

RSpec.describe AutocompleteFinder::User, vcr: true do
  describe '#call' do
    before do
      create(:user, login: 'foo')
      create(:user, login: 'foobar')
      create(:user, login: 'barbar')
    end

    context 'limit the number of found users to 1' do
      let(:autocomplete_users_finder) { AutocompleteFinder::User.new(User.all, 'foo', limit: 1) }

      it { expect(autocomplete_users_finder.call).to match_array(User.where(login: 'foo')) }
    end

    context 'find all users with start with foo' do
      let(:autocomplete_users_finder) { AutocompleteFinder::User.new(User.all, 'foo') }

      it { expect(autocomplete_users_finder.call).to match_array(User.where('login LIKE ?', 'foo%')) }
    end
  end
end
