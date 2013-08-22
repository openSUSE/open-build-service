class CommentRequest < Comment
	def self.save(params)
		super
		CommentRequest.create(@comment)
	end
end
