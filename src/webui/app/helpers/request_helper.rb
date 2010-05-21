module RequestHelper

  # for a simplified view on a request, must be used only for lists
  def reqtype(req)
    if req.has_element? :action
      type = req.action.value :type
      if req.each_action.length > 1
         type = "multiple"
      end
    else
      type = req.value :type
    end
    type = "chgdev" if type == "change_devel"
    type = "bugowner" if type == "set_bugowner"
    type = "addrole" if type == "add_role"
    type
  end

end
