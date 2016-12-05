# rubocop:disable Metrics/LineLength
class XpathEngine
  require 'rexml/parsers/xpathparser'

  class IllegalXpathError < APIException
    setup "illegal_xpath_error", 400
  end

  def initialize
    @lexer = REXML::Parsers::XPathParser.new

    @tables = {
      'attribute'       => 'attribs',
      'package'         => 'packages',
      'project'         => 'projects',
      'person'          => 'users',
      'repository'      => 'repositories',
      'issue'           => 'issues',
      'request'         => 'requests',
      'channel'         => 'channels',
      'channel_binary'  => 'channel_binaries',
      'released_binary' => 'released_binaries'
    }

    # rubocop:disable Style/AlignHash
    @attribs = {
      'packages' => {
        '@project' => {cpart: 'projects.name',
                       joins: 'LEFT JOIN projects ON packages.project_id=projects.id' },
        '@name' => {cpart: 'packages.name'},
        'title' => {cpart: 'packages.title'},
        'description' => {cpart: 'packages.description'},
        'kind' => {cpart: 'package_kinds.kind', joins:            ['LEFT JOIN package_kinds ON package_kinds.package_id = packages.id']},
        'devel/@project' => {cpart: 'projs.name', joins:           ['left join packages devels on packages.develpackage_id = devels.id',
           'left join projects projs on devels.project_id=projs.id']},
        'devel/@package' => {cpart: 'develpackage.name', joins:           ['LEFT JOIN packages develpackage ON develpackage.id = packages.develpackage_id']},
        'issue/@state' => {cpart: 'issues.state'},
        'issue/@name' => {cpart: 'issues.name'},
        'issue/@tracker' => {cpart: 'issue_trackers.name'},
        'issue/@change' => {cpart: 'package_issues.change'},
        'issue/owner/@email' => {cpart: 'users.email', joins:           [ 'LEFT JOIN users ON users.id = issues.owner_id' ]},
        'issue/owner/@login' => {cpart: 'users.login', joins:           [ 'LEFT JOIN users ON users.id = issues.owner_id' ]},
        'attribute_issue/@state' => {cpart: 'attribissues.state'},
        'attribute_issue/@name' => {cpart: 'attribissues.name'},
        'attribute_issue/@tracker' => {cpart: 'attribissue_trackers.name'},
        'attribute_issue/owner/@email' => {cpart: 'users.email', joins:           [ 'LEFT JOIN users ON users.id = attribissues.owner_id' ]},
        'attribute_issue/owner/@login' => {cpart: 'users.login', joins:           [ 'LEFT JOIN users ON users.id = attribissues.owner_id' ]},
        'person/@userid' => {cpart: 'users.login', joins:           [ 'LEFT JOIN users ON users.id = user_relation.user_id']},
        'person/@role' => {cpart: 'ppr.title', joins:           [ 'LEFT JOIN roles AS ppr ON user_relation.role_id = ppr.id']},
        'group/@groupid' => {cpart: 'groups.title', joins:           [ 'LEFT JOIN groups ON groups.id = group_relation.group_id']},
        'group/@role' => {cpart: 'gpr.title', joins:           [ 'LEFT JOIN roles AS gpr ON group_relation.role_id = gpr.id']},
        'attribute/@name' => {cpart: 'attrib_namespaces.name = ? AND attrib_types.name',
          split: ':', joins:           ['LEFT JOIN attrib_types ON attribs.attrib_type_id = attrib_types.id',
           'LEFT JOIN attrib_namespaces ON attrib_types.attrib_namespace_id = attrib_namespaces.id',
           'LEFT JOIN attribs AS attribsprj ON attribsprj.project_id = packages.project_id', # include also, when set in project
           'LEFT JOIN attrib_types AS attrib_typesprj ON attribsprj.attrib_type_id = attrib_typesprj.id',
           'LEFT JOIN attrib_namespaces AS attrib_namespacesprj ON attrib_typesprj.attrib_namespace_id = attrib_namespacesprj.id']},
        'project/attribute/@name' => {cpart: 'attrib_namespaces_proj.name = ? AND attrib_types_proj.name', split: ':', joins:           ['LEFT JOIN attribs AS attribs_proj ON attribs_proj.project_id = packages.project_id',
           'LEFT JOIN attrib_types AS attrib_types_proj ON attribs_proj.attrib_type_id = attrib_types_proj.id',
           'LEFT JOIN attrib_namespaces AS attrib_namespaces_proj ON attrib_types_proj.attrib_namespace_id = attrib_namespaces_proj.id']}
      },
      'projects' => {
        '@name' => {cpart: 'projects.name'},
        '@kind' => {cpart: 'projects.kind'},
        'title' => {cpart: 'projects.title'},
        'description' => {cpart: 'projects.description'},
        'url' => {cpart: 'projects.url'},
        'maintenance/maintains/@project' => {cpart: 'maintains_prj.name', joins: [
          'LEFT JOIN maintained_projects AS maintained_prj ON projects.id = maintained_prj.maintenance_project_id',
          'LEFT JOIN projects AS maintains_prj ON maintained_prj.project_id = maintains_prj.id']},
        'person/@userid' => {cpart: 'users.login', joins: [
          'LEFT JOIN users ON users.id = user_relation.user_id']},
        'person/@role' => {cpart: 'ppr.title', joins: [
          'LEFT JOIN roles AS ppr ON user_relation.role_id = ppr.id']},
        'group/@groupid' => {cpart: 'groups.title', joins:           [ 'LEFT JOIN groups ON groups.id = group_relation.group_id']},
        'group/@role' => {cpart: 'gpr.title', joins:           [ 'LEFT JOIN roles AS gpr ON group_relation.role_id = gpr.id']},
        'repository/@name' => {cpart: 'repositories.name'},
        'repository/path/@project' => {cpart: 'childs.name', joins: [
          'join repositories r on r.db_project_id=projects.id',
          'join path_elements pe on pe.parent_id=r.id',
          'join repositories r2 on r2.id=pe.repository_id',
          'join projects childs on childs.id=r2.db_project_id']},
        'repository/releasetarget/@trigger' => {cpart: 'rt.trigger', joins: [
          'join repositories r on r.db_project_id=projects.id',
          'join release_targets rt on rt.repository_id=r.id']},
        'package/@name' => {cpart: 'packs.name', joins:           ['LEFT JOIN packages AS packs ON packs.project_id = projects.id']},
        'attribute/@name' => {cpart: 'attrib_namespaces.name = ? AND attrib_types.name', split: ':', joins:           ['LEFT JOIN attribs ON attribs.project_id = projects.id',
           'LEFT JOIN attrib_types ON attribs.attrib_type_id = attrib_types.id',
           'LEFT JOIN attrib_namespaces ON attrib_types.attrib_namespace_id = attrib_namespaces.id']}
      },
      'repositories' => {
        '@project' => {cpart: 'pr.name',
                       joins: 'LEFT JOIN projects AS pr ON repositories.db_project_id=pr.id' },
        '@name' => {cpart: 'repositories.name'},
        'path/@project' => {cpart: 'pathrepoprj.name', joins: [
          'LEFT join projects pathrepoprj on path_repo.db_project_id=pathrepoprj.id']},
        'path/@repository' => {cpart: 'path_repo.name' },
        'targetproduct/@project' => {cpart: 'tpprj.name', joins: [
          'LEFT join packages tppkg on tppkg.id=product.package_id ',
          'LEFT join projects tpprj on tpprj.id=tppkg.project_id ']},
        'targetproduct/@arch' => {cpart: 'tppa.name', joins: [
          'LEFT join architectures tppa on tppa.id=product_update_repository.arch_filter_id ']},
        'targetproduct/@name' => {cpart: 'product.name'},
        'targetproduct/@baseversion' => {cpart: 'product.baseversion'},
        'targetproduct/@patchlevel' => {cpart: 'product.patchlevel'},
        'targetproduct/@version' => {cpart: 'product.version'}
      },
      'channels' => {
        'binary/@name' => {cpart: 'channel_binaries.name'},
        'binary/@binaryarch' => {cpart: 'channel_binaries.binaryarch'},
        'binary/@package' => {cpart: 'channel_binaries.package'},
        'binary/@supportstatus' => {cpart: 'supportstatus'},
        '@package' => {cpart: 'cpkg.name'},
        '@project' => {cpart: 'cprj.name'},
        'target/disabled' => {cpart: 'ufdct.disabled', joins: [
          'LEFT join channel_targets ufdct on ufdct.channel_id=channel.id']},
        'target/updatefor/@project' => {cpart: 'puprj.name', joins: [
          'LEFT join channel_targets ufct on ufct.channel_id=channel.id',
          'LEFT join product_update_repositories pur on pur.repository_id=ufct.repository_id',
          'LEFT join products pun on pun.id=pur.product_id ',
          'LEFT join packages pupkg on pupkg.id=pun.package_id ',
          'LEFT join projects puprj on puprj.id=pupkg.project_id ']},
        'target/updatefor/@product' => {cpart: 'pupn.name', joins: [
          'LEFT join channel_targets ufnct on ufnct.channel_id=channel.id',
          'LEFT join product_update_repositories pnur on pnur.repository_id=ufnct.repository_id',
          'LEFT join products pupn on pupn.id=pnur.product_id ']}
      },
      'channel_binaries' => {
        '@name' => {cpart: 'channel_binaries.name'},
        '@binaryarch' => {cpart: 'channel_binaries.binaryarch'},
        '@package' => {cpart: 'channel_binaries.package'},
        '@project' => {cpart: 'cprj.name', joins: [
          'LEFT join packages cpkg on cpkg.id=channel.package_id',
          'LEFT join projects cprj on cprj.id=cpkg.project_id']},
        '@supportstatus' => {cpart: 'supportstatus'},
        'target/disabled' => {cpart: 'ufdct.disabled', joins: [
          'LEFT join channel_targets ufdct on ufdct.channel_id=channel.id']},
        'updatefor/@project' => {cpart: 'puprj.name', joins: [
          'LEFT join channel_targets ufct on ufct.channel_id=channel.id',
          'LEFT join product_update_repositories pur on pur.repository_id=ufct.repository_id',
          'LEFT join products pun on pun.id=pur.product_id ',
          'LEFT join packages pupkg on pupkg.id=pun.package_id ',
          'LEFT join projects puprj on puprj.id=pupkg.project_id ']},
        'updatefor/@product' => {cpart: 'pupn.name', joins: [
          'LEFT join channel_targets ufnct on ufnct.channel_id=channel.id',
          'LEFT join product_update_repositories pnur on pnur.repository_id=ufnct.repository_id',
          'LEFT join products pupn on pupn.id=pnur.product_id ']}
      },
      'released_binaries' => {
        '@name' => {cpart: 'binary_name'},
        '@version' => {cpart: 'binary_version'},
        '@release' => {cpart: 'binary_release'},
        '@arch' => {cpart: 'binary_arch'},
        'disturl' => {cpart: 'binary_disturl'},
        'supportstatus' => {cpart: 'binary_supportstatus'},
        'updateinfo/@id' => {cpart: 'binary_updateinfo'},
        'updateinfo/@version' => {cpart: 'binary_updateinfo_version'},
        'operation' => {cpart: 'operation'},
        'modify/@time' => {cpart: 'modify_time'},
        'obsolete/@time' => {cpart: 'obsolete_time'},
        'repository/@project' => {cpart: 'release_projects.name'},
        'repository/@name' => {cpart: 'release_repositories.name'},
        'publish/@time' => {cpart: 'binary_releasetime'},
        'publish/@package' => {cpart: 'ppkg.name', joins: [
          'LEFT join packages ppkg on ppkg.id=release_package_id'
        ]},
        'updatefor/@project' => {cpart: 'puprj.name', joins: [
          'LEFT join packages pupkg on pupkg.id=product_update.package_id ',
          'LEFT join projects puprj on puprj.id=pupkg.project_id ']},
        'updatefor/@arch' => {cpart: 'pupa.name', joins: [
          'LEFT join architectures pupa on pupa.id=product_update_repository.arch_filter_id ']},
        'updatefor/@product' => {cpart: 'product_update.name'},
        'updatefor/@baseversion' => {cpart: 'product_update.baseversion'},
        'updatefor/@patchlevel' => {cpart: 'product_update.patchlevel'},
        'updatefor/@version' => {cpart: 'product_update.version'},
        'product/@project' => {cpart: 'pprj.name', joins: [
          'LEFT join packages ppkg on ppkg.id=product_ga.package_id ',
          'LEFT join projects pprj on pprj.id=ppkg.project_id ']},
        'product/@version' => {cpart: 'product_ga.version'},
        'product/@release' => {cpart: 'product_ga.release'},
        'product/@baseversion' => {cpart: 'product_ga.baseversion'},
        'product/@patchlevel' => {cpart: 'product_ga.patchlevel'},
        'product/@name' => {cpart: 'product_ga.name'},
        'product/@arch' => {cpart: 'ppna.name', joins: [
          'LEFT join architectures ppna on ppna.id=product_media.arch_filter_id ']},
        'product/@medium' => {cpart: 'product_media.name'}
      },
      'users' => {
        '@login' => {cpart: 'users.login'},
        '@email' => {cpart: 'users.email'},
        '@realname' => {cpart: 'users.realname'},
        '@state' => {cpart: 'users.state'}
       },
      'issues' => {
        '@name' => {cpart: 'issues.name'},
        '@state' => {cpart: 'issues.state'},
        '@tracker' => {cpart: 'issue_trackers.name',
                       joins: 'LEFT JOIN issue_trackers ON issues.issue_tracker_id = issue_trackers.id'
        },
        'owner/@email' => {cpart: 'users.email', joins:           ['LEFT JOIN users ON users.id = issues.owner_id']},
        'owner/@login' => {cpart: 'users.login', joins:           ['LEFT JOIN users ON users.id = issues.owner_id']}
      },
      'requests' => {
        '@id' => { cpart: 'bs_requests.number' },
        '@creator' => { cpart: 'bs_requests.creator' },
        'state/@name' => { cpart: 'bs_requests.state' },
        'state/@who' => { cpart: 'bs_requests.commenter' },
        'state/@when' => { cpart: 'bs_requests.updated_at' },
        'action/@type' => { cpart: 'a.type',
                            joins: "LEFT JOIN bs_request_actions a ON a.bs_request_id = bs_requests.id"
        },
        'action/grouped/@id' => { cpart: 'gr.number',
                                  joins: ["LEFT JOIN bs_request_actions a ON a.bs_request_id = bs_requests.id",
                                          "LEFT JOIN group_request_requests g on g.bs_request_action_group_id = a.id",
                                          "LEFT JOIN bs_requests gr on gr.id = g.bs_request_id"] },
        'action/target/@project' => { cpart: 'a.target_project', joins: "LEFT JOIN bs_request_actions a ON a.bs_request_id = bs_requests.id" },
        'action/target/@package' => { cpart: 'a.target_package', joins: "LEFT JOIN bs_request_actions a ON a.bs_request_id = bs_requests.id" },
        'action/source/@project' => { cpart: 'a.source_project', joins: "LEFT JOIN bs_request_actions a ON a.bs_request_id = bs_requests.id" },
        'action/source/@package' => { cpart: 'a.source_package', joins: "LEFT JOIN bs_request_actions a ON a.bs_request_id = bs_requests.id" },
        # osc is doing these 4 kinds of searches during submit
        'target/@project' => { cpart: 'a.target_project', joins: "LEFT JOIN bs_request_actions a ON a.bs_request_id = bs_requests.id" },
        'target/@package' => { cpart: 'a.target_package', joins: "LEFT JOIN bs_request_actions a ON a.bs_request_id = bs_requests.id" },
        'source/@project' => { cpart: 'a.source_project', joins: "LEFT JOIN bs_request_actions a ON a.bs_request_id = bs_requests.id" },
        'source/@package' => { cpart: 'a.source_package', joins: "LEFT JOIN bs_request_actions a ON a.bs_request_id = bs_requests.id" },
        'review/@by_user' => { cpart: 'r.by_user', joins: "LEFT JOIN reviews r ON r.bs_request_id = bs_requests.id" },
        'review/@by_group' => { cpart: 'r.by_group', joins: "LEFT JOIN reviews r ON r.bs_request_id = bs_requests.id" },
        'review/@by_project' => { cpart: 'r.by_project', joins: "LEFT JOIN reviews r ON r.bs_request_id = bs_requests.id" },
        'review/@by_package' => { cpart: 'r.by_package', joins: "LEFT JOIN reviews r ON r.bs_request_id = bs_requests.id" },
        'review/@state' => { cpart: 'r.state', joins: "LEFT JOIN reviews r ON r.bs_request_id = bs_requests.id" },
        'history/@who' => { cpart: 'husers.login', joins: [ "LEFT JOIN history_elements he ON (he.op_object_id = bs_requests.id AND he.type IN (\"#{HistoryElement::Request.descendants.join('","')}\") )",
                            "LEFT JOIN users husers ON he.user_id = husers.id" ] },

        'submit/target/@project' => { empty: true },
        'submit/target/@package' => { empty: true },
        'submit/source/@project' => { empty: true },
        'submit/source/@package' => { empty: true }
      }
    }
    # rubocop:enable Style/AlignHash

    @operators = [:eq, :and, :or, :neq, :gt, :lt, :gteq, :lteq]

    @base_table = ""
    @conditions = []
    @condition_values = []
    @condition_values_needed = 1 # see xpath_func_not
    @joins = []
  end

  def logger
    Rails.logger
  end

  # Careful: there is no return value, the items found are passed to the calling block
  def find(xpath)
    # logger.debug "---------------------- parsing xpath: #{xpath} -----------------------"

    begin
      @stack = @lexer.parse xpath
    rescue NoMethodError => e
      # if the input contains a [ in random place, rexml will throw
      #  undefined method `[]' for nil:NilClass
      raise IllegalXpathError, "failed to parse #{e.inspect}"
    end
    # logger.debug "starting stack: #{@stack.inspect}"

    if @stack.shift != :document
      raise IllegalXpathError, "xpath expression has to begin with root node"
    end

    if @stack.shift != :child
      raise IllegalXpathError, "xpath expression has to begin with root node"
    end

    @stack.shift
    @stack.shift
    tablename = @stack.shift
    @base_table = @tables[tablename]
    raise IllegalXpathError, "unknown table #{tablename}" unless @base_table

    while !@stack.empty?
      token = @stack.shift
      # logger.debug "next token: #{token.inspect}"
      case token
      when :ancestor
      when :ancestor_or_self
      when :attribute
      when :descendant
      when :descendant_or_self
      when :following
      when :following_sibling
      when :namespace
      when :parent
      when :preceding
      when :preceding_sibling
      when :self
        raise IllegalXpathError, "axis '#{token}' not supported"
      when :child
        if @stack.shift != :qname
          raise IllegalXpathError, "non :qname token after :child token: #{token.inspect}"
        end
        @stack.shift # namespace
        @stack.shift # node
      when :predicate
        parse_predicate([], @stack.shift)
      else
        raise IllegalXpathError, "Unhandled token '#{token.inspect}'"
      end
    end

    # logger.debug "-------------------- end parsing xpath: #{xpath} ---------------------"

    relation = nil
    order = nil
    case @base_table
    when 'packages'
      relation = Package.all
      @joins = ['LEFT JOIN package_issues ON packages.id = package_issues.package_id',
                'LEFT JOIN issues ON issues.id = package_issues.issue_id',
                'LEFT JOIN issue_trackers ON issues.issue_tracker_id = issue_trackers.id',
                'LEFT JOIN attribs ON attribs.package_id = packages.id',
                'LEFT JOIN attrib_issues ON attrib_issues.attrib_id = attribs.id',
                'LEFT JOIN issues AS attribissues ON attribissues.id = attrib_issues.issue_id',
                'LEFT JOIN issue_trackers AS attribissue_trackers ON attribissues.issue_tracker_id = attribissue_trackers.id',
                'LEFT JOIN relationships user_relation ON packages.id = user_relation.package_id',
                'LEFT JOIN relationships group_relation ON packages.id = group_relation.package_id'
               ] << @joins
    when 'projects'
      relation = Project.all
      @joins = ['LEFT JOIN relationships user_relation ON projects.id = user_relation.project_id',
                'LEFT JOIN relationships group_relation ON projects.id = group_relation.project_id'
               ] << @joins
    when 'repositories'
      relation = Repository.where("repositories.db_project_id not in (?)", Relationship.forbidden_project_ids)
      @joins = ['LEFT join path_elements path_element on path_element.parent_id=repositories.id',
                'LEFT join repositories path_repo on path_element.repository_id=path_repo.id',
                'LEFT join release_targets release_target on release_target.repository_id=repositories.id',
                'LEFT join product_update_repositories product_update_repository on product_update_repository.repository_id=release_target.target_repository_id',
                'LEFT join products product on product.id=product_update_repository.product_id '
               ] << @joins
    when 'requests'
      relation = BsRequest.all
      attrib = AttribType.find_by_namespace_and_name('OBS', 'IncidentPriority')
      # this join is only for ordering by the OBS:IncidentPriority attribute, possibly existing in source project
      @joins = [ "LEFT JOIN bs_request_actions req_order_action ON req_order_action.bs_request_id = bs_requests.id",
                 "LEFT JOIN projects req_order_project ON req_order_action.source_project = req_order_project.name",
                 "LEFT JOIN attribs req_order_attrib ON (req_order_attrib.attrib_type_id = '#{attrib.id}' AND req_order_attrib.project_id = req_order_project.id)",
                 "LEFT JOIN attrib_values req_order_attrib_value ON req_order_attrib.id = req_order_attrib_value.attrib_id" ] << @joins
      order = ["req_order_attrib_value.value DESC", :priority, :created_at]
    when 'users'
      relation = User.all
    when 'issues'
      relation = Issue.all
    when 'channels'
      relation = ChannelBinary.all
      @joins = [ 'LEFT join channel_binary_lists channel_binary_list on channel_binary_list.id=channel_binaries.channel_binary_list_id',
                 'LEFT join channels channel on channel.id=channel_binary_list.channel_id',
                 'LEFT join packages cpkg on cpkg.id=channel.package_id',
                 'LEFT join projects cprj on cprj.id=cpkg.project_id'
               ] << @joins
    when 'channel_binaries'
      relation = ChannelBinary.all
      @joins = [ 'LEFT join channel_binary_lists channel_binary_list on channel_binary_list.id=channel_binaries.channel_binary_list_id',
                 'LEFT join channels channel on channel.id=channel_binary_list.channel_id'
               ] << @joins
    when 'released_binaries'
      relation = BinaryRelease.all

      @joins = ['LEFT JOIN repositories AS release_repositories ON binary_releases.repository_id = release_repositories.id',
                'LEFT JOIN projects AS release_projects ON release_repositories.db_project_id = release_projects.id',
                'LEFT join product_media on (product_media.repository_id=release_repositories.id AND product_media.name=binary_releases.medium)',
                'LEFT join products product_ga on product_ga.id=product_media.product_id ',
                'LEFT join product_update_repositories product_update_repository on product_update_repository.repository_id=release_repositories.id',
                'LEFT join products product_update on product_update.id=product_update_repository.product_id '
               ] << @joins
      order = :binary_releasetime
    else
      logger.debug "strange base table: #{@base_table}"
    end
    cond_ary = nil
    if @conditions.count > 0
      cond_ary = [@conditions.flatten.uniq.join(" AND "), @condition_values].flatten
    end

    logger.debug("#{relation.to_sql}.find #{ { joins:      @joins.flatten.uniq.join(' '),
                                               conditions: cond_ary}.inspect }")
    relation = relation.joins(@joins.flatten.uniq.join(" ")).where(cond_ary).order(order)
    # .distinct is critical for perfomance here...
    relation.distinct.pluck(:id)
  end

  def parse_predicate(root, stack)
    # logger.debug "------------------ predicate ---------------"
    # logger.debug "-- pred_array: #{stack.inspect} --"

    raise IllegalXpathError.new "invalid predicate" if stack.nil?

    while !stack.empty?
      token = stack.shift
      case token
      when :function
        fname = stack.shift
        fname_int = "xpath_func_"+fname.gsub(/-/, "_")
        unless respond_to? fname_int
          raise IllegalXpathError, "unknown xpath function '#{fname}'"
        end
        __send__ fname_int, root, *(stack.shift)
      when :child
        t = stack.shift
        if t == :qname
          stack.shift
          root << stack.shift
          t = stack.shift
          t = stack.shift
          if t == :predicate
            parse_predicate(root, stack[0])
            stack.shift
          else
            parse_predicate(root, t)
