# frozen_string_literal: true

class TitlesService
  def initializer(params)
    @params = params
  end

  def fetch_all_titles
    if @params[:title_type].present? && Title.categories.include?(params[:title_type])
      titles, all_titles_count = fetch_all_titles_by_title_type
      meta_tag_group = MetaTag.find_by(page_type:"Title by type titles#index") # Some meta tags are kept in database
    else
      titles = Title.paginate(:page => params[:page], :per_page => 52).includes(:attachment, :influence_relationships, :influenced_relationships)
      all_titles_count = Title.all.count
      meta_tag_group = MetaTag.find_by(page_type:"Home Page titles#index")
    end

    [titles, all_titles_count, meta_tag_group]
  end

  private

  def fetch_all_titles_by_title_type
    if @params[:sort] == "A-Z"
      titles = Title.select("titles.*, CASE WHEN regexp_replace(lower(trim(name)), '[^A-Za-z]+', '', 'g')::text = '' THEN 'zzz' ELSE regexp_replace(lower(trim(name)), '[^A-Za-z]+', '', 'g') END as tname").where(title_type: @params[:title_type]).order("tname").paginate(:page => params[:page], :per_page => 52)
    elsif @params[:sort] == "Z-A"
      titles = Title.select("titles.*, CASE WHEN regexp_replace(lower(trim(name)), '[^A-Za-z]+', '', 'g')::text = '' THEN 'zzz' ELSE regexp_replace(lower(trim(name)), '[^A-Za-z]+', '', 'g') END as tname").where(title_type: @params[:title_type]).order("tname desc").paginate(:page => params[:page], :per_page => 52)
    elsif @params[:sort] == "highest_number"
      titles = sort_by_title_type(@params[:title, type], "relationships_count DESC")
    elsif @params[:sort] == "lowest_number"
      titles = sort_by_title_type(@params[:title, type], "relationships_count ASC")
    elsif @params[:sort] == 'lowest_iscore' || params[:sort] == 'highest_iscore'
      sort_dir = @params[:sort] == 'lowest_iscore' ? :asc : :desc
      titles = sort_by_title_type(@params[:title, type], "influence_score #{sort_dir}")
      puts("SQL: #{@titles.to_sql}")
    elsif @params[:title_type] == "Movie"
      sort_dir = :desc
      titles = sort_by_title_type(@params[:title, type], "influence_score #{sort_dir}")
    else
      titles = sort_by_title_type(@params[:title, type], "relationships_count DESC")
    end

    all_titles_count = titles.count

    [titles, all_titles_count]
  end

  def sort_by_title_type(title_type, sort_order)
    Title.where(title_type: title_type).order(sort_order).paginate(:page => params[:page], :per_page => 52)
  end
end
