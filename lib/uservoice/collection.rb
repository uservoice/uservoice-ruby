module UserVoice
  class Collection
    def initialize(client, query, opts={})
      @client = client
      @query = query
      @limit = opts[:limit] || 2**60
      @per_page = [@limit, 500].min
      @pages = {}
    end

    def first
      load_record(0)
    end

    def last
      load_record(size() - 1)
    end

    def size
      if @response_data.nil?
        load_record(0)
      end
      @response_data['total_records']
    end

    def map
      index = 0
      records = []
      while record = load_record(index)
        records.push(yield record)
        index += 1
      end
      return records
    end
    alias collect map

    def each
      map do |value|
        yield value
        value
      end
    end
        
    private

    def load_record(i)
      load_page((i/500.0).floor + 1)[i%500]
    end

    def load_page(i)
      if @pages[i].nil?
        result = @client.get("#{@query}#{@query.include?('?') ? '&' : '?'}per_page=#{@per_page}&page=#{i}")

        if @response_data = result.delete('response_data')
          @pages[i] = result.shift.last if result.first
        else
          raise UserVoice::NotFound.new('The resource you requested is not a collection')
        end
      end
      return @pages[i]
    end
  end
end
