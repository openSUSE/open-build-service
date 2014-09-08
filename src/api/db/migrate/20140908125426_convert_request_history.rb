class ConvertRequestHistory < ActiveRecord::Migration
  class OldHistory < ActiveRecord::Base
     self.table_name = 'bs_request_histories'
     belongs_to :bs_request
  end

  def self.up
    s = OldHistory.find_by_sql "SELECT bs_request_id,state,comment,commenter,superseded_by,created_at FROM bs_request_histories ORDER BY bs_request_id ASC, state DESC"

    oldid=nil
    puts "Converting #{s.length} request history elements into new structure"
    puts "This can take some time..." if s.length > 1000
    s.each do |e|
      user=User.find_by_login e.commenter
      next unless user
      p={created_at: e.created_at, user_id: user.id, comment: e.comment, op_object_id: e.bs_request_id}

      firstentry = (oldid==e.bs_request_id)
      oldid = e.bs_request_id

      history=nil
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
          if firstentry
            e.destroy
            next
          end
          history = HistoryElement::RequestReopened
        when "new" then
          if firstentry
            e.destroy
            next
          end
          history = HistoryElement::RequestReviewApproved
      end
      next unless history
      history.create(p)
      e.destroy
    end

    if OldHistory.all.length == 0
      drop_table :bs_request_histories
    else
      puts "WARNING: not all old request history elements could be transfered to new model"
      puts "         bs_request_histories SQL table still contains not transfered entries"
    end
  end

  def down
    raise "Sorry, reverting request history is not possible"
  end
end
