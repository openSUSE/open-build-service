# this class is used to fetch all history elements and order them

class History

  def self.find_by_request(request)
     HistoryElement::Request.where(op_object_id: request.id).order(:created_at)
  end

  def self.find_by_review(review)
     HistoryElement::Review.where(op_object_id: review.id).order(:created_at)
  end

end

