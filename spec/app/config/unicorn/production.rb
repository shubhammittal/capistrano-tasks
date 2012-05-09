listen 3000
preload_app true
stderr_path "/tmp/unicorn.stderr.log"
stdout_path "/tmp/unicorn.stdout.log"
pid p(File.dirname(__FILE__) + "/../../tmp/pids/unicorn.pid")

require "capistrano-tasks/unicorn"
CapistranoTasks::Unicorn.unicorn_configuration(self)
