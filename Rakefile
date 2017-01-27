require 'rake'
require 'yaml'


desc 'collect data from github.com and output to database'
task :doit do # not sure this is the right name
  sh sprintf('ruby refresh-dashboard.rb %s', 'dashboard-config_postgres.yaml')
end

# desc 'bootstrap postgres database'
# task :bootstrap do # this is not the right name
#   init_postgres_db(YAML.file_load('dashboard-config.yaml'))
# end
