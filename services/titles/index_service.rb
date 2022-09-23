# Using gem 'simple_command'

class Titles::IndexService
  # put SimpleCommand before the class' ancestors chain
  prepend SimpleCommand

  # optional, initialize the command with some arguments
  def initialize(title_type, params)
    @title_type = title_type
    @params = params
  end

  # mandatory: define a #call method. its return value will be available
  #            through #result
  def call
    if title_type && Title.categories.exists?(title_type)
      titles = TitleTypeQuery.new(title_type, paginate_opts: { page: params[:page], per_page: TitleTypeQuery::PAGINATION_DEFAULT_PERPAGE }, params: params)
      all_titles_count = Title.where(title_type: title_type).count
      meta_tag_group = MetaTag.find_by(page_type:"Title by type titles#index") # Some meta tags are kept in database
    else
      titles = Title.paginate(:page => params[:page], :per_page => 52).includes(:attachment, :influence_relationships, :influenced_relationships, params: params)
      all_titles_count = Title.all.count
      meta_tag_group = MetaTag.find_by(page_type:"Home Page titles#index")
    end

    [titles, all_titles_count, meta_tag_group]
  end

  private

  attr_accessor :title_type, :params
end
