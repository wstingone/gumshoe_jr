require 'rsolr-ext'

module Formats 
  def get_formats(solr,colId) 
    solr_params = {
      :q => "colId:" + colId,
      :rows => 0,
      :facet => true, 
      :facets =>{:fields => ["fileType"]}
    }

    request = solr.find solr_params, :method => :post
    size = 20
    count = 0
    formats = Hash.new
    current_format = nil     
    
    format_hash =  request.facet_counts['facet_fields']['fileType']
    
    if format_hash.size > 20
      format_hash.each do |format|  
        if count < size
          if count % 2 == 0
            puts format
            current_format = format
          else
            formats[current_format] = format
          end
        end
        count += 1
      end
    else
      puts "LESS THAN 20"
      format_hash.each do |format|  
        if count % 2 == 0
          current_format = format
        else
          formats[current_format] = format
        end
      count += 1
      end
    end
    formats
  end
end