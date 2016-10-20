require "rails_helper"

RSpec.shared_examples "a comment" do
  let(:comment_factory) { described_class.name.underscore }
  let(:comment) { create(comment_factory) }

  describe "A comment" do
    it { expect(build(comment_factory)).to be_valid }
  end

  describe "Comment associations" do
    it { is_expected.to belong_to(:bs_request).inverse_of(:comments) }
    it { is_expected.to belong_to(:project).inverse_of(:comments) }
    it { is_expected.to belong_to(:package).inverse_of(:comments) }
    it { is_expected.to belong_to(:user).inverse_of(:comments) }

    it { is_expected.to have_many(:children).dependent(:destroy).class_name('Comment').with_foreign_key('parent_id') }
  end

  describe "Comment validations" do
    it { is_expected.to validate_presence_of(:body) }
    it { is_expected.to validate_presence_of(:type) }
    it { is_expected.to validate_presence_of(:user) }
  end

  describe "to_xml" do
    let(:builder) { Nokogiri::XML::Builder.new }
    let(:comment_element) { builder.doc.css('comment') }

    context "without parent" do
      before do
        comment.to_xml(builder)
      end

      it "creates xml with correct attributes and content" do
        expect(comment_element.attribute('id').value).to eq(comment.id.to_s)
        expect(comment_element.attribute('when').value.to_datetime).to eq(comment.created_at)
        expect(comment_element.attribute('who').value).to eq(comment.user.login)

        expect(comment_element.text).to match(/^#<Nokogiri::XML::Builder::NodeBuilder:0x\h+>$/)
      end
    end

    context "with parent" do
      before do
        parent_comment = create(comment_factory)
        comment.parent_id = parent_comment.id
        comment.to_xml(builder)
      end

      it "creates xml with correct attributes and content" do
        expect(comment_element.attribute('id').value).to eq(comment.id.to_s)
        expect(comment_element.attribute('when').value.to_datetime).to eq(comment.created_at)
        expect(comment_element.attribute('who').value).to eq(comment.user.login)
        expect(comment_element.attribute('parent').value).to eq(comment.parent_id.to_s)

        expect(comment_element.text).to match(/^#<Nokogiri::XML::Builder::NodeBuilder:0x\h+>$/)
      end
    end
  end

  describe "blank_or_destroy" do
    context "without children" do
      before do
        comment
      end

      it 'should be destroyed' do
        expect { comment.blank_or_destroy }.to change { Comment.count }.by(-1)
      end
    end

    context "with children" do
      before do
        create(comment_factory, parent: comment)
      end

      it "shouldn't be destroyed" do
        expect { comment.blank_or_destroy }.to_not change { Comment.count }
        expect(comment.body).to eq 'This comment has been deleted'
        expect(comment.user.login).to eq '_nobody_'
      end
    end
  end
end

RSpec.describe CommentPackage do
  it_behaves_like "a comment"
end

RSpec.describe CommentProject do
  it_behaves_like "a comment"
end

RSpec.describe CommentRequest do
  it_behaves_like "a comment"
end
