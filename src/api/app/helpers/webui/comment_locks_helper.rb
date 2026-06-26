module Webui::CommentLocksHelper
  def comment_lock_alert(commentable)
    alert = 'You can remove the lock by clicking on the "Unlock Comments" button in the Actions section.'
    return alert if commentable.comment_lock

    if commentable.is_a?(Package) && commentable.project.comment_lock
      text = 'You can remove the lock by visiting'
      link = link_to(commentable.project.name, project_show_path(commentable.project))
      safe_join([text, ' ', content_tag(:a, link)])
    else
      alert
    end
  end
end
