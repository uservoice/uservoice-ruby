module UserVoice
  module UriParameters
    
    def self.concat_keys_to_params(node, prefix=nil, hash=nil)
      hash ||= {}

      if node.is_a?(Hash)
        node.each do |key,value|
          concat_keys_to_params(value, "#{prefix}[#{key}]", hash)
        end
      elsif node.is_a?(Array)
        node.each_with_index do |element,index|
          concat_keys_to_params(element, "#{prefix}[#{index}]", hash)
        end
      elsif node.is_a?(String)
        hash["#{prefix}"] = node
      else
        hash["#{prefix}"] = node.to_s
      end
      return hash
    end
  end
end