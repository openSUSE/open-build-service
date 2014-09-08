# this class is used to fetch all history elements and order them

class History

  def self.find_by_request(request, opts={})
     if opts[:withreviews]
       req_history = HistoryElement::Request.where(op_object_id: request.id)

       reviews = Review.where(bs_request: request)
       rev_history = HistoryElement::Review.where(op_object_id: reviews)

       all = HistoryElement::Base.where(id: (req_history+rev_history)).order(:created_at)

       return all
     end

     HistoryElement::Request.where(op_object_id: request.id).order(:created_at)
  end

  def self.find_by_review(review)
     HistoryElement::Review.where(op_object_id: review.id).order(:created_at)
  end

end

