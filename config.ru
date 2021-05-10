# This file is used by Rack-based servers to start the application.

require_relative "config/environment"

base_path = ENV['RAILS_RELATIVE_URL_ROOT'] || "/"
map base_path do
  run Rails.application
end

Rails.application.load_server
Rails.logger.info "Running application on base path: %s" % base_path
