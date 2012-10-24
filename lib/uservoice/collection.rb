module UserVoice
  class Collection
    PER_PAGE = 100

    def initialize(client, query, opts={})
      @client = client
      @query = query
      @limit = opts[:limit] || 2**60
      @per_page = [@limit, PER_PAGE].min
      @pages = {}
    end

    def first
      self[0]
    end

    def last
      self[size() - 1]
    end

    def size
      if @response_data.nil?
        self[0]
      end
      [@response_data['total_records'], @limit].min
    end

    def map
      index = 0
      records = []
      while record = self[index]
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

    def to_a
      each {}
    end
        
    def [](i)
      load_page((i/PER_PAGE.to_f).floor + 1)[i%PER_PAGE] if (0..@limit-1).include?(i)
    end

    private


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
