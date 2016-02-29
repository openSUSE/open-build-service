require 'rails_helper'

RSpec.describe Webui::MainController do
  let(:user) { create(:confirmed_user) }
  let(:admin_user) { create(:admin_user) }

  describe "POST add_news" do
    it "create a status message" do
      login(admin_user)

      post :add_news, message: "Some message", severity: "Green"
      expect(response).to redirect_to(root_path)
      message = StatusMessage.where(user: admin_user, message: "Some message", severity: "Green")
      expect(message).to exist
    end

    context "non-admin users" do
      before do
        login(user)

        post :add_news, message: "Some message", severity: "Green"
      end

      it "does not create a status message" do
        expect(response).to redirect_to(root_path)
        message = StatusMessage.where(user: admin_user, message: "Some message", severity: "Green")
        expect(message).not_to exist
      end
    end

    context "empty message" do
      before do
        login(admin_user)
        post :add_news, severity: "Green"
      end

      it { expect(flash[:error]).to eq("Please provide a message and severity") }
    end

    context "empty severity" do
      before do
        login(admin_user)
        post :add_news, message: "Some message"
      end

      it { expect(flash[:error]).to eq("Please provide a message and severity") }
    end
  end

  describe "POST delete_message" do
    let(:message)  { message = create(:status_message, user: admin_user) }

    it "marks a message as deleted" do
      login(admin_user)

      post :delete_message, message_id: message.id
      expect(response).to redirect_to(root_path)
      expect(message.reload.deleted_at).to be_a_kind_of(ActiveSupport::TimeWithZone)
    end

    context "non-admin users" do
      before do
        login(user)
        post :delete_message, message_id: message.id
      end

      it "can't delete messages" do
        expect(response).to redirect_to(root_path)
        expect(message.reload.deleted_at).to be nil
      end
    end
  end
end
