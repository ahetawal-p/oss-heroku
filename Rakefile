require 'rake'
require 'yaml'


desc 'collect data from github.com and output to database'
task :doit do # not sure this is the right name
	sh 'rm -rf /app/vendor/bundle/ruby/2.2.0/extensions/x86_64-linux/2.2.0-static/libxslt-ruby-1.1.1'
	sh 'gem pristine libxslt-ruby --version 1.1.1'
  	sh sprintf('ruby refresh-dashboard.rb %s', 'dashboard-config_postgres.yaml')
end

# desc 'bootstrap postgres database'
# task :bootstrap do # this is not the right name
#   init_postgres_db(YAML.file_load('dashboard-config.yaml'))
# end
