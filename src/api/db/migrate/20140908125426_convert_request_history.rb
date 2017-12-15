class ConvertRequestHistory < ActiveRecord::Migration[4.2]
  class OldHistory < ApplicationRecord
    self.table_name = 'bs_request_histories'
    belongs_to :bs_request
  end

  def self.up
    user = {}

    # one big transaction to improve speed
    ActiveRecord::Base.transaction do
      puts "Creating some history elements based on #{BsRequest.count} request states..."
      puts "This can take some time..." if BsRequest.count > 1000
      BsRequest.all.each do |request|
        next if request.state == :new # nothing happend yet
        user[request.commenter] ||= User.find_by_login request.commenter
        next unless user[request.commenter]
        p = { created_at: request.updated_at, user: user[request.commenter], op_object_id: request.id }
        p[:comment] = request.comment if request.comment.present?
        history = nil
        case request.state
        when :accepted then
          history = HistoryElement::RequestAccepted
        when :declined then
          history = HistoryElement::RequestDeclined
        when :revoked then
          history = HistoryElement::RequestRevoked
        when :superseded then
          history = HistoryElement::RequestSuperseded
          p[:description_extension] = request.superseded_by.to_s
        end
        history.create(p) if history
      end

      puts "Creating some history elements based on #{Review.count} reviews..."
      Review.all.each do |review|
        next if review.state == :new # nothing happend yet
        user[review.reviewer] ||= User.find_by_login review.reviewer
        next unless user[review.reviewer]
        p = { created_at: review.updated_at, user: user[review.reviewer], op_object_id: review.id }
        p[:comment] = review.reason if review.reason.present?
        history = nil
        case review.state
        when :accepted then
          history = HistoryElement::ReviewAccepted
        when :declined then
          history = HistoryElement::ReviewDeclined
        end
        history.create(p) if history
      end

      # rubocop:disable Metrics/LineLength
      s = OldHistory.find_by_sql "SELECT id,bs_request_id,state,comment,commenter,superseded_by,created_at FROM bs_request_histories ORDER BY bs_request_id ASC, created_at ASC"
      # rubocop:enable Metrics/LineLength
      oldid = nil
      puts "Converting #{s.length} request history elements into new structure"
      puts "This can take some time..." if s.length > 1000
      s.each do |e|
        user[e.commenter] ||= User.find_by_login e.commenter
        next unless user[e.commenter]
        p = { created_at: e.created_at, user: user[e.commenter], op_object_id: e.bs_request_id }
        p[:comment] = e.comment if e.comment.present?

        firstentry = (oldid != e.bs_request_id)
        oldid = e.bs_request_id
        firstreviews = true if firstentry
        firstreviews = nil unless e.state == "review"

        history = nil
        case e.state
        when "accepted" then
          history = HistoryElement::RequestAccepted
        when "declined" then
          history = HistoryElement::RequestDeclined
        when "revoked" then
          history = HistoryElement::RequestRevoked
        when "superseded" then
          history = HistoryElement::RequestSuperseded
          p[:description_extension] = e.superseded_by.to_s
        when "deleted" then
          e.destroy
        when "review" then
          if firstreviews
            e.destroy
            next
          end
          history = HistoryElement::RequestReviewAdded
        when "new" then
          if firstentry
            e.destroy
            next
          end
          history = HistoryElement::RequestAllReviewsApproved
        end
        next unless history
        history.create(p)
        e.destroy
      end

      if OldHistory.count.zero?
        drop_table :bs_request_histories
      else
        puts "WARNING: not all old request history elements could be transfered to new model"
        puts "         bs_request_histories SQL table still contains not transfered entries"
        puts "         a typical reason are entries of not anymore existing users"
      end
    end
  end

  def down
    raise "Sorry, reverting request history is not possible"
  end
end
