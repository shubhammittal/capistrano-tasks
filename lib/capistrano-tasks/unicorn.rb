
# define a task for a rails app running in unicorn
module CapistranoTasks
  module Unicorn

    # call this function from your unicorn configuration
    def self.unicorn_before_fork
      system("kill -QUIT `cat tmp/pids/unicorn.pid.oldbin`")
    end

    def self.load_into(configuration, _namespace, opt = {})
      configuration.load do

        # This code is modified from the capistrano-unicorn gem:
        # https://github.com/sosedoff/capistrano-unicorn/
        
        # Check if remote file exists
        #
        def remote_file_exists?(full_path)
          puts "checking for remote file #{full_path}"
          'true' == capture("if [ -e #{full_path} ]; then echo 'true'; fi").strip
        end
        
        # Check if process is running
        #
        def process_exists?(pid_file)
          pid = capture("cat #{pid_file} || true").strip
          return if pid == ""
          capture("kill -0 #{pid} && echo 'true'").strip == "true"
        end

        def unicorn_send_signal(signal, raise_on_error = false)
          if remote_file_exists?(unicorn_pid)
            if process_exists?(unicorn_pid)
              logger.important("Sending #{signal}...", "Unicorn")
              run "kill -#{signal} `cat #{unicorn_pid}`"
              return
            end
          end
          if raise_on_error
            raise "unicorn process does not exist"
          end
        end

        roles = opt[:roles] || :app
        bootup_timeout = opt[:bootup_timeout] || 30
        workers = opt[:workers] || 2
        
        namespace _namespace do
          
          
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
          

          desc 'send TTIN signal (increment workers by 1)'
          task :increment, :roles => roles, :exception => { :no_release => true } do
            unicorn_send_signal("TTIN")
          end

          desc 'send TTOU signal (decrement workers by 1)'
          task :decrement, :roles => roles, :exception => { :no_release => true } do
            unicorn_send_signal("TTOU")
          end

          desc 'Check current unicorn status'
          task :status, :roles => roles, :except => { :no_release => true } do
            run("false") if !remote_file_exists?(unicorn_pid)
          end

          desc 'Stop Unicorn'
          task :stop, :roles => roles, :except => {:no_release => true} do
            if remote_file_exists?(unicorn_pid)
              if process_exists?(unicorn_pid)
                logger.important("Stopping...", "Unicorn")
                run "kill `cat #{unicorn_pid}`"
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
                run "kill -s QUIT `cat #{unicorn_pid}`"
              else
                run "rm #{unicorn_pid}"
                logger.important("Unicorn is not running.", "Unicorn")
              end
            else
              logger.important("No PIDs found. Check if unicorn is running.", "Unicorn")
            end
          end

          desc 'wait till unicorn no longer exists'
          task :wait_till_dead, :roles => roles, :exception => { :no_release => true } do
            while remote_file_exists?(unicorn_pid) && process_exists?(unicorn_pid)
              puts "still running"
            end
          end
          
          desc 'Reload Unicorn'
          task :reload, :roles => roles, :except => {:no_release => true} do
            if remote_file_exists?(unicorn_pid) && process_exists?(unicorn_pid)
              logger.important("Reloading...", "Unicorn")
              
              # The re-spawning algorithm is taken from:
              # http://unicorn.bogomips.org/SIGNALS.html

              old_pid = capture("cat #{unicorn_pid}")
              
              # Spawn off a new master and it's workers.
              unicorn_send_signal("USR2")

              # make sure that the oldbin was at least created
              while !remote_file_exists?(unicorn_pid + ".oldbin")
                sleep 0.1
              end

              # now wait for the oldbin to go away, that's the
              # indication that we have just one master now.
              while remote_file_exists?(unicorn_pid + ".oldbin")
                logger.info("Waiting for old process to die")
                sleep 1
              end
              
              # TODO(@myprasanna): Replace this with proper checks.
              puts "Sleeping #{bootup_timeout} seconds for the servers to startup..."
              sleep bootup_timeout

              # at this point, we need to verify that the new process
              # is not the old process, that is: the new process did
              # not die (if it did, the the old process will take back
              # the pid file: I can't prove this by documentation but
              # this is what I observed.)
              run "test x`cat #{unicorn_pid}` != 'x#{old_pid}'"
            else
              start
            end
          end
        end
      end
    end
  end
end

## Pass "self" to configuration if you're calling it from deploy.rb or similar
##
def def_unicorn(configuration, _namespace, opts) 
  raise "invalid configuration object" unless configuration.instance_of? Capistrano::Configuration
  CapistranoTasks::Unicorn.load_into(Capistrano::Configuration.instance, _namespace, opts)
end
