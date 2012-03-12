class BsRequest < ActiveXML::Base

  class ListError < Exception; end
  class ModifyError < Exception; end

  default_find_parameter :id

  class << self
    def make_stub(opt)
      option = source_package = target_package = ""
      opt[:description] = "" if !opt.has_key? :description or opt[:description].nil?
      if opt[:targetpackage] and not opt[:targetpackage].empty?
        target_package = "package=\"#{opt[:targetpackage].to_xs}\""
      end

      # set request-specific options
      case opt[:type]
        when "submit" then
          # use source package name if no target package name is given for a submit request
          target_package = "package=\"#{opt[:package].to_xs}\"" if target_package.empty?
          # set target package is the same as the source package if no target package is specified
          revision_option = "rev=\"#{opt[:rev].to_xs}\"" unless opt[:rev].blank?
          action = "<source project=\"#{opt[:project]}\" package=\"#{opt[:package]}\" #{revision_option}/>"
          action += "<target project=\"#{opt[:targetproject].to_xs}\" #{target_package}/>"
          action += "<options><sourceupdate>#{opt[:sourceupdate]}</sourceupdate></options>" unless opt[:sourceupdate].blank?
        when "add_role" then
          action = "<group name=\"#{opt[:group]}\" role=\"#{opt[:role]}\"/>" unless opt[:group].blank?
          action = "<person name=\"#{opt[:person]}\" role=\"#{opt[:role]}\"/>" unless opt[:person].blank?
          action += "<target project=\"#{opt[:targetproject].to_xs}\" #{target_package}/>"
        when "set_bugowner" then
          action = "<person name=\"#{opt[:person]}\" role=\"#{opt[:role]}\"/>"
          action += "<target project=\"#{opt[:targetproject].to_xs}\" #{target_package}/>"
        when "change_devel" then
          action = "<source project=\"#{opt[:project]}\" package=\"#{opt[:package]}\"/>"
          action += "<target project=\"#{opt[:targetproject].to_xs}\" #{target_package}/>"
        when "maintenance_incident" then
          action = "<source project=\"#{opt[:project]}\" />"
          action += "<target project=\"#{opt[:targetproject].to_xs}\" />" unless opt[:targetproject].blank?
        when "maintenance_release" then
          action = "<source project=\"#{opt[:project]}\" />"
          action += "<target project=\"#{opt[:targetproject].to_xs}\" />" unless opt[:targetproject].blank?
        when "delete" then
          action = "<target project=\"#{opt[:targetproject].to_xs}\" #{target_package}/>"
      end
      # build the request XML
      reply = <<-EOF
        <request>
          <action type="#{opt[:type]}">
            #{action}
          </action>
          <state name="new"/>
          <description>#{opt[:description].to_xs}</description>
        </request>
      EOF
      return reply
    end

    def addReview(id, opts)
      opts = {:user => nil, :group => nil, :project => nil, :package => nil, :comment => nil}.merge opts

      transport ||= ActiveXML::Config::transport_for :bsrequest
      path = "/request/#{id}?cmd=addreview"
      path << "&by_user=#{CGI.escape(opts[:user])}" unless opts[:user].blank?
      path << "&by_group=#{CGI.escape(opts[:group])}" unless opts[:group].blank?
      path << "&by_project=#{CGI.escape(opts[:project])}" unless opts[:project].blank?
      path << "&by_package=#{CGI.escape(opts[:package])}" unless opts[:package].blank?
      begin
        r = transport.direct_http URI("#{path}"), :method => "POST", :data => opts[:comment]
        BsRequest.free_cache(id)
        return true
      rescue ActiveXML::Transport::ForbiddenError => e
        message, _, _ = ActiveXML::Transport.extract_error_message e
        raise ModifyError, message
      rescue ActiveXML::Transport::NotFoundError => e
        message, _, _ = ActiveXML::Transport.extract_error_message e
        raise ModifyError, message
      end
    end

    def modifyReview(id, changestate, opts)
      unless (changestate=="accepted" || changestate=="declined")
        raise ModifyError, "unknown changestate #{changestate}"
      end

      transport ||= ActiveXML::Config::transport_for :bsrequest
      path = "/request/#{id}?newstate=#{changestate}&cmd=changereviewstate"
      path << "&by_user=#{CGI.escape(opts[:user])}" unless opts[:user].blank?
      path << "&by_group=#{CGI.escape(opts[:group])}" unless opts[:group].blank?
      path << "&by_project=#{CGI.escape(opts[:project])}" unless opts[:project].blank?
      path << "&by_package=#{CGI.escape(opts[:package])}" unless opts[:package].blank?
      begin
        transport.direct_http URI("#{path}"), :method => "POST", :data => opts[:comment]
        BsRequest.free_cache(id)
        return true
      rescue ActiveXML::Transport::ForbiddenError, ActiveXML::Transport::NotFoundError, ActiveXML::Transport::Error => e
        message, _, _ = ActiveXML::Transport.extract_error_message e
        raise ModifyError, message
      end
    end

    def modify(id, changestate, opts)
      opts = {:superseded_by => nil, :force => false, :reason => ''}.merge opts
      if ["accepted", "declined", "revoked", "superseded", "new"].include?(changestate)
        transport ||= ActiveXML::Config::transport_for :bsrequest
        path = "/request/#{id}?newstate=#{changestate}&cmd=changestate"
        path += "&superseded_by=#{opts[:superseded_by]}" unless opts[:superseded_by].blank?
        path += "&force=1" if opts[:force]
        begin
          transport.direct_http URI("#{path}"), :method => "POST", :data => opts[:reason].to_s
          BsRequest.free_cache(id)
          return true
        rescue ActiveXML::Transport::ForbiddenError => e
          message, _, _ = ActiveXML::Transport.extract_error_message e
          raise ModifyError, message
        rescue ActiveXML::Transport::NotFoundError => e
          message, _, _ = ActiveXML::Transport.extract_error_message e
          raise ModifyError, message
        end
      end
      raise ModifyError, "unknown changestate #{changestate}"
    end

    def find_last_request(opts)
      unless opts[:targetpackage] and opts[:targetproject] and opts[:sourceproject] and opts[:sourcepackage]
        raise RuntimeError, "missing parameters"
      end
      pred = "(action/target/@package='#{opts[:targetpackage]}' and action/target/@project='#{opts[:targetproject]}' and action/source/@project='#{opts[:sourceproject]}' and action/source/@package='#{opts[:sourcepackage]}' and action/@type='submit')"
      requests = Collection.find_cached :what => :request, :predicate => pred
      last = nil
      requests.each_request do |r|
        last = r if not last or r.value(:id).to_i > last.value(:id).to_i
      end
      return last
    end

    def list(opts)
      unless opts[:states] or opts[:reviewstate] or opts[:roles] or opts[:types] or opts[:user] or opts[:project]
        raise RuntimeError, "missing parameters"
      end

      opts.delete(:types) if opts[:types] == 'all' # All types means don't pass 'type' to backend

      transport ||= ActiveXML::Config::transport_for :bsrequest
      path = "/request?view=collection"
      path << "&states=#{CGI.escape(opts[:states])}" unless opts[:states].blank?
      path << "&roles=#{CGI.escape(opts[:roles])}" unless opts[:roles].blank?
      path << "&reviewstates=#{CGI.escape(opts[:reviewstates])}" unless opts[:reviewstates].blank?
      path << "&types=#{CGI.escape(opts[:types])}" unless opts[:types].blank? # the API want's to have it that way, sigh...
      path << "&user=#{CGI.escape(opts[:user])}" unless opts[:user].blank?
      path << "&project=#{CGI.escape(opts[:project])}" unless opts[:project].blank?
      path << "&package=#{CGI.escape(opts[:package])}" unless opts[:package].blank?
      begin
        logger.debug "Fetching request list from api"
        response = transport.direct_http URI("#{path}"), :method => "GET"
        return Collection.new(response).each # last statement, implicit return value of block, assigned to 'request_list' non-local variable
      rescue ActiveXML::Transport::Error => e
        message, _, _ = ActiveXML::Transport.extract_error_message e
        raise ListError, message
      end
    end

    def creator(req)
      login = ''
      if req.has_element?(:history)
        #NOTE: 'req' can be a LibXMLNode or not. Depends on code path.
        if req.history.class == ActiveXML::LibXMLNode
          login = req.history.who
        else
          login = req.history.first[:who]
        end
      else
        login = req.state.who
      end
      Person.find_cached(login)
    end

    def sorted_filenames_from_sourcediff(sourcediff)
      # Sort files into categories by their ending and add all of them to a hash. We
      # will later use the sorted and concatenated categories as key index into the per action file hash.
      changes_file_keys, spec_file_keys, patch_file_keys, other_file_keys = [], [], [], []
      files_hash, issues_hash = {}, {}

      sourcediff.files.each do |file|
        if file.new
          filename = file.new.name.to_s
        elsif file.old # in case of deleted files
          filename = file.old.name.to_s
        end
        if filename.include?('/')
          other_file_keys << filename
        else
          if filename.ends_with?('.spec')
            spec_file_keys << filename
          elsif filename.ends_with?('.changes')
            changes_file_keys << filename
          elsif filename.match(/.*.(patch|diff|dif)/)
            patch_file_keys << filename
          else
            other_file_keys << filename
          end
        end
        files_hash[filename] = file
      end

      if sourcediff.has_element?(:issues)
        sourcediff.issues.each do |issue|
          issues_hash[issue.value('label')] = Issue.find_cached(issue.value('name'), :tracker => issue.value('tracker'))
        end
      end

      parsed_sourcediff = {
        :old => sourcediff.old,
        :new => sourcediff.new,
        :filenames => changes_file_keys.sort + spec_file_keys.sort + patch_file_keys.sort + other_file_keys.sort,
        :files => files_hash,
        :issues => issues_hash
      }
      return parsed_sourcediff
    end
  end

  def creator
    return BsRequest.creator(self)
  end

  def reviews_for_user_and_others(user)
    user_reviews, other_open_reviews = [], []
    self.each_review do |review|
      if review.state == 'new'
        if user &&
           ( (review.has_attribute?(:by_user) && user.login == review.by_user) ||
             (review.has_attribute?(:by_group) && user.is_in_group?(review.by_group)) ||
             (review.has_attribute?(:by_project) && user.is_maintainer?(review.by_project)) ||
             (review.has_attribute?(:by_project) && review.has_attribute?(:by_package) && 
              user.is_maintainer?(review.by_project, review.by_package)) )
          user_reviews << review
        else
          other_open_reviews << review
        end
      end
    end
    return user_reviews, other_open_reviews
  end

  def history
    ret = []
    self.each_history do |h|
      ret << { :who => h.who, :when => Time.parse(h.when), :name => h.name, :comment => h.value(:comment) }
    end if self.has_element?(:history)
    h = self.state
    ret << { :who => h.who, :when => Time.parse(h.when), :name => h.name, :comment => h.value(:comment) }
    return ret
  end

  def events
    # Try to find out what happened over time...
    events = {}
    last_history_item = nil
    self.each_history do |item|
      what, color = "", nil
      case item.name
        when "new" then
          if last_history_item && last_history_item.name == "review"
            what, color = "acCEPted review", "green" # Moving back to state 'new'
          elsif last_history_item && last_history_item.name == "declined"
            what, color = "reopened", "maroon"
          else
            what = "created request" # First history item, regardless of 'state' (may be 'review')
          end
        when "review" then
          if !last_history_item # First history item
            what = "created request"
          elsif last_history_item && last_history_item.name == "declined"
            what, color = "reopened review", 'maroon'
          else # Other items...
            what = "added review"
          end
        when "accepted" then what, color = "accepted request", "green"
        when "declined" then
          color = "red"
          if last_history_item
            case last_history_item.value('name')
              when "review" then what = "declined review"
              when "new" then what = "declined request"
            end
          end
        when "superseded" then what = "superseded request"
      end

      events[item.when] = {:who => item.who, :what => what, :when => item.when, :comment => item.value('comment')}
      events[item.when][:color] = color if color
      last_history_item = item
    end
    last_review_item = nil
    self.each_review do |item|
      if ['accepted', 'declined'].include?(item.state)
        events[item.when] = {:who => item.who, :what => "#{item.state} review for #{reviewer_for_history_item(item)}", :when => item.when, :comment => item.value('comment')}
        events[item.when][:color] = "green" if item.state == "accepted"
        events[item.when][:color] = "red" if item.state == "declined"
      end
      last_review_item = item
    end
    # The <state ... /> element describes the last event in request's history:
    state, what, color = self.state, "", ""
    comment = state.value('comment')
    case state.value('name')
      when "accepted" then what, color = "accepted request", "green"
      when "declined" then what, color = "declined request", "red"
      when "new", "review"
        if last_history_item # Last history entry
          case last_history_item.value('name')
            when 'review' then
              # TODO: There is still a case left, see sr #106286, factory-auto added a review for autobuild-team, the
              # request # remained in state 'review', but another review was accepted in between. That is kind of hard
              # to grasp from the pack of <history/>, <review/> and <state/> items without breaking # the other cases ;-)
              what, color = "accepted review for #{last_history_item.value('who')}", 'green'
              comment = last_review_item.value('comment') # Yes, the comment for the last history item is in the last review ;-)
            when 'declined' then what, color = 'reopened request', 'maroon'
          end
        else
          what = "created request"
        end
      when "superseded" then what, color = 'superseded request', 'green'
      when "revoked" then what, color = 'revoked request', 'green'
    end

    events[state.when] = {:who => state.who, :what => what, :when => state.when, :comment => comment}
    events[state.when][:color] = color if color
    events[state.when][:superseded_by] = @superseded_by if @superseded_by
    # That wasn't all to difficult, no? ;-)

    sorted_events = [] # Store events sorted by key (i.e. datetime)
    events.keys.sort.each { |key| sorted_events << events[key] }
    return sorted_events
  end

  def actions(with_diff = true)
    return Rails.cache.fetch("request_#{value('id')}_actions", :expires_in => 7.days) do
      actions, action_index = [], 0
      each_action do |xml|
        action = {:type => xml.value('type'), :xml => xml}

        if xml.has_element?(:source) && xml.source.has_attribute?(:project)
          action[:sprj] = xml.source.value('project')
          action[:spkg] = xml.source.value('package') if xml.source.has_attribute?(:package)
          action[:srev] = xml.source.value('rev') if xml.source.has_attribute?(:rev)
        end
        if xml.has_element?(:target) && xml.target.has_attribute?(:project)
          action[:tprj] = xml.target.value('project')
          action[:tpkg] = xml.target.value('package') if xml.target.has_attribute?(:package)
        end

        case xml.value('type') # All further stuff depends on action type...
        when 'submit' then
          action[:name] = "Submit #{action[:spkg]}"
          action[:sourcediff] = actiondiffs()[action_index] if with_diff
          action[:creator_is_target_maintainer] = true if self.creator.is_maintainer?(action[:tprj], action[:tpkg])

          target_package = Package.find_cached(action[:tpkg], :project => action[:tprj])
          if target_package
            linkinfo = target_package.linkinfo
            target_package.developed_packages.each do |dev_pkg|
              action[:forward] ||= []
              action[:forward] << {:project => dev_pkg.project, :package => dev_pkg.name, :type => 'devel'}
            end
            if linkinfo
              lprj, lpkg = linkinfo.project, linkinfo.package
              link_is_already_devel = false
              if action[:forward]
                action[:forward].each do |forward|
                  if forward[:project] == lprj && forward[:package] == lpkg
                    link_is_already_devel = true
                    break
                  end
                end
              end
              if !link_is_already_devel
                action[:forward] ||= []
                action[:forward] << {:project => linkinfo.project, :package => linkinfo.package, :type => 'link'}
              end
            end
          end

        when 'delete' then
          if action[:tpkg]
            action[:name] = "Delete #{action[:tpkg]}"
          else
            action[:name] = "Delete #{action[:tprj]}"
          end

          if action[:tpkg] # API / Backend don't support whole project diff currently
            action[:sourcediff] = actiondiffs()[action_index] if with_diff
          end
        when 'add_role' then 
          action[:name] = 'Add Role'
          action[:role] = xml.person.value('role')
          action[:user] = xml.person.value('name')
        when 'change_devel' then 
          action[:name] = 'Change Devel'
        when 'set_bugowner' then 
          action[:name] = 'Set Bugowner'
        when 'maintenance_incident' then
          action[:name] = 'Maintenance Incident'
          action[:sourcediff] = actiondiffs()[action_index] if with_diff
        when 'maintenance_release' then
          action[:name] = "Release #{action[:spkg].split('.')[0]}"
          action[:sourcediff] = actiondiffs()[action_index] if with_diff
        end
        action_index += 1
        actions << action
      end
      actions
    end
  end

  def actiondiffs
    return Rails.cache.fetch("request_#{value('id')}_actiondiffs", :expires_in => 7.days) do
      actiondiffs = []
      begin
        transport ||= ActiveXML::Config::transport_for :bsrequest
        result = ActiveXML::Base.new(transport.direct_http(URI("/request/#{value('id')}?cmd=diff&view=xml&withissues=1"), :method => "POST", :data => ""))
        result.each_action do |action| # Parse each action and get the it's diff (per file)
          sourcediffs = []
          action.each_sourcediff do |sourcediff| # Parse earch sourcediff in that action
            sourcediffs << BsRequest.sorted_filenames_from_sourcediff(sourcediff)
          end
          actiondiffs << sourcediffs
        end
      rescue ActiveXML::Transport::NotFoundError, ActiveXML::Transport::Error => e
      end
      actiondiffs
    end
  end

  # Check if 'user' is maintainer in _all_ request targets:
  def is_target_maintainer?(user)
    return Rails.cache.fetch("request_#{value('id')}_is_target_maintainer_#{user}", :expires_in => 7.days) do
      has_target, is_target_maintainer = false, true
      each_action do |xml|
        if xml.has_element?(:target) && xml.target.has_attribute?(:project)
          has_target = true
          if xml.target.has_attribute?(:package)
            tpkg = Package.find_cached(xml.target.package, :project => xml.target.project)
            is_target_maintainer &= tpkg.can_edit?(user) if tpkg
          else
            tprj = Project.find_cached(xml.target.project)
            is_target_maintainer &= tprj.can_edit?(user) if tprj
          end
        end
      end
      has_target && is_target_maintainer
    end
  end

  def reviewer_for_history_item(item)
    reviewer = ''
    if item.by_group
      reviewer = item.value('by_group')
    elsif item.by_project
      reviewer = item.value('by_project')
    elsif item.by_package
      reviewer = item.value('by_package')
    elsif item.by_user
      reviewer = item.value('by_user')
    end
    return reviewer
  end
end
