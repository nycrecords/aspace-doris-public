Rails.application.config.after_initialize do
  class SubjectsController
    def index
      repo_id = params.fetch(:rid, nil)
      if !params.fetch(:q, nil)
        DEFAULT_SUBJ_SEARCH_PARAMS.each do |k, v|
          params[k] = v unless params.fetch(k,nil)
        end
      end
      search_opts = default_search_opts(DEFAULT_SUBJ_SEARCH_OPTS)
      search_opts['fq'] = ["used_within_published_repository:\"/repositories/#{repo_id}\""] if repo_id
      @base_search  =  repo_id ? "/repositories/#{repo_id}/subjects?" : '/subjects'
      default_facets = repo_id ? [] : ['used_within_published_repository']
      page = Integer(params.fetch(:page, "1"))
      begin
        set_up_and_run_search(['subject'], default_facets, search_opts, params)
      rescue NoResultsError
        flash[:error] = I18n.t('search_results.no_results')
        redirect_back(fallback_location: '/') and return
      rescue Exception => error
        flash[:error] = I18n.t('errors.unexpected_error')
        redirect_back(fallback_location: '/subjects' ) and return
      end

      @context = repo_context(repo_id, 'subject')
      if @results['total_hits'] > 1
        @search[:dates_within] = false
        @search[:text_within] = true
      end

      @page_title = I18n.t('subject._plural')
      @results_type = @page_title
      all_sorts = Search.get_sort_opts
      @sort_opts = []
      %w(title_sort_asc title_sort_desc).each do |type|
        @sort_opts.push(all_sorts[type])
      end

      if params[:q].size > 1 || params[:q][0] != '*'
        @sort_opts.unshift(all_sorts['relevance'])
      end
      @no_statement = true
      # subject_types is a hash with term_type as key and the subject record as value
      @subject_types = Hash.new
      @results.records.each do |result|
        puts(result)
        sub_type = result['json']['terms'][0]['term_type']
        if @subject_types.has_key?(sub_type)
          @subject_types[sub_type] << result
        else
          @subject_types[sub_type] = [result]
        end
      end
      render 'search/subjects_search_results'
    end
  end

  class AgentsController
    def index
      repo_id = params.fetch(:rid, nil)
      Rails.logger.debug("repo_id: #{repo_id}")
      if !params.fetch(:q, nil)
        DEFAULT_AG_SEARCH_PARAMS.each do |k, v|
          params[k] = v unless params.fetch(k,nil)
        end
      end
      search_opts = default_search_opts(DEFAULT_AG_SEARCH_OPTS)
      search_opts['fq'] = ["used_within_published_repository:\"/repositories/#{repo_id}\""] if repo_id
      @base_search  =  repo_id ? "/repositories/#{repo_id}/agents?" : '/agents?'
      default_facets = DEFAULT_AG_FACET_TYPES.dup
      default_facets.push('used_within_published_repository') unless repo_id
      page = Integer(params.fetch(:page, "1"))

      begin
        set_up_and_run_search( DEFAULT_AG_TYPES, default_facets, search_opts, params)
      rescue NoResultsError
        flash[:error] = I18n.t('search_results.no_results')
        redirect_back(fallback_location: '/') and return
      rescue Exception => error
        flash[:error] = I18n.t('errors.unexpected_error')
        redirect_back(fallback_location: '/agents') and return
      end

      @context = repo_context(repo_id, 'agent')
      if @results['total_hits'] > 1
        @search[:dates_within] = false
        @search[:text_within] = true
      end

      @page_title = I18n.t('agent._plural')
      @results_type = @page_title
      all_sorts = Search.get_sort_opts
      @sort_opts = []
      %w(title_sort_asc title_sort_desc).each do |type|
        @sort_opts.push(all_sorts[type])
      end
      if params[:q].size > 1 || params[:q][0] != '*'
        @sort_opts.unshift(all_sorts['relevance'])
      end
      @no_statement = true
      render 'search/agents_search_results'
    end
  end

  class ResourcesController
    # present a list of resources.  If no repository named, just get all of them.
    def index
      @repo_id = params.fetch(:rid, nil)
      if @repo_id
        @base_search = "/repositories/#{@repo_id}/resources?"
        repo = archivesspace.get_record("/repositories/#{@repo_id}")
        @repo_name = repo.display_string
      else
        @base_search = "/repositories/resources?"
      end
      search_opts = default_search_opts( DEFAULT_RES_INDEX_OPTS)
      search_opts['fq'] = ["repository:\"/repositories/#{@repo_id}\""] if @repo_id
      DEFAULT_RES_SEARCH_PARAMS.each do |k,v|
        params[k] = v unless params.fetch(k, nil)
      end
      page = Integer(params.fetch(:page, "1"))
      facet_types =  %w{primary_type subjects published_agents}
      begin
        set_up_and_run_search(['resource'], facet_types, search_opts, params)
      rescue NoResultsError
        flash[:error] = I18n.t('search_results.no_results')
        redirect_back(fallback_location: '/') and return
      rescue Exception => error
        flash[:error] = I18n.t('errors.unexpected_error')
        redirect_back(fallback_location: '/' ) and return
      end

      @context = repo_context(@repo_id, 'resource')
      if @results['total_hits'] > 1
        @search[:dates_within] = true if params.fetch(:filter_from_year,'').blank? && params.fetch(:filter_to_year,'').blank?
        @search[:text_within] = true
      end
      @page_title = I18n.t('resource._plural')
      @results_type = @page_title
      @sort_opts = []
      all_sorts = Search.get_sort_opts
      all_sorts.delete('relevance') unless params[:q].size > 1 || params[:q] != '*'
      all_sorts.keys.each do |type|
        @sort_opts.push(all_sorts[type])
      end

      if params[:q].size > 1 || params[:q][0] != '*'
        @sort_opts.unshift(all_sorts['relevance'])
      end
      @result_props = {
          :no_res => true
      }
      @no_statement = true
      #    if @results['results'].length == 1
      #      @result =  @results['results'][0]
      #      render 'resources/show'
      #    else
      render 'search/resources_search_results'
      #    end
    end
  end

  module Searchable
    extend ActiveSupport::Concern

    def set_up_advanced_search(default_types = [],default_facets=[],default_search_opts={}, params={})
      params = sanitize_params(params)
      @search = Search.new(params)
      unless @search[:limit].blank?
        default_types = @search[:limit].split(",")
      end
      set_search_statement
      raise I18n.t('navbar.error_no_term') unless @search.has_query?
      have_query = false
      advanced_query_builder = AdvancedQueryBuilder.new
      @search[:q].each_with_index { |query, i|
        query.gsub!(/\[\]/x) { |c| "\\" + c }
        query = '*' if query.blank?
        have_query = true
        op = @search[:op][i]
        field = @search[:field][i].blank? ? 'keyword' :  @search[:field][i]
        from = @search[:from_year][i] || ''
        to = @search[:to_year][i] || ''
        @base_search += '&' if @base_search.last != '?'
        @base_search += "q[]=#{CGI.escape(query)}&op[]=#{CGI.escape(op)}&field[]=#{CGI.escape(field)}&from_year[]=#{CGI.escape(from)}&to_year[]=#{CGI.escape(to)}"
        builder = AdvancedQueryBuilder.new
        # add field part of the row
        builder.and(field, query, 'text', false, op == 'NOT')
        # add year range part of the row
        unless from.blank? && to.blank?
          builder.and('years', AdvancedQueryBuilder::RangeValue.new(from, to), 'range', false, op == 'NOT')
        end
        # add to the builder based on the op
        if op == 'OR'
          advanced_query_builder.or(builder)
        else
          advanced_query_builder.and(builder)
        end
      }
      raise I18n.t('navbar.error_no_term') unless have_query  # just in case we missed something

      # any  search within results?
      @search[:filter_q].each do |v|
        value = v == '' ? '*' : v
        advanced_query_builder.and('keyword', value, 'text', false, false)
      end
      # we have to add filtered dates, if they exist
      unless @search[:dates_searched]
        years = get_filter_years(params)
        unless years['from_year'].blank? && years['to_year'].blank?
          builder = AdvancedQueryBuilder.new
          builder.and('years', AdvancedQueryBuilder::RangeValue.new(years['from_year'], years['to_year']), 'range', false, false)
          advanced_query_builder.and(builder)
          @base_search = "#{@base_search}&filter_from_year=#{years['from_year']}&filter_to_year=#{years['to_year']}"
        end
      end
      @criteria = default_search_opts
      @criteria['sort'] = @search[:sort] if @search[:sort]  # sort can be passed as default or via params
      # we have to pass the sort along in the URL
      @sort =  @criteria['sort']
      Rails.logger.debug("SORT: #{@sort}")
      # if there's an fq passed along...
      unless @criteria['fq'].blank?
        @criteria['fq'].each do |fq |
          f,v = fq.split(":")
          advanced_query_builder.and(f, v, "text", false, false)
        end
      end

      unless @criteria['repo_id'].blank?
        repo_uri = "/repositories/" + @criteria['repo_id']

        # Add a filter to limit to this repository (or things that link to it)
        this_repo = AdvancedQueryBuilder.new
        this_repo
            .and('repository', repo_uri, 'uri')
            .or('used_within_published_repository', repo_uri, 'uri')

        advanced_query_builder.and(this_repo)
      end
      @base_search += "&limit=#{@search[:limit]}" unless @search[:limit].blank?

      @facet_filter = FacetFilter.new(default_facets, @search[:filter_fields],  @search[:filter_values])

      # building the query for the facetting
      type_query_builder = AdvancedQueryBuilder.new
      default_types.reduce(type_query_builder) {|b, type|
        b.or('types', type)
      }

      @criteria['aq'] = advanced_query_builder.build.to_json
      @criteria['filter'] = @facet_filter.get_filter_query.and(type_query_builder).build.to_json
      @criteria['facet[]'] = @facet_filter.get_facet_types
      @search[:limit].blank? ? @criteria['page_size'] = params.fetch(:page_size, AppConfig[:pui_global_search_results_page_size]) : @criteria['page_size'] = params.fetch(:page_size, AppConfig[:pui_search_results_page_size])
    end
  end
end