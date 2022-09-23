require 'will_paginate/array'

class TitlesController < ApplicationController
  before_action :authenticate_user!, except: [:index, :show, :search_titles_and_talents_with_ajax, :title_show]
  load_and_authorize_resource only: [:create, :edit, :new]

  helper_method :static_images

  def index
    service = Titles::IndexService.call(params[:title_type], params)

    if service.success?
      @titles, @all_titles_count, meta_tag_group = service.result
      if meta_tag_group.present?
        @description = meta_tag_group.description
        @keywords = meta_tag_group.keywords
      else
        @description = ""
        @keywords = ""
      end
    else
      # ...
    end

    respond_to do |format|
      format.html
      format.js
    end
  end

  def show

    @title = Title.friendly.find(params[:id])
    @fav_list = FavoriteList.find_by(name: @title.name)
    @fav_lists = @title.available_favorite_list(current_user.id) if current_user.present?
    @title_ids = @fav_list.favorites.pluck(:title_id) if @fav_list.present?
    favorites = @fav_lists.joins(:favorites) if @fav_lists.present?
    @fav_title_ids = favorites.where("favorites.title_id=?", @title.id).pluck("favorite_lists.id") if @fav_lists.present?
    @sort = "" # sort by title type
    @sort_by_genre = ""
    @sort_by_tag = ""
    @min_year = "" # will be used for setting year in range slider
    @max_year = "" # will be used for setting year in range slider
    @selected_min_year = params[:from]
    @selected_max_year = params[:to]
    @year_filter_present = params[:from].present? && params[:to].present?
    @no_year_filter = Title.without_year_categories.include?(params[:sort])
    @title_container = params[:title_container].present? ? params[:title_container] : ""
    @paginate_influenceds_1 = false #not assigned instance variables are equal to nil
    @paginate_influences_1 = false
    @max_paginate = 32
    @max_see_more = 20
    max_num_titles = 60

    meta_tag_group = MetaTag.find_by(page_type:"Title titles#show")
    if meta_tag_group.present?
      @description = meta_tag_group.description.to_s + ", Total Connections: " + @title.relationships_count.to_s
      @keywords = meta_tag_group.keywords
    else
      @description = ""
      @keywords = ""
    end
    if !(params[:title_category].present? || params[:sort].present? || params[:sort_by_genre].present? || params[:sort_by_tag].present? || @year_filter_present) # Initial rendering withour any parameters and filteration

      genres_id = @title.genre_relationships.pluck(:genre_id)
      genres = Genre.where(id: genres_id)
      result = Hash.new { |hash, key| hash[key] = [] }
      genres.each do |genre|
        gen_rel_count = GenreRelationship.where(genre_id: genre.id).count
        result[gen_rel_count] << genre
      end
      sorted_genres = result.sort.reverse #sort current title genres by pupularity number in GenreRelationship
      @genres = sorted_genres.to_h
      @influence_ids = @title.influenced_relationships.select(:influence_id).map(&:influence_id)
      @influenced_ids = @title.influence_relationships.select(:influenced_id).map(&:influenced_id)
      @influence_titles = Title.where(id: @influence_ids) #titles which were influenced by current title
      # @influence_genre_array = @influence_titles.map(&:genres).flatten.map(&:name)#used in view
      @influence_genre_array = @influence_titles.joins(:genres).pluck("genres.name")
      @influenced_titles = Title.where(id: @influenced_ids) #titles which have influence on current title
      # @influenced_genre_array = @influenced_titles.map(&:genres).flatten.map(&:name)#used in view
      @influenced_genre_array = @influenced_titles.joins(:genres).pluck("genres.name")
      @related_titles = @influenced_titles + @influence_titles
      title_influenced = @title.influenced_relationships.map(&:tags).map{|tag_array| tag_array.map(&:name).uniq}.flatten()
      title_influence = @title.influence_relationships.map(&:tags).map{|tag_array| tag_array.map(&:name).uniq}.flatten()
      @tag_name_array = title_influenced + title_influence

      related_title_years = @related_titles.map{ |i| [i.year, i.end_year]}.flatten.compact - [0] - [4000] # get years and remove default and semi default values
      related_title_years.sort!
      @min_year = related_title_years.first
      @max_year = related_title_years.last
      @related_titles = @related_titles.group_by(&:title_type).sort_by{|k,v| v.length}.reverse

    else

      if params[:sort].present?

        influence_ids = @title.influenced_relationships.select(:influence_id).map(&:influence_id)
        influenced_ids = @title.influence_relationships.select(:influenced_id).map(&:influenced_id)

        if params[:sort] == "All"
          @influence_titles = Title.where(id: influence_ids)
          @influenced_titles = Title.where(id: influenced_ids)
        elsif Title.categories.include?(params[:sort]) #for extra security
          @influence_titles = Title.where(id: influence_ids, title_type: params[:sort])
          @influenced_titles = Title.where(id: influenced_ids, title_type: params[:sort])
        else
          @influenced_titles = @influence_titles = Title.where(title_type:"")
        end

        @sort = (params[:sort] == "All") ? "" : params[:sort]

        if !params[:title_category].present? && !params[:sort_by_genre].present? && !params[:sort_by_tag].present? && !@year_filter_present
          @influence_genre_array = @influence_titles.map(&:genres).flatten.map(&:name)#used in view
          @influenced_genre_array = @influenced_titles.map(&:genres).flatten.map(&:name)#used in view
          influence_ids = @influence_titles.map(&:id)
          influenced_ids = @influenced_titles.map(&:id)
          title_influenced = @title.influenced_relationships.where(influence_id: influenced_ids).map(&:tags).map{|tag_array| tag_array.map(&:name).uniq}.flatten()
          title_influence = @title.influence_relationships.where(influence_id: influence_ids).map(&:tags).map{|tag_array| tag_array.map(&:name).uniq}.flatten()
          @tag_name_array = title_influenced + title_influence
        end

      else
        influence_ids = @title.influenced_relationships.select(:influence_id).map(&:influence_id)
        influenced_ids = @title.influence_relationships.select(:influenced_id).map(&:influenced_id)
        @influence_titles = Title.where(id: influence_ids)
        @influenced_titles = Title.where(id: influenced_ids)
      end

      if @year_filter_present

        @influence_titles = @influence_titles.where("(year >= #{@selected_min_year} and year <= #{@selected_max_year})")
        @influenced_titles = @influenced_titles.where("(year >= #{@selected_min_year} and year <= #{@selected_max_year})")

      end

      if params[:sort_by_genre].present?

        influence_titles_temp = []
        influenced_titles_temp = []
        params[:sort_by_genre] =  params[:sort_by_genre].to_s.gsub /&amp;/, "&"
        selected_genre_id = Genre.find_by(name: params[:sort_by_genre]).id

        @influence_titles.each do |title|
          influence_genre_array = title.genre_relationships.map(&:genre_id)
          if influence_genre_array.include?(selected_genre_id)
            influence_titles_temp << title
          end
        end

        @influenced_titles.each do |title|
          influenced_genre_array = title.genre_relationships.map(&:genre_id)
          if influenced_genre_array.include?(selected_genre_id)
            influenced_titles_temp << title
          end
        end

        @influence_titles = influence_titles_temp
        @influenced_titles = influenced_titles_temp
        @sort_by_genre = params[:sort_by_genre]

        if !params[:title_category].present? && !params[:sort_by_tag].present? && !@year_filter_present
          influence_ids = @influence_titles.map(&:id)
          influenced_ids = @influenced_titles.map(&:id)
          title_influenced = @title.influenced_relationships.where(influence_id: influenced_ids).joins(:tags).pluck("tags.name").uniq.flatten()
          title_influence = @title.influence_relationships.where(influence_id: influence_ids).joins(:tags).pluck("tags.name").uniq.flatten()
          @tag_name_array = title_influenced + title_influence
        end

      end

      if params[:sort_by_tag].present?

        influence_titles_temp = []
        influenced_titles_temp = []
        selected_tag_id = Tag.find_by(name: params[:sort_by_tag]).id

        @influence_titles.each do |title|
          influence_tag_array = title.influence_relationships.find_by(influenced_id: @title.id).relationship_tag_relationships.map(&:tag_id).uniq
          if influence_tag_array.include?(selected_tag_id)
            influence_titles_temp << title
          end
        end

        @influenced_titles.each do |title|
          influenced_tag_array = title.influenced_relationships.find_by(influence_id: @title.id).relationship_tag_relationships.map(&:tag_id).uniq
          if influenced_tag_array.include?(selected_tag_id)
            influenced_titles_temp << title
          end
        end

        @influence_titles = influence_titles_temp
        @influenced_titles = influenced_titles_temp
        @sort_by_tag = params[:sort_by_tag]

      end

    end

    @influence_titles_count = @influence_titles.count #used in _influence.html.erb
    @influenced_titles_count = @influenced_titles.count #used in influenced.html.erb
    @sum_all = @influenced_titles_count + @influence_titles_count #used in show

    if params[:title_category].present?

      if params[:title_category] == "influenceds"
        @influenced_titles = Kaminari.paginate_array(@influenced_titles).page(params[:page]).per(@max_see_more)
        @paginate_influenceds = false
      elsif params[:title_category] == "influences"
        @influence_titles = Kaminari.paginate_array(@influence_titles).page(params[:page]).per(@max_see_more)
        @paginate_influences = false
      elsif params[:title_category] == "pg_influenceds"
        @influenced_titles = Kaminari.paginate_array(@influenced_titles).page(params[:page]).per(@max_paginate)
        @paginate_influenceds = true
      elsif params[:title_category] == "pg_influences"
        @influence_titles = Kaminari.paginate_array(@influence_titles).page(params[:page]).per(@max_paginate)
        @paginate_influences = true
      end

    else

      if @influenced_titles_count >= max_num_titles
        @influenced_titles = Kaminari.paginate_array(@influenced_titles).page(1).per(@max_paginate)
        @paginate_influenceds_1 = true
      else
        @influenced_titles = Kaminari.paginate_array(@influenced_titles).page(1).per(@max_see_more)
      end

      if @influence_titles_count >= max_num_titles
        @influence_titles = Kaminari.paginate_array(@influence_titles).page(1).per(@max_paginate)
        @paginate_influences_1 = true
      else
        @influence_titles = Kaminari.paginate_array(@influence_titles).page(1).per(@max_see_more)
      end

    end

    respond_to do |format|
      format.html
      format.js
    end

  end

  def title_show

    @title = Title.includes(:influence_relationships, :influenced_relationships, :genres).friendly.find(params[:id])
    @genres = @title.genres
    @genre_movie_ranks = GenreMovieRank.where(genre_id: @genres.ids, title_id: @title.id).pluck(:genre_id, :rank).to_h
    @influence_relationships = @title.influence_relationships
    @influenced_relationships = @title.influenced_relationships
    @influenced_title_ids = @influence_relationships.pluck(:influenced_id)
    @influence_title_ids = @influenced_relationships.pluck(:influence_id)
    @influence_titles = Title.eager_load(:genres).where(id: @influence_title_ids).order(:year)
    @influenced_titles = Title.eager_load(:genres).where(id: @influenced_title_ids).order(:year)
    genre_ids = (@influence_titles.pluck("genres.id") +   @influenced_titles.pluck("genres.id")).uniq
    @influence_genres = Genre.where(id: genre_ids.flatten)
    @total_titles = @influence_titles.merge(@influenced_titles)
    titles = @total_titles.where.not(year: nil).order(year: :asc)
    @title_groups = @total_titles.group_by(&:title_type)
    @min_year = @total_titles.first.year.to_i
    @max_year = @total_titles.last.year.to_i
    @tags = @influence_relationships
              .or(@influenced_relationships).joins(:tags)
              .select("tags.name").group("tags.name").count
    @tags = @tags.sort_by{ |k, v| v }.reverse.to_h
    p @tags
  end

  def csv_export
    @title = Title.friendly.find(params[:id])
    send_data TitleCsvGenerator.summary([@title.id]), filename: "#{@title.name}.csv"
  end

  def pdf_export
    redirect_to :back
  end

  def tv_season_show
    @tv_season = Title.friendly.find(params[:id])
    association = TvSerieSeasonAssociation.where(tv_season_id: @tv_season.id).first
    @tv_serie = Title.friendly.find(association.tv_serie_id)
    @tv_episodes = @tv_season.tv_episodes
    @tv_episodes = Kaminari.paginate_array(@tv_episodes).page(params[:page]).per(52)
  end

  def new
    @title = Title.new(static_poster: false)
  end

  def batch_new
    @title = Title.new #for error messages partial
    @title_count = params[:title_count].present? ? params[:title_count] : 5
    @titles = Array.new(@title_count.to_i, Title.new)
  end

  def static_images
    StaticImage.pluck(:name, :id)
  end

  def create
    title_params_mod = title_params # wasn't able to modify original prams
    if (title_params[:end_year].present? && title_params[:end_year] == "present")
      title_params_mod[:end_year] = 4000 # still lasting TV Series or TV Seasons
    end

    @title = Title.new(title_params_mod)
    if title_params_mod[:title_type] == "TV Season"
      if tv_title_params[:tv_serie_id].present?
        tv_serie = Title.friendly.find(tv_title_params[:tv_serie_id])
        @title = tv_serie.tv_seasons.new(title_params_mod)
        if tv_serie.tv_seasons.where(tv_season_num: title_params_mod[:tv_season_num]).present? #validation for uniqueness of tv_season_num, it can't be done in model
          @title.errors.messages[:tv_season_num] = ["is already taken"]
          render :new
          return
        end
        @title.user_id = current_user.id
        @title.name = tv_serie.name # TV Season name can be duplicated, it will be used for slug generation
        @title.attachment = params[:title][:attachment] unless @title.static_poster
        if @title.save
          tv_serie.tv_seasons << @title
          redirect_to tv_season_titles_path(@title)
        else
          render :new
        end
      else
        @title.errors.messages[:tv_serie] = ["is not selected"]
        render :new
      end
    elsif title_params_mod[:title_type] == "TV Episode"
      if tv_title_params[:tv_serie_id].present?
        tv_serie = Title.friendly.find(tv_title_params[:tv_serie_id])
      else
        @title.errors.messages[:tv_serie] = ["is not selected"]
        render :new
        return
      end

      if tv_title_params[:tv_season_id].present?
        tv_season = tv_serie.tv_seasons.friendly.find(tv_title_params[:tv_season_id])
      else
        @title.errors.messages[:tv_season] = ["is not selected"]
        render :new
        return
      end

      @title = tv_season.tv_episodes.new(title_params_mod)
      if tv_season.tv_episodes.where(tv_episode_num: title_params_mod[:tv_episode_num]).present? #validation for uniqueness of tv_episode_num, it can't be done in model
        @title.errors.messages[:tv_episode_num] = ["is already taken"]
        render :new
        return
      end
      @title.user_id = current_user.id
      @title.attachment = params[:title][:attachment] unless @title.static_poster
      if @title.save
        tv_season.tv_episodes << @title
        redirect_to @title
      else
        render :new
      end
    else
      @title = Title.new(title_params_mod)
      @title.user_id = current_user.id
      @title.attachment = params[:title][:attachment] unless @title.static_poster
      if @title.save
        redirect_to @title
      else
        render :new
      end
    end
  end

  def batch_create
    @title = Title.new #for error messages partial
    @titles = []
    batch_title_params.each do |title_params| #this block is for keeping form data in case of failed validation
      @titles << Title.new(
        name: title_params[:name],
        description: title_params[:description],
        title_type: title_params[:title_type],
        year: title_params[:year],
        end_year: title_params[:end_year],
        static_poster: title_params[:static_poster],
        static_image_id: title_params[:static_image_id]
      )
    end

    if tv_title_params[:title_type] == "TV Episode" # custom tv association validation

      if tv_title_params[:tv_serie_id].present?
        tv_serie = Title.friendly.find(tv_title_params[:tv_serie_id])
      else
        @title.errors.messages[:tv_serie] = ["is not selected"]
        render :batch_new
        return
      end

      if tv_title_params[:tv_season_id].present?
        tv_season = tv_serie.tv_seasons.friendly.find(tv_title_params[:tv_season_id])
      else
        @title.errors.messages[:tv_season] = ["is not selected"]
        render :batch_new
        return
      end

      begin
        ActiveRecord::Base.transaction do # for ActiveRecord::RecordInvalid exception
          batch_title_params.each do |title_params|
            @title = tv_season.tv_episodes.new(
              name: title_params[:name],
              description: title_params[:description],
              year: title_params[:year], end_year: title_params[:end_year],
              tv_episode_num: title_params[:tv_episode_num],
              title_type: title_params[:title_type],
              static_poster: title_params[:static_poster],
              static_image_id: title_params[:static_image_id],
              user_id: current_user.id
            )
            if tv_season.tv_episodes.where(tv_episode_num: title_params[:tv_episode_num]).present? #validation for uniqueness of tv_episode_num, it can't be done in model
              @title.errors.messages[:tv_episode_num] = ["is already taken"]
              render :new
              return
            end
            @title.attachment = title_params[:attachment]
            if @title.validate! # this raises ActiveRecord::RecordInvalid exception and all the successfully commited transactions get rolled back
              tv_season.tv_episodes << @title
            end
          end
        end
      rescue
        render :batch_new
        return
      end

    elsif title_params[:title_type] == "TV Season"

      if tv_title_params[:tv_serie_id].present?
        tv_serie = Title.friendly.find(tv_title_params[:tv_serie_id])
      else
        @title.errors.messages[:tv_serie] = ["is not selected"]
        render :batch_new
        return
      end

      begin
        ActiveRecord::Base.transaction do
          batch_title_params.each do |title_params|
            @title = tv_serie.tv_seasons.new(
              name: title_params[:name],
              description: title_params[:description],
              year: title_params[:year],
              end_year: title_params[:end_year],
              tv_season_num: title_params[:tv_season_num],
              title_type: title_params[:title_type],
              static_poster: title_params[:static_poster],
              static_image_id: title_params[:static_image_id],
              user_id: current_user.id
            )
            if tv_serie.tv_seasons.where(tv_season_num: title_params[:tv_season_num]).present? #validation for uniqueness of tv_season_num, it can't be done in model
              @title.errors.messages[:tv_season_num] = ["is already taken"]
              render :batch_new
              return
            end
            @title.name = tv_serie.name # TV Season name can be duplicated, it will be used for slug generation
            @title.attachment = title_params[:attachment]
            if @title.validate!
              tv_serie.tv_seasons << @title
            end
          end
        end
      rescue ActiveRecord::RecordInvalid
        render :batch_new
        return
      end

    else # tv title TV Series doesn't need to have associated parents and can be saved as other non tv titles

      begin
        ActiveRecord::Base.transaction do
          batch_title_params.each do |title_params|
            @title = Title.new(
              name: title_params[:name],
              description: title_params[:description],
              year: title_params[:year],
              end_year: title_params[:end_year],
              title_type: title_params[:title_type],
              static_poster: title_params[:static_poster],
              static_image_id: title_params[:static_image_id],
              user_id: current_user.id
            )
            @title.attachment = title_params[:attachment]
            if @title.validate!
              @title.save
            end
          end
        end
      rescue ActiveRecord::RecordInvalid
        render :batch_new
        return
      end
    end
    redirect_to titles_url
    return
  end

  def edit
    @title = Title.friendly.find(params[:id])
  end

  def update
    posted_title_type = ""
    title_params_mod = title_params # wasn't able to modify original prams
    if (title_params[:end_year].present? && title_params[:end_year] == "present")
      title_params_mod[:end_year] = 4000 # still lasting TV Series or TV Seasons
    end

    @title = Title.friendly.find(params[:id])
    @title.user_id = @title.user_id.present? ? @title.user_id : current_user.id #it will add gradually user_id to all titles, many titles were created before validations and they have user_id: nil
    title_current_type = @title.title_type
    type_changed = false
    associations_dropped = false

    if (tv_title_params[:tv_serie_id].to_i == @title.id) || (tv_title_params[:tv_season_id].to_i == @title.id) # avoid self reference of titles
      @title.errors.messages[:self_reference] = ["is not allowed"]
      render :edit
      return
    end

    if title_params_mod[:title_type] == "TV Episode" # custom tv association validation and removing old association rows

      if tv_title_params[:tv_serie_id].present?
        tv_serie = Title.friendly.find(tv_title_params[:tv_serie_id])
      else
        @title.errors.messages[:tv_serie] = ["is not selected"]
        render :edit
        return
      end

      if tv_title_params[:tv_season_id].present?
        tv_season = tv_serie.tv_seasons.friendly.find(tv_title_params[:tv_season_id])
        if tv_season.tv_episodes.where(tv_episode_num: title_params_mod[:tv_episode_num]).present?  #validation for uniqueness of tv_episode_num, it can't be done in model
          @title.errors.messages[:tv_episode_num] = ["is already taken"]
          render :new
          return
        end
      else
        @title.errors.messages[:tv_season] = ["is not selected"]
        render :edit
        return
      end

      if !TvSeasonEpisodeAssociation.where(tv_season_id: tv_season.id, tv_episode_id: @title.id).present? # remove old association rows if TV Episode was changed
        TvSeasonEpisodeAssociation.where(tv_episode_id: @title.id).destroy_all
        associations_dropped = true
      end

    elsif title_params_mod[:title_type] == "TV Season"

      if tv_title_params[:tv_serie_id].present?
        tv_serie = Title.friendly.find(tv_title_params[:tv_serie_id])
        if tv_serie.tv_seasons.where(tv_season_num: title_params_mod[:tv_season_num]).present?  #validation for uniqueness of tv_season_num, it can't be done in model
          @title.errors.messages[:tv_episode_num] = ["is already taken"]
          render :new
          return
        end
        posted_title_type = "TV Season"
      else
        @title.errors.messages[:tv_serie] = ["is not selected"]
        render :edit
        return
      end

      if !TvSerieSeasonAssociation.where(tv_serie_id: tv_serie.id, tv_season_id: @title.id).present? # remove old association rows TV Series was changed
        TvSerieSeasonAssociation.where(tv_season_id: @title.id).destroy_all
        associations_dropped = true
      end

    end

    if ["TV Series", "TV Season", "TV Episode"].include?(title_current_type) && title_params_mod[:title_type] != title_current_type # destroy all the existing associations if tytle_type was changed

      if title_current_type == "TV Season"
        TvSerieSeasonAssociation.where(tv_season_id: @title.id).destroy_all
        TvSeasonEpisodeAssociation.where(tv_season_id: @title.id).destroy_all
      elsif title_current_type == "TV Episode"
        TvSeasonEpisodeAssociation.where(tv_episode_id: @title.id).destroy_all
      elsif title_current_type == "TV Series"
        TvSerieSeasonAssociation.where(tv_serie_id: @title.id).destroy_all
      end
      type_changed = true
    end

    @title.assign_attributes(title_params_mod)
    if title_attachment_params.present?
      @title.name = tv_serie.name if posted_title_type == "TV Season" # TV Season name can be duplicated, it will be used for slug generation
      @title.attachment = title_attachment_params[:attachment]
      if @title.validate
        @title.save
        if ( type_changed == true || associations_dropped == true )
          if title_params_mod[:title_type] == "TV Episode"
            tv_season.reload
            tv_season.tv_season_episode_associations.create(tv_episode_id: @title.id)
          elsif title_params_mod[:title_type] == "TV Season"
            tv_serie.reload
            tv_serie.tv_serie_season_associations.create(tv_season_id: @title.id)
          end
        end

        if @title.title_type == "TV Season"
          redirect_to tv_season_titles_path(@title)
        else
          redirect_to @title
        end

      else
        render :edit
      end
    else
      if @title.validate
        @title.save
        if ( type_changed == true || associations_dropped == true )
          if title_params_mod[:title_type] == "TV Episode"
            tv_season.tv_season_episode_associations.create(tv_episode_id: @title.id)
          elsif title_params_mod[:title_type] == "TV Season"
            tv_serie.tv_serie_season_associations.create(tv_season_id: @title.id)
          end
        end

        if @title.title_type == "TV Season"
          redirect_to tv_season_titles_path(@title)
        else
          redirect_to @title
        end

      else
        render :edit
      end
    end
  end

  def destroy
    Title.friendly.find(params[:id]).destroy
    redirect_to titles_url
  end

  def titles_with_ajax
    @titles = Title.includes(:influence_relationships, :influenced_relationships).search("#{params[:term]}")
    @result = []
    excluded_types = ["TV Season"] # TV Season is not allowed to participate in relationship

    @titles.each do |title|
      @connections = title.influence_relationships.count + title.influenced_relationships.count
      if !excluded_types.include?(title.title_type)
        @res = {
          id: title.id,
          attachment: title.static_poster ? title.static_image_url : url_for(title.attachment.variant(resize_to_limit: [100, 100])),
          name: title.name,
          year: title.year,
          end_year: title.end_year,
          title_type: title.title_type,
          connections: @connections,
          slug: title.slug
        }
        @result.push(@res)
      end
    end
    respond_to do |format|
      format.html
      format.json { render :json => @result }
    end
  end

  def tv_series_with_ajax
    @tv_series = Title.includes(:influence_relationships, :influenced_relationships).search("#{params[:term]}").where(title_type:"TV Series")
    @result = []

    @tv_series.each do |title|
      @res = {id: title.id, attachment: url_for(title.attachment(:thumb)), name: title.name, year: title.year, end_year: title.end_year, title_type: title.title_type, connections: @connections}
      @result.push(@res)
    end

    respond_to do |format|
      format.html
      format.json { render :json => @result }
    end
  end

  def tv_seasons_with_ajax
    @tv_serie = Title.includes(:influence_relationships, :influenced_relationships).friendly.find(params[:tv_serie_id])
    @result = []

    @tv_serie.tv_seasons.each do |title|
      @res = {id: title.id, attachment: url_for(title.attachment(:thumb)), name: title.name, season_num: title.tv_season_num, year: title.year, end_year: title.end_year, title_type: title.title_type }
      @result.push(@res)
    end

    respond_to do |format|
      format.html
      format.json { render :json => @result }
    end
  end

  def create_movie_csv
    Movie.import(params[:movie], current_user)
    MovieSource.import_movie_source(params[:movie_source], current_user)
    redirect_to movies_path, notice: "Data imported successfully"
  end

  def default_static_image
    default_image = DefaultStaticImage.find_by(name: params[:name])
    if default_image.present?
      @result = default_image
    end
    respond_to do |format|
      format.json { render json: @result}
    end
  end

  def add_to_search
    @title = Title.friendly.find(params[:id])
    if @title.update(search: params[:search])
      if @title.search
        @message = 'Title added to search successfully.'
      else
        @message = 'Title remove from search successfully.'
      end
    end
  end

  private

  def title_params
    if params[:title].present?
      return params.require(:title).permit(:name, :alternative_name, :year, :title_type, :description, :imdb_id, :end_year, :tv_season_num, :tv_episode_num, :static_poster, :static_image_id)
    else
      return {name: "", alternative_name: "", year: "", title_type: "", description: "", end_year: "", tv_season_num: "", tv_episode_num: "", static_poster: false}
    end
  end

  def tv_title_params
    if params[:title].present?
      return params.require(:title).permit(:title_type, :tv_serie_id, :tv_season_id)
    else
      return {title_type:"", tv_serie_id: "", tv_season_id: ""}
    end
  end

  def title_attachment_params
    params.require(:title).permit(:attachment)# attachment is not being properly loaded without permit
  end

  def batch_title_params
    if params[:title].present?
      title_type = params[:title][:title_type]
      if params[:titles].present? && params[:titles].count > 0
        titles = []
        params[:titles].each do |key, value|
          data = {
            name: value[:name],
            description: value[:description],
            title_type: title_type,
            year: value[:year],
            end_year: value[:end_year] == "present" ? 4000 : value[:end_year],
            tv_season_num: value[:tv_season_num],
            tv_episode_num: value[:tv_episode_num],
            static_poster: value[:static_poster],
            static_image_id: value[:static_image_id],
            attachment: value.permit(:attachment)
          }

          unless Title.tv_categories.include?(title_type)
            data[:year] = params[:title][:year]
          end

          if params[:title][:static_poster]
            data[:static_poster] = true
            data[:static_image_id] = params[:title][:static_image_id]
          end

          titles << data
        end
        return titles
      else
        return [ { name: "", description: "",  title_type: "", year: "", end_year: "", tv_season_num: "", tv_episode_num: "", attachment: "" } ]
      end
    else
      return [ { name: "", description: "", title_type: "", year: "", end_year: "", tv_season_num: "", tv_episode_num: "", attachment: ""} ]
    end
  end

end

