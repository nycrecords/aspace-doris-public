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
       if device_type == "mobile"
         render 'search/subjects_search_results_mobile'
       else
         render 'search/subjects_search_results'
       end
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
          DEFAULT_OBJ_SEARCH_OPTS = {
              'resolve[]' => ['repository:id', 'resource:id@compact_resource', 'ancestors:id@compact_resource', 'top_container_uri_u_sstr:id'],
              'facet.mincount' => 1,
              'sort' =>  'title_sort asc'
          }
    include ViewHelper

    def index
      @repo_id = params.fetch(:rid, nil)
      #Fetching the list of repositories
      @criteria = {}
      @criteria['sort'] = "repo_sort asc"
      @criteria['page_size'] = 100
      @search_data =  archivesspace.search('primary_type:repository', 1, @criteria) || {}

      @digital_objects_list = Array.new
      @search_data['results'].each do |repo_list|
        hash = ASUtils.json_parse(repo_list['json']) || {}
        repo_uri = hash['uri']
        #Fetching the raw data for all digital objects
        @digital_objects_list.push(archivesspace.search_digital_objects("#{repo_uri}/digital_objects?",repo_uri,1,{},true))
      end
      #Fetching all the resources
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
      facet_types =  %w{primary_type subjects published_agents creators}
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
      #Fetching the linked instances and converting to 1-D array
      @digital_objects_list.each do |digital_instance|
        flattened_instance = digital_instance["results"].map{|x| x["linked_instances"]}
        @instance_uris =  flattened_instance.flatten.map{|x| x["ref"]}
        #Checking if record tree contains digital object linked record
        @has_digital_instances = Array.new
        @results.records.each do |result|
          ordered_records = archivesspace.get_record(result['json']['uri']  + '/ordered_records').json.fetch('uris')
          record_tree = ordered_records.map{|x| x["ref"]}
          @has_digital_instances.push( !((record_tree &  @instance_uris).empty?) )
        end
      end
      render 'search/resources_search_results'
    end

    def show
      uri = "/repositories/#{params[:rid]}/resources/#{params[:id]}"
      begin
        #Fetching the list of repositories
        @criteria = {}
        @criteria['sort'] = "repo_sort asc"
        @criteria['page_size'] = 100
        @search_data =  archivesspace.search('primary_type:repository', 1, @criteria) || {}

        @digital_objects_list = Array.new
        @search_data['results'].each do |repo_list|
          hash = ASUtils.json_parse(repo_list['json']) || {}
          repo_uri = hash['uri']
          #Fetching the raw data for all digital objects
          @digital_objects_list.push(archivesspace.search_digital_objects("#{repo_uri}/digital_objects?",params[:rid],1,{},true))
        end
        #Fetching the resource record
        @criteria = {}
        @criteria['resolve[]']  = ['repository:id', 'resource:id@compact_resource', 'top_container_uri_u_sstr:id', 'related_accession_uris:id', 'digital_object_uris:id']

        tree_root = archivesspace.get_raw_record(uri + '/tree/root') rescue nil
        @has_children = tree_root && tree_root['child_count'] > 0
        @has_containers = has_containers?(uri)

        @result =  archivesspace.get_record(uri, @criteria)
        @repo_info = @result.repository_information
        @page_title = "#{I18n.t('resource._singular')}: #{strip_mixed_content(@result.display_string)}"
        @context = [{:uri => @repo_info['top']['uri'], :crumb => @repo_info['top']['name']}, {:uri => nil, :crumb => process_mixed_content(@result.display_string)}]
        fill_request_info

        #Fetching the linked instances and converting to 1-D array
        @digital_objects_list.each do |digital_instance|
          flattened_instance = digital_instance["results"].map{|x| x["linked_instances"]}
          @instance_uris =  flattened_instance.flatten.map{|x| x["ref"]}
          #Checking if record tree contains digital object linked record
          @has_digital_instance = Array.new
          ordered_records = archivesspace.get_record(uri + '/ordered_records').json.fetch('uris')
          @record_tree = ordered_records.map{|x| x["ref"]}
          @has_digital_instance =  !((@record_tree &  @instance_uris).empty?)
        end

      rescue RecordNotFound
        record_not_found(uri, 'resource')
      end
    end

    def infinite
      @root_uri = "/repositories/#{params[:rid]}/resources/#{params[:id]}"
      begin
        #Fetching the list of repositories
        @criteria = {}
        @criteria['sort'] = "repo_sort asc"
        @criteria['page_size'] = 100
        @search_data =  archivesspace.search('primary_type:repository', 1, @criteria) || {}

        @digital_objects_list = Array.new
        @search_data['results'].each do |repo_list|
          hash = ASUtils.json_parse(repo_list['json']) || {}
          repo_uri = hash['uri']
          #Fetching the raw data for all digital objects
          @digital_objects_list.push(archivesspace.search_digital_objects("#{repo_uri}/digital_objects?",repo_uri,1,{},true))
        end
        #Fetching the infinite record
        @criteria = {}
        @criteria['resolve[]']  = ['repository:id', 'resource:id@compact_resource', 'top_container_uri_u_sstr:id', 'related_accession_uris:id']
        @result =  archivesspace.get_record(@root_uri, @criteria)
        @has_containers = has_containers?(@root_uri)

        @repo_info = @result.repository_information
        @page_title = "#{I18n.t('resource._singular')}: #{strip_mixed_content(@result.display_string)}"
        @context = [{:uri => @repo_info['top']['uri'], :crumb => @repo_info['top']['name']}, {:uri => nil, :crumb => process_mixed_content(@result.display_string)}]
        fill_request_info

        #Fetching the linked instances and converting to 1-D array
        @digital_objects_list.each do |digital_instance|
          flattened_instance = digital_instance["results"].map{|x| x["linked_instances"]}
          @instance_uris =  flattened_instance.flatten.map{|x| x["ref"]}
          #Checking if record tree contains digital object linked record
          @has_digital_instance = Array.new
          @ordered_records = archivesspace.get_record(@root_uri + '/ordered_records').json.fetch('uris')
          @record_tree = @ordered_records.map{|x| x["ref"]}
          @has_digital_instance = !((@record_tree &  @instance_uris).empty?)
        end

      rescue RecordNotFound
        record_not_found(uri, 'resource')
      end
    end

    def tree_node_from_root
      @root_uri = "/repositories/#{params[:rid]}/resources/#{params[:id]}"
      render :json => archivesspace.get_raw_record(@root_uri + '/tree/node_from_root_' + params[:node_ids].first)
    rescue RecordNotFound
      render json: {}, status: 404
    end

    def infinite_resolve
      @resolve_uri = params[:resolve_uri];
      @result =  archivesspace.get_record(@resolve_uri)
      render partial: 'resources/infinite_item', locals: {:result => @result, :props => { :full => true}}
    end

    def raw_json
      begin
        render json: archivesspace.get_raw_record(params[:record_uri])
      rescue RecordNotFound
        record_not_found(uri,'Record');
      end
    end


    def get_dataid

      data_links = params[:data_links]
      identifiers=[];
      data_links.each do |data_link|
        #Fetching the records for the uri
        search_opts = default_search_opts(DEFAULT_OBJ_SEARCH_OPTS)
        raw_data=archivesspace.get_record(data_link,search_opts)
        badge_label="";
        #Creating the identifier
        if raw_data.level
          if raw_data.primary_type =~ /digital_object/
            level = I18n.t("enumerations.digital_object_level.#{raw_data.level}", :default => raw_data.level)
            badge_label = I18n.t("digital_object._public.badge_label", :level => level)
          else
            level = raw_data.level == 'otherlevel' ? raw_data.other_level : raw_data.level
            badge_label = I18n.t("enumerations.archival_record_level.#{level}", :default => level)
          end
        else
          badge_label = t("#{raw_data.primary_type}._singular")
        end

        if raw_data.container_summary_for_badge
          badge_label = raw_data.container_summary_for_badge.delete! ':'
          badge_label += ':'
        end

        comp_id = display_component_id(raw_data,true)
        unless comp_id.blank?
          badge_label+= " "+comp_id
          unless raw_data.container_summary_for_badge
            badge_label+= ": "
          end
        end
        #Adding identifier to array of identifiers
        identifiers.push(badge_label);
      end
      #Return list of identifiers
      render json: { identifiers:identifiers }

      rescue RecordNotFound
        record_not_found(uri, 'resource')
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

    # creates the html-ized search statement
    def set_search_statement
      rid = defined?(@repo_id) ? @repo_id : nil
      #    Pry::ColorPrinter.pp @search
      l = @search[:limit].blank? ? 'all' : @search[:limit]
      type = "<strong> #{I18n.t("search-limits.#{l}")}</strong>"
      type += I18n.t('search_results.in_repository', :name =>  CGI::escapeHTML(get_pretty_facet_value('repository', "/repositories/#{rid}"))) if rid

      Rails.logger.debug("TYPE: #{type}")
      condition = " "
      @search[:q].each_with_index do |q,i|
        # Updated the prepended and appended html content in each condition
        condition += ''
        if i == 0
          if !@search[:op][i].blank?
            condition += I18n.t("search_results.op_first_row.#{@search[:op][i]}", :default => "")
          end
        else
          condition += I18n.t("search_results.op.#{@search[:op][i]}", :default => "")
        end
        f = @search[:field][i].blank? ? 'keyword' : @search[:field][i]
        condition += ' ' + I18n.t("search_results.#{f}_contain", :kw =>  CGI::escapeHTML((q == '*' ? I18n.t('search_results.anything') : q)) )
        unless @search[:from_year][i].blank? &&  @search[:to_year][i].blank?
          from_year = @search[:from_year][i].blank? ? I18n.t('search_results.filter.year_begin') : @search[:from_year][i]
          to_year =  @search[:to_year][i].blank? ? I18n.t('search_results.filter.year_now') : @search[:to_year][i]
          condition += ' ' + I18n.t('search_results.filter.from_to', :begin => "<strong>#{from_year}</strong>", :end => "<strong>#{to_year}</strong>")
        end
        condition += '&nbsp;'
        Rails.logger.debug("Condition: #{condition}")
      end
      # Updated the :conditions and removed the html content
      @search[:search_statement] = I18n.t('search_results.search_for', :type => type,
                                          :conditions => "#{condition}")
    end

    # Changed the default facet types to exclude repositories
    DEFAULT_SEARCH_FACET_TYPES = ['primary_type', 'subjects', 'published_agents','langcode']
    def search
      @repo_id = params.fetch(:rid, nil)
      repo_url = "/repositories/#{@repo_id}"
      @base_search =  @repo_id ? "#{repo_url}/search?" : '/search?'
      fallback_location = @repo_id ? app_prefix(repo_url) : app_prefix('/search?reset=true');
      @new_search = fallback_location

      if params[:reset] == 'true'
        @reset = true
        params[:rid] = nil
        @search = Search.new(params)
        return render 'search/search_results'
      end

      search_opts = default_search_opts(DEFAULT_SEARCH_OPTS)
      search_opts['fq'] = ["repository:\"#{repo_url}\" OR used_within_published_repository::\"#{repo_url}\""] if @repo_id
      begin
        set_up_advanced_search(DEFAULT_TYPES, DEFAULT_SEARCH_FACET_TYPES, search_opts, params)
        #NOTE the redirect back here on error!
      rescue Exception => error
        Rails.logger.debug(error.message)
        p error
        flash[:error] = I18n.t('search_results.error')
        redirect_back(fallback_location: root_path ) and return
      end
      page = Integer(params.fetch(:page, "1"))
      Rails.logger.debug("base search: #{@base_search}")
      Rails.logger.debug("query: #{@query}")

      @results = archivesspace.advanced_search(@base_search, page, @criteria)
      @counts = archivesspace.get_types_counts(DEFAULT_TYPES)
      if @results['total_hits'].blank? ||  @results['total_hits'] == 0
        flash[:notice] = I18n.t('search_results.no_results')
        fallback_location = URI(fallback_location)
        fallback_location.query = URI(@base_search).query + "&reset=true"
        redirect_to(fallback_location.to_s)
      else
        process_search_results(@base_search)
        if @results['total_hits'] > 1
          @search[:dates_within] = true if params.fetch(:filter_from_year,'').blank? && params.fetch(:filter_to_year,'').blank?
          @search[:text_within] = true
        end
        @sort_opts = []
        all_sorts = Search.get_sort_opts
        all_sorts.keys.each do |type|
          @sort_opts.push(all_sorts[type])
        end
        render 'search/search_results'
      end
    end

  end

  class ClassificationsController
    def index
      repo_id = params.fetch(:rid, nil)
      if !params.fetch(:q, nil)
        DEFAULT_CL_SEARCH_PARAMS.each do |k,v|
          params[k] = v
        end
      end
      search_opts = default_search_opts( DEFAULT_CL_SEARCH_OPTS)
      search_opts['fq'] = ["repository:\"/repositories/#{repo_id}\""] if repo_id

      @base_search = repo_id ? "repositories/#{repo_id}/classifications?" : '/classifications?'
      page = Integer(params.fetch(:page, "1"))

      begin
        set_up_and_run_search( DEFAULT_CL_TYPES, DEFAULT_CL_FACET_TYPES, search_opts, params)
      rescue NoResultsError
        flash[:error] = I18n.t('search_results.no_results')
        redirect_back(fallback_location: '/') and return
      rescue Exception => error
        flash[:error] = I18n.t('errors.unexpected_error')
        redirect_back(fallback_location: '/') and return
      end

      if @results['total_hits'] > 1
        @search[:dates_within] = true if params.fetch(:filter_from_year,'').blank? && params.fetch(:filter_to_year,'').blank?
        @search[:text_within] = true
      end
      @sort_opts = []
      @sort_opts << [
          I18n.t('search_sorting.sorting', :type => I18n.t("search_sorting.classification_identifier"), :direction => I18n.t("search_sorting.asc")),
          IDENTIFIER_SORT_ASC
      ]
      @sort_opts << [
          I18n.t('search_sorting.sorting', :type => I18n.t("search_sorting.classification_identifier"), :direction => I18n.t("search_sorting.desc")),
          IDENTIFIER_SORT_DESC
      ]
      all_sorts = Search.get_sort_opts
      all_sorts.delete('relevance') unless params[:q].size > 1 || params[:q] != '*'
      all_sorts.keys.each do |type|
        next if type == 'year_sort'
        @sort_opts.push(all_sorts[type])
      end
      @page_title = I18n.t('classification._plural')
      @results_type = @page_title
      @no_statement = true
      # Updated the view

      render 'classifications/search_results'

    end

    # Method to fetch raw data for classification terms
    def term_json
      begin
        uri = "/repositories/#{params[:rid]}/classification_terms/#{params[:id]}"
        render json: archivesspace.get_raw_record(uri)
      rescue RecordNotFound
        record_not_found(uri, 'classification_term')
      end
    end

    def linked_records
      begin
        resources = []
        accessions = []
        params[:classifications].each do |classification|
          classification_data = archivesspace.get_raw_record(classification)
          classification_data['linked_records'].each do |linked_record|
            # Parse related accessions
            if linked_record['_resolved']['jsonmodel_type'] == 'accession' &&
                linked_record['_resolved']['publish'] == true &&
                linked_record['ref'] != params[:original_accession]
              accessions.push({ title: linked_record['_resolved']['title'], uri: linked_record['ref'] })
            end
            # Parse related collections
            if linked_record['_resolved']['jsonmodel_type'] == 'resource' &&
                linked_record['_resolved']['publish'] == true
              resources.push({ title: linked_record['_resolved']['title'], uri: linked_record['ref'] })
            end
          end
        end
        # return lists of accessions and collections
        render json: { accessions: accessions, resources: resources }
      rescue RecordNotFound
        record_not_found(uri, 'classification')
      end
    end
  end

  class ArchivesSpaceClient

    def search_digital_objects(base, repo_id, page = 1, search_opts = {},use_get=false)
      search_opts = DEFAULT_SEARCH_OPTS.merge(search_opts)

      url = build_url(base,search_opts.merge(:page => page))
      results = do_search(url,use_get)

    end
  end

  class Record
    def parse_repository_info
      info = {}
      info['top'] = {}
      unless resolved_repository.nil?
        %w(name uri url parent_institution_name image_url repo_code).each do | item |
          info['top'][item] = resolved_repository[item] unless resolved_repository[item].blank?
        end
        unless resolved_repository['agent_representation'].blank? || resolved_repository['agent_representation']['_resolved'].blank? || resolved_repository['agent_representation']['_resolved']['agent_contacts'].blank? || resolved_repository['agent_representation']['_resolved']['jsonmodel_type'] != 'agent_corporate_entity'
          in_h = resolved_repository['agent_representation']['_resolved']['agent_contacts'][0]
          %w{city region post_code country email }.each do |k|
            info[k] = in_h[k] if in_h[k].present?
          end
          if in_h['address_1'].present?
            info['address'] = []
            [1,2,3].each do |i|
              info['address'].push(in_h["address_#{i}"]) if in_h["address_#{i}"].present?
            end
          end
          info['telephones'] = in_h['telephones'] if !in_h['telephones'].blank?
        end
      end
      info
    end
  end
end