# frozen_string_literal: true

class TitlesService
  def self.fetch_all_titles_by_title_type(params)
    if params[:sort] == "A-Z"
      titles = Title.select("titles.*, CASE WHEN regexp_replace(lower(trim(name)), '[^A-Za-z]+', '', 'g')::text = '' THEN 'zzz' ELSE regexp_replace(lower(trim(name)), '[^A-Za-z]+', '', 'g') END as tname").where(title_type: params[:title_type]).order("tname").paginate(:page => params[:page], :per_page => 52)
    elsif params[:sort] == "Z-A"
      titles = Title.select("titles.*, CASE WHEN regexp_replace(lower(trim(name)), '[^A-Za-z]+', '', 'g')::text = '' THEN 'zzz' ELSE regexp_replace(lower(trim(name)), '[^A-Za-z]+', '', 'g') END as tname").where(title_type: params[:title_type]).order("tname desc").paginate(:page => params[:page], :per_page => 52)
    elsif params[:sort] == "highest_number"
      titles = sort_by_title_type(params[:title, type], "relationships_count DESC")
    elsif params[:sort] == "lowest_number"
      titles = sort_by_title_type(params[:title, type], "relationships_count ASC")
    elsif params[:sort] == 'lowest_iscore' || params[:sort] == 'highest_iscore'
      sort_dir = params[:sort] == 'lowest_iscore' ? :asc : :desc
      titles = sort_by_title_type(params[:title, type], "influence_score #{sort_dir}")
      puts("SQL: #{@titles.to_sql}")
    elsif params[:title_type] == "Movie"
      sort_dir = :desc
      titles = sort_by_title_type(params[:title, type], "influence_score #{sort_dir}")
    else
      titles = sort_by_title_type(params[:title, type], "relationships_count DESC")
    end

    titles
  end

  class << self
    private

    def sort_by_title_type(title_type, sort_order)
      Title.where(title_type: title_type).order(sort_order).paginate(:page => params[:page], :per_page => 52)
    end
  end
end
