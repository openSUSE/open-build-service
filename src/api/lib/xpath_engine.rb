# rubocop:disable Metrics/MethodLength
class XpathEngine
  require 'rexml/parsers/xpathparser'

  class IllegalXpathError < ArgumentError; end

  def initialize
    @lexer = REXML::Parsers::XPathParser.new

    @tables = {
      'attribute' => 'attribs',
      'package' => 'packages',
      'project' => 'projects',
      'person' => 'users',
      'repository' => 'repositories',
      'issue' => 'issues',
      'request' => 'requests',
      'channel' => 'channels',
      'channel_binary' => 'channel_binaries',
      'released_binary' => 'released_binaries'
    }

    @attribs = {
      'packages' => {
        '@project' => { cpart: 'projects.name',
                        joins: 'LEFT JOIN projects ON packages.project_id=projects.id' },
        '@name' => { cpart: 'packages.name' },
        'title' => { cpart: 'packages.title' },
        'description' => { cpart: 'packages.description' },
        'scmsync' => { cpart: 'packages.scmsync' },
        'kind' => { cpart: 'package_kinds.kind', joins: ['LEFT JOIN package_kinds ON package_kinds.package_id = packages.id'] },
        'devel/@project' => { cpart: 'projs.name', joins:         ['left join packages devels on packages.develpackage_id = devels.id',
                                                                   'left join projects projs on devels.project_id=projs.id'] },
        'devel/@package' => { cpart: 'develpackage.name', joins:  ['LEFT JOIN packages develpackage ON develpackage.id = packages.develpackage_id'] },
        'issue/@state' => { cpart: 'issues.state' },
        'issue/@name' => { cpart: 'issues.name' },
        'issue/@tracker' => { cpart: 'issue_trackers.name' },
        'issue/@change' => { cpart: 'package_issues.change' },
        'issue/owner/@email' => { cpart: 'users.email', joins:        ['LEFT JOIN users ON users.id = issues.owner_id'] },
        'issue/owner/@login' => { cpart: 'users.login', joins:        ['LEFT JOIN users ON users.id = issues.owner_id'] },
        'attribute_issue/@state' => { cpart: 'attribissues.state' },
        'attribute_issue/@name' => { cpart: 'attribissues.name' },
        'attribute_issue/@tracker' => { cpart: 'attribissue_trackers.name' },
        'attribute_issue/owner/@email' => { cpart: 'users.email', joins:        ['LEFT JOIN users ON users.id = attribissues.owner_id'] },
        'attribute_issue/owner/@login' => { cpart: 'users.login', joins:        ['LEFT JOIN users ON users.id = attribissues.owner_id'] },
        'person/@userid' => { cpart: 'users.login', joins:        ['LEFT JOIN users ON users.id = user_relation.user_id'] },
        'person/@role' => { cpart: 'ppr.title', joins: ['LEFT JOIN roles AS ppr ON user_relation.role_id = ppr.id'] },
        'group/@groupid' => { cpart: 'groups.title', joins: ['LEFT JOIN groups ON groups.id = group_relation.group_id'] },
        'group/@role' => { cpart: 'gpr.title', joins: ['LEFT JOIN roles AS gpr ON group_relation.role_id = gpr.id'] },
        'attribute/@name' => { cpart: 'attrib_namespaces.name = ? AND attrib_types.name', split: ':',
                               joins: ['LEFT JOIN attrib_types ON attribs.attrib_type_id = attrib_types.id',
                                       'LEFT JOIN attrib_namespaces ON attrib_types.attrib_namespace_id = attrib_namespaces.id',
                                       'LEFT JOIN attribs AS attribsprj ON attribsprj.project_id = packages.project_id', # include also, when set in project
                                       'LEFT JOIN attrib_types AS attrib_typesprj ON attribsprj.attrib_type_id = attrib_typesprj.id',
                                       'LEFT JOIN attrib_namespaces AS attrib_namespacesprj ON attrib_typesprj.attrib_namespace_id = attrib_namespacesprj.id'] },
        'project/attribute/@name' => { cpart: 'attrib_namespaces_proj.name = ? AND attrib_types_proj.name', split: ':',
                                       joins: ['LEFT JOIN attribs AS attribs_proj ON attribs_proj.project_id = packages.project_id',
                                               'LEFT JOIN attrib_types AS attrib_types_proj ON attribs_proj.attrib_type_id = attrib_types_proj.id',
                                               'LEFT JOIN attrib_namespaces AS attrib_namespaces_proj ON attrib_types_proj.attrib_namespace_id = attrib_namespaces_proj.id'] }
      },
      'projects' => {
        '@name' => { cpart: 'projects.name' },
        '@kind' => { cpart: 'projects.kind' },
        'title' => { cpart: 'projects.title' },
        'description' => { cpart: 'projects.description' },
        'url' => { cpart: 'projects.url' },
        'remoteurl' => { cpart: 'projects.remoteurl' },
        'scmsync' => { cpart: 'projects.scmsync' },
        'maintenance/maintains/@project' => { cpart: 'maintains_prj.name', joins: [
          'LEFT JOIN maintained_projects AS maintained_prj ON projects.id = maintained_prj.maintenance_project_id',
          'LEFT JOIN projects AS maintains_prj ON maintained_prj.project_id = maintains_prj.id'
        ] },
        'person/@userid' => { cpart: 'users.login', joins: ['LEFT JOIN users ON users.id = user_relation.user_id'] },
        'person/@role' => { cpart: 'ppr.title', joins: ['LEFT JOIN roles AS ppr ON user_relation.role_id = ppr.id'] },
        'group/@groupid' => { cpart: 'groups.title', joins: ['LEFT JOIN groups ON groups.id = group_relation.group_id'] },
        'group/@role' => { cpart: 'gpr.title', joins: ['LEFT JOIN roles AS gpr ON group_relation.role_id = gpr.id'] },
        'repository/@name' => { cpart: 'repositories.name',
                                joins: ['join repositories on repositories.db_project_id=projects.id'] },
        'repository/path/@project' => { cpart: 'childs.name',
                                        joins: ['join repositories r on r.db_project_id=projects.id',
                                                'join path_elements pe on pe.parent_id=r.id',
                                                'join repositories r2 on r2.id=pe.repository_id',
                                                'join projects childs on childs.id=r2.db_project_id'] },
        'repository/releasetarget/@trigger' => { cpart: 'rt.trigger',
                                                 joins: ['join repositories r on r.db_project_id=projects.id',
                                                         'join release_targets rt on rt.repository_id=r.id'] },
        'package/@name' => { cpart: 'packs.name', joins: ['LEFT JOIN packages AS packs ON packs.project_id = projects.id'] },
        'attribute/@name' => { cpart: 'attrib_namespaces.name = ? AND attrib_types.name', split: ':',
                               joins: ['LEFT JOIN attribs ON attribs.project_id = projects.id',
                                       'LEFT JOIN attrib_types ON attribs.attrib_type_id = attrib_types.id',
                                       'LEFT JOIN attrib_namespaces ON attrib_types.attrib_namespace_id = attrib_namespaces.id'] }
      },
      'repositories' => {
        '@project' => { cpart: 'pr.name', joins: 'LEFT JOIN projects AS pr ON repositories.db_project_id=pr.id' },
        '@name' => { cpart: 'repositories.name' },
        'path/@project' => { cpart: 'pathrepoprj.name',
                             joins: ['LEFT join projects pathrepoprj on path_repo.db_project_id=pathrepoprj.id'] },
        'path/@repository' => { cpart: 'path_repo.name' },
        'targetproduct/@project' => { cpart: 'tpprj.name',
                                      joins: ['LEFT join packages tppkg on tppkg.id=product.package_id ',
                                              'LEFT join projects tpprj on tpprj.id=tppkg.project_id '] },
        'targetproduct/@arch' => { cpart: 'tppa.name',
                                   joins: ['LEFT join architectures tppa on tppa.id=product_update_repository.arch_filter_id '] },
        'targetproduct/@name' => { cpart: 'product.name' },
        'targetproduct/@baseversion' => { cpart: 'product.baseversion' },
        'targetproduct/@patchlevel' => { cpart: 'product.patchlevel' },
        'targetproduct/@version' => { cpart: 'product.version' }
      },
      'channels' => {
        'binary/@name' => { cpart: 'channel_binaries.name' },
        'binary/@binaryarch' => { cpart: 'channel_binaries.binaryarch' },
        'binary/@package' => { cpart: 'channel_binaries.package' },
        'binary/@supportstatus' => { cpart: 'supportstatus' },
        '@package' => { cpart: 'cpkg.name' },
        '@project' => { cpart: 'cprj.name' },
        'target/disabled' => { cpart: 'ufdct.disabled', joins: ['LEFT join channel_targets ufdct on ufdct.channel_id=channel.id'] },
        'target/updatefor/@project' => { cpart: 'puprj.name',
                                         joins: ['LEFT join channel_targets ufct on ufct.channel_id=channel.id',
                                                 'LEFT join product_update_repositories pur on pur.repository_id=ufct.repository_id',
                                                 'LEFT join products pun on pun.id=pur.product_id ',
                                                 'LEFT join packages pupkg on pupkg.id=pun.package_id ',
                                                 'LEFT join projects puprj on puprj.id=pupkg.project_id '] },
        'target/updatefor/@product' => { cpart: 'pupn.name',
                                         joins: ['LEFT join channel_targets ufnct on ufnct.channel_id=channel.id',
                                                 'LEFT join product_update_repositories pnur on pnur.repository_id=ufnct.repository_id',
                                                 'LEFT join products pupn on pupn.id=pnur.product_id '] }
      },
      'channel_binaries' => {
        '@name' => { cpart: 'channel_binaries.name' },
        '@binaryarch' => { cpart: 'channel_binaries.binaryarch' },
        '@package' => { cpart: 'channel_binaries.package' },
        '@project' => { cpart: 'cprj.name', joins: ['LEFT join packages cpkg on cpkg.id=channel.package_id',
                                                    'LEFT join projects cprj on cprj.id=cpkg.project_id'] },
        '@supportstatus' => { cpart: 'supportstatus' },
        'target/disabled' => { cpart: 'ufdct.disabled', joins: ['LEFT join channel_targets ufdct on ufdct.channel_id=channel.id'] },
        'updatefor/@project' => { cpart: 'puprj.name', joins:     ['LEFT join channel_targets ufct on ufct.channel_id=channel.id',
                                                                   'LEFT join product_update_repositories pur on pur.repository_id=ufct.repository_id',
                                                                   'LEFT join products pun on pun.id=pur.product_id ',
                                                                   'LEFT join packages pupkg on pupkg.id=pun.package_id ',
                                                                   'LEFT join projects puprj on puprj.id=pupkg.project_id '] },
        'updatefor/@product' => { cpart: 'pupn.name', joins:      ['LEFT join channel_targets ufnct on ufnct.channel_id=channel.id',
                                                                   'LEFT join product_update_repositories pnur on pnur.repository_id=ufnct.repository_id',
                                                                   'LEFT join products pupn on pupn.id=pnur.product_id '] }
      },
      'released_binaries' => {
        '@name' => { cpart: 'binary_name' },
        '@version' => { cpart: 'binary_version' },
        '@release' => { cpart: 'binary_release' },
        '@arch' => { cpart: 'binary_arch' },
        '@medium' => { cpart: 'medium' },
        'disturl' => { cpart: 'binary_disturl' },
        'binaryid' => { cpart: 'binary_id' },
        'cpeid' => { cpart: 'binary_cpeid' },
        'supportstatus' => { cpart: 'binary_supportstatus' },
        'updateinfo/@id' => { cpart: 'binary_updateinfo' },
        'updateinfo/@version' => { cpart: 'binary_updateinfo_version' },
        'operation' => { cpart: 'operation' },
        'build/@time' => { cpart: 'binary_buildtime' },
        'build/@binaryid' => { cpart: 'binary_id' },
        'modify/@time' => { cpart: 'modify_time' },
        'obsolete/@time' => { cpart: 'obsolete_time' },
        'repository/@project' => { cpart: 'release_projects.name' },
        'repository/@name' => { cpart: 'release_repositories.name' },
        'publish/@time' => { cpart: 'binary_releasetime' },
        'publish/@package' => { cpart: 'ppkg.name', joins: ['LEFT join packages ppkg on ppkg.id=release_package_id'] },
        'publish/@flavor' => { cpart: 'flavor' },
        'updatefor/@project' => { cpart: 'puprj.name', joins: ['LEFT join packages pupkg on pupkg.id=product_update.package_id ',
                                                               'LEFT join projects puprj on puprj.id=pupkg.project_id '] },
        'updatefor/@arch' => { cpart: 'pupa.name',
                               joins: ['LEFT join architectures pupa on pupa.id=product_update_repository.arch_filter_id '] },
        'updatefor/@product' => { cpart: 'product_update.name' },
        'updatefor/@baseversion' => { cpart: 'product_update.baseversion' },
        'updatefor/@patchlevel' => { cpart: 'product_update.patchlevel' },
        'updatefor/@version' => { cpart: 'product_update.version' },
        'product/@project' => { cpart: 'pprj.name', joins: ['LEFT join packages ppkg on ppkg.id=product_ga.package_id ',
                                                            'LEFT join projects pprj on pprj.id=ppkg.project_id '] },
        'product/@version' => { cpart: 'product_ga.version' },
        'product/@release' => { cpart: 'product_ga.release' },
        'product/@baseversion' => { cpart: 'product_ga.baseversion' },
        'product/@patchlevel' => { cpart: 'product_ga.patchlevel' },
        'product/@name' => { cpart: 'product_ga.name' },
        'product/@arch' => { cpart: 'ppna.name', joins: ['LEFT join architectures ppna on ppna.id=product_media.arch_filter_id '] },
        'product/@medium' => { cpart: 'product_media.name' }
      },
      'users' => {
        '@login' => { cpart: 'users.login' },
        '@email' => { cpart: 'users.email' },
        '@realname' => { cpart: 'users.realname' },
        '@state' => { cpart: 'users.state' }
      },
      'issues' => {
        '@name' => { cpart: 'issues.name' },
        '@state' => { cpart: 'issues.state' },
        '@tracker' => { cpart: 'issue_trackers.name', joins: 'LEFT JOIN issue_trackers ON issues.issue_tracker_id = issue_trackers.id' },
        'owner/@email' => { cpart: 'users.email', joins:         ['LEFT JOIN users ON users.id = issues.owner_id'] },
        'owner/@login' => { cpart: 'users.login', joins:         ['LEFT JOIN users ON users.id = issues.owner_id'] }
      },
      'requests' => {
        '@id' => { cpart: 'bs_requests.number' },
        '@creator' => { cpart: 'bs_requests.creator' },
        'state/@name' => { cpart: 'bs_requests.status' },
        'state/@who' => { cpart: 'bs_requests.commenter' },
        'state/@when' => { cpart: 'bs_requests.updated_at' },
        'action/@type' => { cpart: 'a.type',
                            joins: 'LEFT JOIN bs_request_actions a ON a.bs_request_id = bs_requests.id' },
        'action/grouped/@id' => { cpart: 'gr.number',
                                  joins: ['LEFT JOIN bs_request_actions a ON a.bs_request_id = bs_requests.id',
                                          'LEFT JOIN group_request_requests g on g.bs_request_action_group_id = a.id',
                                          'LEFT JOIN bs_requests gr on gr.id = g.bs_request_id'] },
        'action/target/@project' => { cpart: 'a.target_project', joins: 'LEFT JOIN bs_request_actions a ON a.bs_request_id = bs_requests.id' },
        'action/target/@package' => { cpart: 'a.target_package', joins: 'LEFT JOIN bs_request_actions a ON a.bs_request_id = bs_requests.id' },
        'action/source/@project' => { cpart: 'a.source_project', joins: 'LEFT JOIN bs_request_actions a ON a.bs_request_id = bs_requests.id' },
        'action/source/@package' => { cpart: 'a.source_package', joins: 'LEFT JOIN bs_request_actions a ON a.bs_request_id = bs_requests.id' },
        # osc is doing these 4 kinds of searches during submit
        'target/@project' => { cpart: 'a.target_project', joins: 'LEFT JOIN bs_request_actions a ON a.bs_request_id = bs_requests.id' },
        'target/@package' => { cpart: 'a.target_package', joins: 'LEFT JOIN bs_request_actions a ON a.bs_request_id = bs_requests.id' },
        'source/@project' => { cpart: 'a.source_project', joins: 'LEFT JOIN bs_request_actions a ON a.bs_request_id = bs_requests.id' },
        'source/@package' => { cpart: 'a.source_package', joins: 'LEFT JOIN bs_request_actions a ON a.bs_request_id = bs_requests.id' },
        'review/@by_user' => { cpart: 'r.by_user', joins: 'LEFT JOIN reviews r ON r.bs_request_id = bs_requests.id' },
        'review/@by_group' => { cpart: 'r.by_group', joins: 'LEFT JOIN reviews r ON r.bs_request_id = bs_requests.id' },
        'review/@by_project' => { cpart: 'r.by_project', joins: 'LEFT JOIN reviews r ON r.bs_request_id = bs_requests.id' },
        'review/@by_package' => { cpart: 'r.by_package', joins: 'LEFT JOIN reviews r ON r.bs_request_id = bs_requests.id' },
        'review/@when' => { cpart: 'bs_requests.updated_at', joins: 'LEFT JOIN reviews r ON r.bs_request_id = bs_requests.id' },
        'review/@state' => { cpart: 'r.state', joins: 'LEFT JOIN reviews r ON r.bs_request_id = bs_requests.id' },
        'review/history/@when' => { cpart: 'he.created_at',
                                    joins: 'LEFT JOIN reviews r ON r.bs_request_id = bs_requests.id ' \
                                           "LEFT JOIN history_elements he ON (he.op_object_id = r.id AND he.type IN (\"#{HistoryElement::Review.descendants.join('","')}\") )" },
        'history/@when' => { cpart: 'he.created_at', joins: "LEFT JOIN history_elements he ON (he.op_object_id = bs_requests.id AND he.type IN (\"#{HistoryElement::Request.descendants.join('","')}\") )" },
        'history/@who' => { cpart: 'husers.login', joins: ["LEFT JOIN history_elements he ON (he.op_object_id = bs_requests.id AND he.type IN (\"#{HistoryElement::Request.descendants.join('","')}\") )",
                                                           'LEFT JOIN users husers ON he.user_id = husers.id'] },

        'submit/target/@project' => { empty: true },
        'submit/target/@package' => { empty: true },
        'submit/source/@project' => { empty: true },
        'submit/source/@package' => { empty: true }
      }
    }

    @operators = %i[eq and or neq gt lt gteq lteq]

    @base_table = ''
    @conditions = []
    @condition_values = []
    @condition_values_needed = 1 # see xpath_func_not
    @joins = []
  end

  delegate :logger, to: :Rails

  # Careful: there is no return value, the items found are passed to the calling block
  def find(xpath)
    # logger.debug "---------------------- parsing xpath: #{xpath} -----------------------"

    begin
      @stack = @lexer.parse xpath
    rescue NoMethodError
      # if the input contains a [ in random place, rexml will throw
      #  undefined method `[]' for nil:NilClass
      raise IllegalXpathError, 'failed to parse xpath expression'
    rescue REXML::ParseException => e
      raise IllegalXpathError, e.message
    end
    # logger.debug "starting stack: #{@stack.inspect}"

    raise IllegalXpathError, 'xpath expression has to begin with root node' if @stack.shift != :document

    raise IllegalXpathError, 'xpath expression has to begin with root node' if @stack.shift != :child

    @stack.shift
    @stack.shift
    tablename = @stack.shift
    @base_table = @tables[tablename]
    raise IllegalXpathError, "unknown table #{tablename}" unless @base_table

    until @stack.empty?
      token = @stack.shift
      # logger.debug "next token: #{token.inspect}"
      case token
      when :ancestor, :ancestor_or_self, :attribute,
           :descendant, :descendant_or_self, :following, :following_sibling,
           :namespace, :parent, :preceding, :preceding_sibling
        nil
      when :self
        raise IllegalXpathError, "axis '#{token}' not supported"
      when :child
        raise IllegalXpathError, "non :qname token after :child token: #{token.inspect}" if @stack.shift != :qname

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
                'LEFT JOIN relationships group_relation ON packages.id = group_relation.package_id'] << @joins
    when 'projects'
      relation = Project.all
      @joins = ['LEFT JOIN relationships user_relation ON projects.id = user_relation.project_id',
                'LEFT JOIN relationships group_relation ON projects.id = group_relation.project_id'] << @joins
    when 'repositories'
      relation = Repository.where.not('repositories.db_project_id' => Relationship.forbidden_project_ids)
      @joins = ['LEFT join path_elements path_element on path_element.parent_id=repositories.id',
                'LEFT join repositories path_repo on path_element.repository_id=path_repo.id',
                'LEFT join release_targets release_target on release_target.repository_id=repositories.id',
                'LEFT join product_update_repositories product_update_repository on product_update_repository.repository_id=release_target.target_repository_id',
                'LEFT join products product on product.id=product_update_repository.product_id '] << @joins
    when 'requests'
      relation = BsRequest.all
      attrib = AttribType.find_by_namespace_and_name('OBS', 'IncidentPriority')
      # this join is only for ordering by the OBS:IncidentPriority attribute, possibly existing in source project
      @joins = ['LEFT JOIN bs_request_actions req_order_action ON req_order_action.bs_request_id = bs_requests.id',
                'LEFT JOIN projects req_order_project ON req_order_action.source_project = req_order_project.name',
                "LEFT JOIN attribs req_order_attrib ON (req_order_attrib.attrib_type_id = '#{attrib.id}' AND req_order_attrib.project_id = req_order_project.id)",
                'LEFT JOIN attrib_values req_order_attrib_value ON req_order_attrib.id = req_order_attrib_value.attrib_id'] << @joins
      order = ['req_order_attrib_value.value DESC', :priority, :created_at]
    when 'users'
      relation = User.not_deleted
    when 'issues'
      relation = Issue.all
    when 'channels'
      relation = ChannelBinary.all
      @joins = ['LEFT join channel_binary_lists channel_binary_list on channel_binary_list.id=channel_binaries.channel_binary_list_id',
                'LEFT join channels channel on channel.id=channel_binary_list.channel_id',
                'LEFT join packages cpkg on cpkg.id=channel.package_id',
                'LEFT join projects cprj on cprj.id=cpkg.project_id'] << @joins
    when 'channel_binaries'
      relation = ChannelBinary.all
      @joins = ['LEFT join channel_binary_lists channel_binary_list on channel_binary_list.id=channel_binaries.channel_binary_list_id',
                'LEFT join channels channel on channel.id=channel_binary_list.channel_id'] << @joins
    when 'released_binaries'
      relation = BinaryRelease.all

      @joins = ['LEFT JOIN repositories AS release_repositories ON binary_releases.repository_id = release_repositories.id',
                'LEFT JOIN projects AS release_projects ON release_repositories.db_project_id = release_projects.id',
                'LEFT join product_media on (product_media.repository_id=release_repositories.id AND product_media.name=binary_releases.medium COLLATE utf8mb4_unicode_ci)',
                'LEFT join products product_ga on product_ga.id=product_media.product_id ',
                'LEFT join product_update_repositories product_update_repository on product_update_repository.repository_id=release_repositories.id',
                'LEFT join products product_update on product_update.id=product_update_repository.product_id '] << @joins
      order = :binary_releasetime
    else
      logger.debug "strange base table: #{@base_table}"
    end
    cond_ary = nil
    cond_ary = [@conditions.flatten.uniq.join(' AND '), @condition_values].flatten if @conditions.count.positive?

    logger.debug("#{relation.to_sql}.find #{{ joins: @joins.flatten.uniq.join(' '),
                                              conditions: cond_ary }.inspect}")
    relation = relation.joins(@joins.flatten.uniq.join(' ')).where(cond_ary).order(order)
    # .distinct is critical for perfomance here...
    relation.distinct.pluck(:id)
  end

  def parse_predicate(root, stack)
    # logger.debug "------------------ predicate ---------------"
    # logger.debug "-- pred_array: #{stack.inspect} --"

    raise IllegalXpathError, 'invalid predicate' if stack.nil?

    until stack.empty?
      token = stack.shift
      case token
      when :function
        fname = stack.shift
        fname_int = "xpath_func_#{fname.tr('-', '_')}"
        raise IllegalXpathError, "unknown xpath function '#{fname}'" unless respond_to?(fname_int)

        __send__(fname_int, root, *stack.shift)
      when :child
        qtype = stack.shift
        case qtype
        when :qname
          stack.shift
          root << stack.shift
          qtype = stack.shift
          qtype = stack.shift
          if qtype == :predicate
            parse_predicate(root, stack[0])
            stack.shift
          elsif qtype.nil? || qtype == :qname
            # just a plain existence test
            xpath_func_boolean(root, stack)
          else
            parse_predicate(root, qtype)
          end
          root.pop
        when :any
          # noop, already shifted
        else
          raise IllegalXpathError, "unhandled token '#{t.inspect}'"
        end
      when *@operators
        opname = token.to_s
        opname_int = "xpath_op_#{opname}"
        raise IllegalXpathError, "unhandled xpath operator '#{opname}'" unless respond_to?(opname_int)

        __send__(opname_int, root, *stack)
        stack = []
      else
        raise IllegalXpathError, "illegal token X '#{token.inspect}'"
      end
    end

    # logger.debug "-------------- predicate finished ----------"
  end

  def evaluate_expr(expr, root, escape: false)
    table = @base_table
    a = []
    until expr.empty?
      token = expr.shift
      case token
      when ''
        a << expr.shift
      when :child
        expr.shift # qname
        expr.shift # namespace
        a << expr.shift
      when :attribute
        expr.shift # :qname token
        expr.shift # namespace
        a << "@#{expr.shift}"
      when :literal
        value = (escape ? escape_for_like(expr.shift) : expr.shift)
        return '' if @last_key && @attribs[table][@last_key][:empty]

        if @last_key && @attribs[table][@last_key][:split]
          tvalues = value.split(@attribs[table][@last_key][:split])
          raise IllegalXpathError, 'attributes must be $NAMESPACE:$NAME' if tvalues.size != 2

          @condition_values_needed.times { @condition_values << tvalues }
        else
          @condition_values_needed.times { @condition_values << value }
        end
        @last_key = nil
        return '?'
      else
        raise IllegalXpathError, "illegal token: '#{token.inspect}'"
      end
    end
    key = (root + a).join('/')
    # this is a wild hack - we need to save the key, so we can possibly split the next
    # literal. The real fix is to translate the xpath into SQL directly
    @last_key = key
    raise IllegalXpathError, "unable to evaluate '#{key}' for '#{table}'" unless @attribs[table] && @attribs[table].key?(key)
    # logger.debug "-- found key: #{key} --"
    return if @attribs[table][key][:empty]

    @joins << @attribs[table][key][:joins] if @attribs[table][key][:joins]
    @split = @attribs[table][key][:split] if @attribs[table][key][:split]
    @attribs[table][key][:cpart]
  end

  def escape_for_like(str)
    str.gsub(/([_%])/, '\\\\\1')
  end

  def xpath_op_eq(root, left_value, right_value)
    # logger.debug "-- xpath_op_eq(#{left_value.inspect}, #{right_value.inspect}) --"

    lval = evaluate_expr(left_value, root)
    rval = evaluate_expr(right_value, root)

    condition = if lval.nil? || rval.nil?
                  '0'
                else
                  "#{lval} = #{rval}"
                end
    # logger.debug "-- condition: [#{condition}]"

    @conditions << condition
  end

  def xpath_op_neq(root, left_value, right_value)
    # logger.debug "-- xpath_op_neq(#{left_value.inspect}, #{right_value.inspect}) --"

    lval = evaluate_expr(left_value, root)
    rval = evaluate_expr(right_value, root)

    condition = if lval.nil? || rval.nil?
                  '1'
                else
                  "#{lval} != #{rval}"
                end

    # logger.debug "-- condition: [#{condition}]"

    @conditions << condition
  end

  def xpath_op_gt(root, left_value, right_value)
    lval = evaluate_expr(left_value, root)
    rval = evaluate_expr(right_value, root)

    @conditions << "#{lval} > #{rval}"
  end

  def xpath_op_gteq(root, left_value, right_value)
    lval = evaluate_expr(left_value, root)
    rval = evaluate_expr(right_value, root)

    @conditions << "#{lval} >= #{rval}"
  end

  def xpath_op_lt(root, left_value, right_value)
    lval = evaluate_expr(left_value, root)
    rval = evaluate_expr(right_value, root)

    @conditions << "#{lval} < #{rval}"
  end

  def xpath_op_lteq(root, left_value, right_value)
    lval = evaluate_expr(left_value, root)
    rval = evaluate_expr(right_value, root)

    @conditions << "#{lval} <= #{rval}"
  end

  def xpath_op_and(root, left_value, right_value)
    # logger.debug "-- xpath_op_and(#{left_value.inspect}, #{right_value.inspect}) --"
    parse_predicate(root, left_value)
    lv_cond = @conditions.pop
    parse_predicate(root, right_value)
    rv_cond = @conditions.pop

    condition = "((#{lv_cond}) AND (#{rv_cond}))"
    # logger.debug "-- condition: [#{condition}]"

    @conditions << condition
  end

  def xpath_op_or(root, left_value, right_value)
    # logger.debug "-- xpath_op_or(#{left_value.inspect}, #{right_value.inspect}) --"

    parse_predicate(root, left_value)
    lv_cond = @conditions.pop
    parse_predicate(root, right_value)
    rv_cond = @conditions.pop

    condition = if lv_cond == '0'
                  rv_cond
                elsif rv_cond == '0'
                  lv_cond
                else
                  "((#{lv_cond}) OR (#{rv_cond}))"
                end
    # logger.debug "-- condition: [#{condition}]"

    @conditions << condition
  end

  def xpath_func_contains(root, haystack, needle)
    # logger.debug "-- xpath_func_contains(#{haystack.inspect}, #{needle.inspect}) --"

    hs = evaluate_expr(haystack, root)
    ne = evaluate_expr(needle, root, escape: true)

    condition = if hs.nil? || ne.nil?
                  '0'
                else
                  "LOWER(#{hs}) LIKE LOWER(CONCAT('%',#{ne},'%'))"
                end
    # logger.debug "-- condition : [#{condition}]"

    @conditions << condition
  end

  def xpath_func_boolean(root, expr)
    # logger.debug "-- xpath_func_boolean(#{expr}) --"

    cond = evaluate_expr(expr, root)
    condition = "NOT (ISNULL(#{cond}))"
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

    case expr.first
    when :attribute
      # existence check to an attribute
      # (is defined as opposite of boolean())
      #  https://www.w3.org/TR/xpath-functions-31/#func-not
      cond = evaluate_expr(expr, root)
      condition = "ISNULL(#{cond})"
    when :child
      cond = evaluate_expr(expr, root)
      condition = "(NOT #{cond} OR ISNULL(#{cond}))"
    else
      @condition_values_needed = 2
      parse_predicate(root, expr)
      cond = @conditions.pop
      condition = "(NOT #{cond} OR ISNULL(#{cond}))"
    end
    @condition_values_needed = 1

    # logger.debug "-- condition : [#{condition}]"
    @conditions << condition
  end

  def xpath_func_starts_with(root, left_value, right_value)
    # logger.debug "-- xpath_func_starts_with(#{left_value.inspect}, #{right_value.inspect}) --"

    s1 = evaluate_expr(left_value, root)
    s2 = evaluate_expr(right_value, root, escape: true)

    condition = "#{s1} LIKE CONCAT(#{s2},'%')"
    # logger.debug "-- condition: [#{condition}]"

    @conditions << condition
  end

  def xpath_func_ends_with(root, left_value, right_value)
    # logger.debug "-- xpath_func_ends_with(#{left_value.inspect}, #{right_value.inspect}) --"

    s1 = evaluate_expr(left_value, root)
    s2 = evaluate_expr(right_value, root, escape: true)

    condition = "#{s1} LIKE CONCAT('%',#{s2})"
    # logger.debug "-- condition: [#{condition}]"

    @conditions << condition
  end
end
# rubocop:enable Metrics/MethodLength
