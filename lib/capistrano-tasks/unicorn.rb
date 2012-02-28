
# define a task for a rails app running in unicorn
def def_unicorn(_namespace, opt = {})
  roles = opt[:roles] || :app

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
    
    # Set unicorn vars
    #
    _cset(:unicorn_pid, "#{fetch(:current_path)}/tmp/pids/unicorn.pid")
    _cset(:app_env, (fetch(:rails_env) rescue 'production'))
    _cset(:unicorn_env, (fetch(:app_env)))
    _cset(:unicorn_bin, "unicorn")
    
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
        run "#{try_sudo} kill -s HUP `cat #{unicorn_pid}`"
      else
        start
      end
    end
  end
  
  # after "deploy:restart", "unicorn:reload"
end
