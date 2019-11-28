require 'rails_helper'

RSpec.describe ::MetaControllerService::MetaValidator do
  let(:project) { create(:project, name: 'openSUSE_41') }
  let(:admin_user) { create(:admin_user, login: 'Admin') }
  let(:meta_validator) { ::MetaControllerService::MetaValidator.new(project: project, request_data: Xmlhash.parse(meta)) }

  before do
    User.session = admin_user
  end

  context 'with valid meta' do
    let(:meta) do
      <<-HEREDOC
      <project name="#{project.name}">
      <title/><description/>
      </project>
      HEREDOC
    end

    before do
      meta_validator.call
    end

    describe '#valid?' do
      it { expect(meta_validator).to be_valid }
    end

    describe '#errors' do
      it { expect(meta_validator.errors).to be_blank }
    end
  end

  context 'with multiple bugowner' do
    let(:bugowner_1) { create(:confirmed_user, login: 'Tom') }
    let(:bugowner_2) { create(:confirmed_user, login: 'Jerry') }
    let(:meta) do
      <<-HEREDOC
      <project name="#{project.name}">
      <title/><description/>
      <person userid="Tom" role="bugowner"/>
      <person userid="Jerry" role="bugowner"/>
      </project>
      HEREDOC
    end

    before do
      meta_validator.call
    end

    describe '#valid?' do
      it { expect(meta_validator).not_to be_valid }
    end

    describe '#errors' do
      let(:error_message) { 'More than one bugowner found. A project can only have one bugowner assigned.' }

      it { expect(meta_validator.errors).to eq([error_message]) }
    end
  end
end
