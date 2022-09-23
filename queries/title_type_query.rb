class TitleTypeQuery
  PAGINATION_DEFAULT_PERPAGE = 52
  PAGINATION_DEFAULT_PAGE = 1
 
  def initialize(title_type, paginate_opts: {page: PAGINATION_DEFAULT_PAGE, per_page: PAGINATION_DEFAULT_PERPAGE}, params)
    @title_type = title_type
    @paginate_opts = paginate_opts
    @titles = Title.where(title_type: title_type)
    @titles.extend(Scopes)
  end
 
  def all(sort_param)
    result = case sort_param
      when "A-Z"
        @titles.select_tname.order("tname")
      when "Z-A"
        @titles.select_tname.order("tname desc")
      when "highest_number"
        @titles.order("relationships_count DESC")
      when "lowest_number"
        @titles.order("relationships_count ASC")
      when "lowest_iscore"
        @titles.order("influence_score asc")
        puts("SQL: #{@titles.to_sql}")
      when "highest_iscore"
        @titles.order("influence_score desc")
        puts("SQL: #{@titles.to_sql}")
      else
        if @title_type == "Movie"
          params[:sort] = "highest_iscore"
          params[:page_type] = "movie"
          sort_dir = :desc
          @titles.order("influence_score #{sort_dir}")
        else
          params[:sort] = "highest_number"
          params[:page_type] = "others"
          @titles.order("relationships_count DESC")
        end
      end

    paginate_result(result)
  end
 
  private

  def paginate_result
    result.paginate(page: paginate_opts[:page], per_page: paginate_opts[:per_page])
  end

  module Scopes
    def select_tname
      select("
        titles.*, CASE WHEN regexp_replace(lower(trim(name)), '[^A-Za-z]+', '', 'g')::text = '' THEN 'zzz' ELSE regexp_replace(lower(trim(name)), '[^A-Za-z]+', '', 'g') END as tname
      ")
    end
  end
end