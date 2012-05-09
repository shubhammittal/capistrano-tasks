listen 3000
preload_app true
stderr_path "/tmp/unicorn.stderr.log"
stdout_path "/tmp/unicorn.stdout.log"
pid p(File.dirname(__FILE__) + "/../../tmp/pids/unicorn.pid")

require "capistrano-tasks/unicorn"

before_fork do |server, worker|
  CapistranoTasks::Unicorn.unicorn_before_fork
end
