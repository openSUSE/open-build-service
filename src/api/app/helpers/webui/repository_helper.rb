module Webui::RepositoryHelper
  def flag_column(flags, repository, architecture)
    flag = flags.effective_flag(repository, architecture)
    is_flag_set_by_user = flags.set_by_user?(repository, architecture)
    title = flag.status.capitalize
    icon_class = flag.status == 'disable' ? 'fas fa-ban text-danger' : 'fas fa-check text-success'
    data = { status: flag.status, flag: flag.flag, repository: repository,
             architecture: architecture }
    if is_flag_set_by_user
      title += ' (set by user)'
      icon_class += ' ml-0_6'
      data['default'] = flags.default_flag(repository, architecture).status
      data['user-set'] = 1
    else
      title += ' (calculated)'
    end

    content_tag(:div) do
      content_tag(:i, nil, class: 'fas fa-spinner fa-spin d-none') +
        link_to('javascript:;', title: title, class: 'flag-popup', data: data) do
          content_tag(:span, class: 'text-nowrap current_flag_state') do
            content_tag(:i, nil, class: icon_class) +
              if is_flag_set_by_user
                content_tag(:i, nil, class: 'fas fa-circle text-gray-500 text-40p-size')
              end
          end
        end
    end
  end
end
