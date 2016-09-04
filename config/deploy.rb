#---------------------------------------------------------------------------------------------------------------------
# deploy avec capistrano V3
#---------------------------------------------------------------------------------------------------------------------
#
# ce script de deploiement n'est utilisé que pour déployer les composants executable sur une machine linux
# qui partage ces composants pour des machines windows.
# aucune execution ne sera réalisée sur la machine cible de déploiement.
# toutes les machines exécutant ces composants quelles soient linix ou windows devront pointer sur ces composants.
# les données ou fichiers produits par l'exécution des composants seront stockés localement à la machine linux ou
# windows exécutante.
#
#---------------------------------------------------------------------------------------------------------------------
#
# actions à réalisées sur la machine d'exécution linux ou windows
# la connection au répertoire :deploy_to/current
# le runtime ruby être deployé
# les gem doivent être déployé et maintenu   (bundle install)
# le reboot quotidien de la machine (shutdown /r /f /t 0,
# http://www.isunshare.com/windows-10/4-ways-to-set-auto-shutdown-in-windows-10.html
# http://www.tenforums.com/tutorials/7370-restart-computer-windows-10-a.html)
# suppression de la mire log pour ouvrir une session (http://www.windows8facile.fr/w10-supprimer-mot-de-passe-demarrage/)
# le lancement des serveurs  lors de louverture de la session : dans le répertoire de demarrage, creer un raccourci
# à controler => la purge hebdomadaire des répertoires de travail ('log', 'tmp', 'output', 'archive') (del /F /S /Q d:\statupbot)
# ---------------------------------------------------------------------------------------------------------------------
#
# avant tout deploy, il faut publier sur https://devscrapper/statupbot.git avec la commande
# git push origin master
#
# pour deployer dans un terminal avec ruby 223 dans la path : cap production deploy
# cette commande prend en charge :
# la publication des sources vers le serveur cible
# la publication des fichiers de paramètrage
# les liens du current vers les relaease
#---------------------------------------------------------------------------------------------------------------------

lock '3.4.1'

set :application, 'statupbot_v4'
set :repo_url, "https://github.com/devscrapper/#{fetch(:application)}.git/"
set :github_access_token, '64c0b7864a901bc6a9d7cd851ab5fb431196299e'
set :default, 'master'
set :user, 'eric'
set :pty, true
set :use_sudo, false
set :deploy_to, "/home/#{fetch(:user)}/apps/statupbot"
set :rvm_ruby_version, '2.2.3'
set :server_list, []


# Default branch is :master
# ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
# set :deploy_to, '/var/www/my_app_name'

# Default value for :scm is :git
# set :scm, :git

# Default value for :format is :pretty
# set :format, :pretty

# Default value for :log_level is :debug
set :log_level, :debug

# Default value for :pty is false
#set :pty, true

# Default value for :linked_files is []
#set :linked_files, fetch(:linked_files, [])

# Default value for linked_dirs is []
#set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp', 'output', 'input', 'data', 'archive')

# Default value for default_env is {}
set :default_env, {path: "/opt/ruby/bin:$PATH"}

# Default value for keep_releases is 5
set :keep_releases, 3

#before 'deploy:check:linked_files', 'config:push'

# before 'deploy:starting', 'github:deployment:create'
# after  'deploy:starting', 'github:deployment:pending'
# after  'deploy:finished', 'github:deployment:success'
# after  'deploy:failed',   'github:deployment:failure'

#----------------------------------------------------------------------------------------------------------------------
# task list : git push
#----------------------------------------------------------------------------------------------------------------------
namespace :git do
  task :push do
    on roles(:all) do
      run_locally do
        system 'git push origin master'
      end
    end
  end
end
#----------------------------------------------------------------------------------------------------------------------
# task list : deploy
#----------------------------------------------------------------------------------------------------------------------
namespace :deploy do
  task :bundle_install do
    on roles(:app) do
      within release_path do
       # le bundle doit être réalisé sur la machine d'exécution pas sur la machine contenant les exécutable/sources
       # execute :bundle, "--gemfile Gemfile --path #{shared_path}/bundle  --binstubs #{shared_path}bin --without [:development]"
      end
    end
  end

  task :environment do
    on roles(:app) do
      within release_path do
        execute("echo 'staging: test' >  #{File.join(current_path, 'parameter', 'environment.yml')}")
      end
    end
  end

  task :environment do
      on roles(:app) do
        within release_path do
          # permet d'ecrire la tranformation de reposirory en win32.xml, win64.xml linu.xml mac.xml
          execute("echo 'staging: test' >  #{File.join(current_path, 'parameter', 'environment.yml')}")
          execute("echo 'os: :windows' >>  #{File.join(current_path, 'parameter', 'environment.yml')}")
          execute("echo 'os_version: :seven' >>  #{File.join(current_path, 'parameter', 'environment.yml')}")
        end
      end
    end
end



after 'deploy:finished', "deploy:environment"
before 'deploy:updating', "git:push"

