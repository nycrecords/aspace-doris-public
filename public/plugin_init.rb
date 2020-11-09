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
end