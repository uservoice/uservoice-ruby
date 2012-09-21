require 'uservoice-ruby'
require 'yaml'

def config
  begin
    YAML.load_file(File.expand_path('../config.yml', __FILE__))
  rescue Errno::ENOENT
    raise "Configure your own config.yml and place it in the spec directory"
  end
end
