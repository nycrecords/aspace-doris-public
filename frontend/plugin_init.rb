Rails.application.config.after_initialize do

  class ApplicationController

    def params_for_backend_search
      sc = SearchController.new
      #Added page size for search parameters
      params_for_search = params.select{|k,v| ["page","page_size", "q", "aq", "type", "sort", "exclude", "filter_term", "fields"].include?(k) and not v.blank?}

      params_for_search["page"] ||= 1
      #Default page size, if the size is not provided
      params_for_search["page_size"] ||= 10

      if params_for_search["type"]
        params_for_search["type[]"] = Array(params_for_search["type"]).reject{|v| v.blank?}
        params_for_search.delete("type")
      end

      if params_for_search["filter_term"]
        params_for_search["filter_term[]"] = Array(params_for_search["filter_term"]).reject{|v| v.blank?}
        params_for_search.delete("filter_term")
      end

      if params_for_search["aq"]
        # Just validate it
        params_for_search["aq"] = JSONModel(:advanced_query).from_json(params_for_search["aq"]).to_json
      end

      if params_for_search["exclude"]
        params_for_search["exclude[]"] = Array(params_for_search["exclude"]).reject{|v| v.blank?}
        params_for_search.delete("exclude")
      end

      if params_for_search["fields"]
        params_for_search["fields[]"] = Array(params_for_search["fields"]).reject{|v| v.blank?}
        params_for_search.delete("fields")
      end
      params_for_search
    end

  end
end