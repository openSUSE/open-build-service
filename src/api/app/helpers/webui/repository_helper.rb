module Webui::RepositoryHelper
  def icon_class(flag, is_flag_set_by_user)
    icon_class = flag.status == 'disable' ? 'fas fa-ban text-danger' : 'fas fa-check text-success'
    icon_class + (is_flag_set_by_user ? ' ms-0_6' : '')
  end

  def title(flag, is_flag_set_by_user)
    title = flag.status.capitalize
    if is_flag_set_by_user
      "#{title} (set by user)"
    else
      "#{title} (calculated)"
    end
  end

  def flag_column(flags, repository, architecture)
    flag = flags.effective_flag(repository, architecture)
    is_flag_set_by_user = flags.set_by_user?(repository, architecture)

    data = { status: flag.status, flag: flag.flag, repository: repository,
             architecture: architecture }
    if is_flag_set_by_user
      data['default'] = flags.default_flag(repository, architecture).status
      data['user-set'] = 1
    end

    tag.div do
      tag.i(nil, class: 'fas fa-spinner fa-spin d-none') +
        link_to('javascript:;', title: title(flag, is_flag_set_by_user), class: 'flag-popup', data: data) do
          tag.span(class: 'text-nowrap current_flag_state') do
            tag.i(nil, class: icon_class(flag, is_flag_set_by_user)) +
              (tag.i(nil, class: 'fas fa-circle text-gray-500 text-40p-size') if is_flag_set_by_user)
          end
        end
    end
  end
end