#            stack.shift
#            raise IllegalXpathError, "unhandled token in :qname '#{t.inspect}'"
          end
          root.pop
        elsif t == :any
          # noop, already shifted
        else
          raise IllegalXpathError, "unhandled token '#{t.inspect}'"
        end
      when *@operators
        opname = token.to_s
        opname_int = "xpath_op_"+opname
        unless respond_to? opname_int
          raise IllegalXpathError, "unhandled xpath operator '#{opname}'"
        end
        __send__ opname_int, root, *(stack)
        stack = []
      else
        raise IllegalXpathError, "illegal token X '#{token.inspect}'"
      end
    end

    # logger.debug "-------------- predicate finished ----------"
  end

  def evaluate_expr(expr, root, escape = false)
    table = @base_table
    a = Array.new
    while !expr.empty?
      token = expr.shift
      case token
      when :child
        expr.shift # qname
        expr.shift # namespace
        a << expr.shift
      when :attribute
        expr.shift #:qname token
        expr.shift # namespace
        a << "@"+expr.shift
      when :literal
        value = (escape ? escape_for_like(expr.shift) : expr.shift)
        if @last_key && @attribs[table][@last_key][:empty]
          return ""
        end
        if @last_key && @attribs[table][@last_key][:split]
          tvalues = value.split(@attribs[table][@last_key][:split])
          if tvalues.size != 2
            raise XpathEngine::IllegalXpathError, "attributes must be $NAMESPACE:$NAME"
          end
          @condition_values_needed.times { @condition_values << tvalues }
        elsif @last_key && @attribs[table][@last_key][:double]
          @condition_values_needed.times { @condition_values << [value, value] }
        else
          @condition_values_needed.times { @condition_values << value }
        end
        @last_key = nil
        return "?"
      else
        raise IllegalXpathError, "illegal token: '#{token.inspect}'"
      end
    end
    key = (root+a).join "/"
    # this is a wild hack - we need to save the key, so we can possibly split the next
    # literal. The real fix is to translate the xpath into SQL directly
    @last_key = key
    raise IllegalXpathError, "unable to evaluate '#{key}' for '#{table}'" unless @attribs[table] && @attribs[table].has_key?(key)
    # logger.debug "-- found key: #{key} --"
    if @attribs[table][key][:empty]
      return nil
    end
    if @attribs[table][key][:joins]
      @joins << @attribs[table][key][:joins]
    end
    if @attribs[table][key][:split]
      @split = @attribs[table][key][:split]
    end
    @attribs[table][key][:cpart]
  end

  def escape_for_like(str)
    str.gsub(/([_%])/, '\\\\\1')
  end

  def xpath_op_eq(root, lv, rv)
    # logger.debug "-- xpath_op_eq(#{lv.inspect}, #{rv.inspect}) --"

    lval = evaluate_expr(lv, root)
    rval = evaluate_expr(rv, root)

    if lval.nil? || rval.nil?
      condition = '0'
    else
      condition = "#{lval} = #{rval}"
    end
    # logger.debug "-- condition: [#{condition}]"

    @conditions << condition
  end

  def xpath_op_neq(root, lv, rv)
    # logger.debug "-- xpath_op_neq(#{lv.inspect}, #{rv.inspect}) --"

    lval = evaluate_expr(lv, root)
    rval = evaluate_expr(rv, root)

    if lval.nil? || rval.nil?
      condition = '1'
    else
      condition = "#{lval} != #{rval}"
    end

    # logger.debug "-- condition: [#{condition}]"

    @conditions << condition
  end

  def xpath_op_gt(root, lv, rv)
    lval = evaluate_expr(lv, root)
    rval = evaluate_expr(rv, root)

    @conditions << "#{lval} > #{rval}"
  end

  def xpath_op_gteq(root, lv, rv)
    lval = evaluate_expr(lv, root)
    rval = evaluate_expr(rv, root)

    @conditions << "#{lval} >= #{rval}"
  end

  def xpath_op_lt(root, lv, rv)
    lval = evaluate_expr(lv, root)
    rval = evaluate_expr(rv, root)

    @conditions << "#{lval} < #{rval}"
  end

  def xpath_op_lteq(root, lv, rv)
    lval = evaluate_expr(lv, root)
    rval = evaluate_expr(rv, root)

    @conditions << "#{lval} <= #{rval}"
  end

  def xpath_op_and(root, lv, rv)
    # logger.debug "-- xpath_op_and(#{lv.inspect}, #{rv.inspect}) --"
    parse_predicate(root, lv)
    lv_cond = @conditions.pop
    parse_predicate(root, rv)
    rv_cond = @conditions.pop

    condition = "((#{lv_cond}) AND (#{rv_cond}))"
    # logger.debug "-- condition: [#{condition}]"

    @conditions << condition
  end

  def xpath_op_or(root, lv, rv)
    # logger.debug "-- xpath_op_or(#{lv.inspect}, #{rv.inspect}) --"

    parse_predicate(root, lv)
    lv_cond = @conditions.pop
    parse_predicate(root, rv)
    rv_cond = @conditions.pop

    if lv_cond == '0'
      condition = rv_cond
    elsif rv_cond == '0'
      condition = lv_cond
    else
      condition = "((#{lv_cond}) OR (#{rv_cond}))"
    end
    # logger.debug "-- condition: [#{condition}]"

    @conditions << condition
  end

  def xpath_func_contains(root, haystack, needle)
    # logger.debug "-- xpath_func_contains(#{haystack.inspect}, #{needle.inspect}) --"

    hs = evaluate_expr(haystack, root)
    ne = evaluate_expr(needle, root, true)

    if hs.nil? || ne.nil?
      condition = '0'
    else
      condition = "LOWER(#{hs}) LIKE LOWER(CONCAT('%',#{ne},'%'))"
    end
    # logger.debug "-- condition : [#{condition}]"

    @conditions << condition
  end

  def xpath_func_boolean(root, expr)
    # logger.debug "-- xpath_func_boolean(#{expr}) --"

    @condition_values_needed = 2
    cond = evaluate_expr(expr, root)

    condition = "NOT (NOT #{cond} OR ISNULL(#{cond}))"
    # logger.debug "-- condition : [#{condition}]"

    @condition_values_needed = 1
    @conditions << condition
  end

  def xpath_func_not(root, expr)
    # logger.debug "-- xpath_func_not(#{expr}) --"

    # An XPath query like "not(@foo='bar')" in the SQL world means, all rows where the 'foo' column
    # is not 'bar' and where it is NULL. As a result, 'cond' below occurs twice in the resulting SQL.
    # This implies that the values to # fill those 'p.name = ?' fragments (@condition_values) have to
    # occor twice, hence the @condition_values_needed counter. For our example, the resulting SQL will
    # look like:
    #
    #   SELECT * FROM projects p LEFT JOIN db_project_types t ON p.type_id = t.id
    #            WHERE (NOT t.name = 'maintenance_incident' OR t.name IS NULL);
    #
    # Note that this can result in bloated SQL statements, so some trust in the query optimization
    # capabilities of your DBMS is neeed :-)

    if [:child, :attribute].include? expr.first
       # for incorrect writings of not(@name) as existens check
       # we used to support it :/
       @condition_values_needed = 2 if expr.first == :attribute
       cond = evaluate_expr(expr, root)
       condition = "(NOT #{cond} OR ISNULL(#{cond}))"
       @condition_values_needed = 1
    else
       parse_predicate(root, expr)
       condition = "(#{@conditions.pop})"
    end
    # logger.debug "-- condition : [#{condition}]"
    @conditions << condition
  end

  def xpath_func_starts_with(root, x, y)
    # logger.debug "-- xpath_func_starts_with(#{x.inspect}, #{y.inspect}) --"

    s1 = evaluate_expr(x, root)
    s2 = evaluate_expr(y, root, true)

    condition = "#{s1} LIKE CONCAT(#{s2},'%')"
    # logger.debug "-- condition: [#{condition}]"

    @conditions << condition
  end

  def xpath_func_ends_with(root, x, y)
    # logger.debug "-- xpath_func_ends_with(#{x.inspect}, #{y.inspect}) --"

    s1 = evaluate_expr(x, root)
    s2 = evaluate_expr(y, root, true)

    condition = "#{s1} LIKE CONCAT('%',#{s2})"
    # logger.debug "-- condition: [#{condition}]"

    @conditions << condition
  end
end
# rubocop:enable Metrics/LineLength
