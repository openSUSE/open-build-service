require 'rails_helper'

RSpec.describe Comment do
  let(:comment_package) { create(:comment_package) }
  let(:comment_package_with_parent) { create(:comment_package, parent: comment_package, commentable: comment_package.commentable) }
  let(:comment_package_with_parent_2) { create(:comment_package, parent: comment_package, commentable: comment_package.commentable) }
  let(:comment_package_with_grandparent) { create(:comment_package, parent: comment_package_with_parent, commentable: comment_package.commentable) }

  describe 'has a valid Factory' do
    it { expect(comment_package).to be_valid }
  end

  describe 'save' do
    it 'stores emoji' do
      comment_package.body = '😁'
      comment_package.save
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:commentable) }
    it { is_expected.to belong_to(:user).inverse_of(:comments) }

    it { is_expected.to have_many(:children).dependent(:destroy).class_name('Comment').with_foreign_key('parent_id') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:body) }
    it { is_expected.to validate_presence_of(:commentable) }
    it { is_expected.to validate_presence_of(:user) }

    it {
      expect { create(:comment_package, parent: comment_package) }.to raise_error(
        ActiveRecord::RecordInvalid, 'Validation failed: Parent belongs to different object'
      )
    }
  end

  describe 'blank_or_destroy' do
    context 'without children' do
      before do
        comment_package
      end

      it 'is destroyed' do
        expect { comment_package.blank_or_destroy }.to change(Comment, :count).by(-1)
      end
    end

    context 'with nobody parent and a brother' do
      before do
        comment_package_with_parent
        comment_package_with_parent_2
        comment_package.blank_or_destroy
      end

      it 'is destroyed' do
        expect { comment_package_with_parent.blank_or_destroy }.to change(Comment, :count).by(-1)
      end
    end

    context 'with nobody parent, nobody grandparent and no brother' do
      before do
        comment_package_with_grandparent
        comment_package_with_parent.blank_or_destroy
        comment_package.blank_or_destroy
      end

      it 'is destroyed' do
        expect { comment_package_with_grandparent.blank_or_destroy }.to change(Comment, :count).by(-3)
      end
    end

    context 'with children' do
      before do
        comment_package_with_parent
      end

      it 'is not destroyed' do
        expect { comment_package.blank_or_destroy }.not_to(change(Comment, :count))
        expect(comment_package.body).to eq('This comment has been deleted')
        expect(comment_package.user.login).to eq('_nobody_')
      end
    end
  end
end
