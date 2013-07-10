module CommentsHelper
	def sort_comments(comment)
		@all_comments = Hash.new
		@all_comments[:parents] = []
		@all_comments[:children] = []
		@comments_as_thread = []

		# getting all comment data from xml and pushing into an array
		comment.each do |com|
			unless com.parent_id.present?
				@all_comments[:parents] << [com.title, com.to_s, com.id, com.user, com.created_at] # n.to_s is the body of the comment
			else
				@all_comments[:children] << [com.to_s, com.user, com.parent_id, com.id, com.created_at]
			end
		end

		@all_comments[:parents].sort_by! { |c| c[4] } # sorting by created_at 
		@all_comments[:children].sort_by! { |c| c[4] }# sorting by created_at 

		# now pushing sorted and final list of first/top/parent level comments into to a hash to
		@all_comments[:parents].each do |first_level|
		@comments_as_thread << {
			created_at: first_level[4],
			id: first_level[2],
			title: first_level[0],
			body: first_level[1],
			parent_id: nil,
			user: first_level[3],
			children: find_children(first_level[2])
		}
		end
		return @comments_as_thread
	end

	def find_children(parent_id = nil)
		return [] unless parent_id
		current_children = []
		
		# get children of current top comment
		
		got_child_comments = @all_comments[:children].select do |c|
			c[2] == parent_id
		end

		# pushing children coments into hash

		got_child_comments.each do |child|
		current_children << {
			created_at: child[4],
			id: child[3],
			title: '', # replies dont have title
			body: child[0],
			parent_id: child[2],
			user: child[1],
			children: find_children(child[3])
		}
		end
		return current_children
	end
end