
# define a task for a rails app running in unicorn
module CapistranoTasks
  module Unicorn
    def self.load_into(configuration, _namespace, opt = {})
      configuration.load do
        
        roles = opt[:roles] || :app
        bootup_timeout = opt[:bootup_timeout] || 30
        workers = opt[:workers] || 2
        
        namespace _namespace do
          
          # This code is modified from the capistrano-unicorn gem:
          # https://github.com/sosedoff/capistrano-unicorn/
          
          # Check if remote file exists
          #
          def remote_file_exists?(full_path)
            'true' == capture("if [ -e #{full_path} ]; then echo 'true'; fi").strip
          end
          
          # Check if process is running
          #
          def process_exists?(pid_file)
            capture("ps -p $(cat #{pid_file}) ; true").strip.split("\n").size == 2
          end
          
          # Grep for something.
          #
          def grep_proc_cnt(what)
            op = capture("ps aux | grep '#{what}' | grep -v grep").strip
            puts op
            op.split("\n").length
          end
          
          # Set unicorn vars
          #
          set(:unicorn_pid, "#{fetch(:current_path)}/tmp/pids/unicorn.pid")
          set(:app_env, (fetch(:rails_env) rescue 'production'))
          set(:unicorn_env, (fetch(:app_env)))
          set(:unicorn_bin, "unicorn")
          set(:bootup_timeout, bootup_timeout)
          
          desc 'Start Unicorn'
          task :start, :roles => roles, :except => {:no_release => true} do
            if remote_file_exists?(unicorn_pid)
              if process_exists?(unicorn_pid)
                logger.important("Unicorn is already running!", "Unicorn")
                next
              else
                run "rm #{unicorn_pid}"
              end
            end
            
            config_path = "#{current_path}/config/unicorn/#{app_env}.rb"
            if remote_file_exists?(config_path)
              logger.important("Starting...", "Unicorn")
              run "cd #{current_path} && BUNDLE_GEMFILE=#{current_path}/Gemfile bundle exec #{unicorn_bin} -c #{config_path} -E #{app_env} -D"
            else
              logger.important("Config file for \"#{unicorn_env}\" environment was not found at \"#{config_path}\"", "Unicorn")
            end
          end
          
          desc 'Stop Unicorn'
          task :stop, :roles => roles, :except => {:no_release => true} do
            if remote_file_exists?(unicorn_pid)
              if process_exists?(unicorn_pid)
                logger.important("Stopping...", "Unicorn")
                run "#{try_sudo} kill `cat #{unicorn_pid}`"
              else
                run "rm #{unicorn_pid}"
                logger.important("Unicorn is not running.", "Unicorn")
              end
            else
              logger.important("No PIDs found. Check if unicorn is running.", "Unicorn")
            end
          end
          
          desc 'Unicorn graceful shutdown'
          task :graceful_stop, :roles => roles, :except => {:no_release => true} do
            if remote_file_exists?(unicorn_pid)
              if process_exists?(unicorn_pid)
                logger.important("Stopping...", "Unicorn")
                run "#{try_sudo} kill -s QUIT `cat #{unicorn_pid}`"
              else
                run "rm #{unicorn_pid}"
                logger.important("Unicorn is not running.", "Unicorn")
              end
            else
              logger.important("No PIDs found. Check if unicorn is running.", "Unicorn")
            end
          end
          
          desc 'Reload Unicorn'
          task :reload, :roles => roles, :except => {:no_release => true} do
            if remote_file_exists?(unicorn_pid) && process_exists?(unicorn_pid)
              logger.important("Stopping...", "Unicorn")
              
              # The re-spawning algorithm is taken from:
              # http://unicorn.bogomips.org/SIGNALS.html
              
              run "cp #{unicorn_pid} #{unicorn_pid}.old"
              old_pid = "`cat #{unicorn_pid}.old`"
              
              # Spawn off a new master and it's workers.
              run "kill -s USR2 #{old_pid}"
              while grep_proc_cnt('unicorn worker')!= workers * 2
                sleep 1
              end
              
              # TODO(@myprasanna): Replace this with proper checks.
              puts "Sleeping for the servers to startup..."
              sleep 60
              
              # Ask the old master to gracefully shut down.
              run "kill -s WINCH #{old_pid}"
              while grep_proc_cnt('unicorn worker') != workers
                sleep 1
              end
              
              # Now that the workers are down, kill the old master.
              run "kill -s QUIT #{old_pid}"
              while grep_proc_cnt('unicorn master') != 1
                sleep 1
              end
              
            else
              start
            end
          end
        end
      end
    end
  end
end

def def_unicorn(_namespace, opts) 
  CapistranoTasks::Unicorn.load_into(Capistrano::Configuration.instance, _namespace, opts)
end
