# util.rb - shared static methods/constants
require 'sequel'

# AH TODO we should read from options instead of hardcodeing
GIT_CONFIG = File.join(File.dirname(__FILE__), 'git-config.yaml')
DB_CONFIG  = File.join(File.dirname(__FILE__), 'dashboard-config.yaml')

# +config+ Hash of data needed to connect to database
# returns a Sequel handle to specified database
def get_db_handle(config)
  db_config = config[:database.to_s]
  engine    = db_config[:engine.to_s]

  if engine.eql?('postgres')
    require 'pg'
    # TODO ensure that all keys are provided
    user     = ENV['DB_USERNAME'] ? ENV['DB_ USERNAME'] : db_config[:username.to_s]
    puts user
    password = ENV['DB_PASSWORD'] ? ENV['DB_PASSWORD'] : db_config[:password.to_s]
    server   = ENV['DB_SERVER'] ? ENV['DB_SERVER'] : db_config[:server.to_s]
    puts server
    port     = ENV['DB_PORT'] ? ENV['DB_PORT'] : db_config[:port.to_s]
    database = ENV['DB_DATABSE'] ? ENV['DB_DATABSE'] : db_config[:database.to_s]
    return Sequel.connect(sprintf('postgres://%s:%s@%s:%s/%s', user, password, server, port, database))
  elsif engine.match(/sqlite3?/)
   # require 'sqlite3'
    # TODO check that dir is writable
    file = db_config[:filename.to_s]
    dir  = config['data-directory']

    Dir.mkdir(dir) unless File.exist?(dir)

    return Sequel.connect(sprintf('sqlite://%s/%s', dir, file))
  else
    raise StandardError.new(sprintf('unsupported database engine[%s]', config[:engine]))
  end
end

def db_exists?(config)
  puts config
  db_config = config[:database.to_s]
  engine    = db_config[:engine.to_s]

  if engine.eql?('postgres')
    dbh = get_db_handle(config)
    begin
      tables = dbh.tables
      return ! tables.empty?
    rescue => e # TODO need to be more specific about which exception we're catching
      init_postgres_db(config)
      return false
    end

  elsif engine.eql?('sqlite3')
    File.exist?(db_config[:filename.to_s])
  end

end

def init_postgres_db(config)
  `createdb --owner postgres oss-dashboard` # TODO pull this out of configuration
end
