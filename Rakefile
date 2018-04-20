require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

def child_pids_recursive(pid)
  # get children
  pipe = IO.popen("ps -ef | grep #{pid}")

  child_pids = pipe.readlines.map do |line|
    parts = line.split(/\s+/)
    parts[2] if parts[3] == pid.to_s && parts[2] != pipe.pid.to_s
  end.compact

  pipe.close

  # get grandchildren
  grandchild_pids = child_pids.map do |cpid|
    child_pids_recursive(cpid)
  end.flatten

  child_pids + grandchild_pids
end

def kill_all(pid)
  child_pids_recursive(pid).reverse.each do |p|
    begin
      Process.kill('TERM', p.to_i)
    rescue
      # ignore
    end
  end
end

task :server do
  pid = 0
  children = []
  Bundler.with_clean_env do
    nul = RbConfig::CONFIG['host_os'] =~ /mswin|mingw/ ? 'nul' : '/dev/null'
    pid = spawn "bundle exec puma 'spec/chat_server.ru' 2>#{nul}"
  end

  at_exit do
    $stderr.puts "Killing pid #{pid}"
    kill_all(pid)
  end

  sleep 3
end

task :spec => :server

task default: :spec
