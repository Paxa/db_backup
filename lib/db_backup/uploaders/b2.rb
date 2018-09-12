require 'uri'

class DbBackup::Uploaders::B2

  def initialize(options = {})
    b2_uri = URI.parse(options[:target])

    @b2_options = {
      account_id: b2_uri.user,
      account_token: b2_uri.password,
      bucket_name: b2_uri.host,
      path: b2_uri.path,
      path_wothout_slash: b2_uri.path.sub(/^\//, '')
    }

    @auth_file_path = "#{ENV["HOME"]}/.b2_account_info_#{@b2_options[:account_id]}"
    @env_vars = {
      "LC_ALL" => "en_US.UTF-8",
      "LANG" => "en_US.UTF-8",
      "B2_ACCOUNT_INFO" => @auth_file_path
    }.freeze
  end

  def ls(options = {})
    cmd_options = []
    if options[:recursive]
      cmd_options << '--recursive'
    end

    path = [@b2_options[:path_wothout_slash], options[:folder]].compact.join("/")

    res = b2_command(:ls, *cmd_options, @b2_options[:bucket_name], path)

    if res[:success]
      res[:stdout].split("\n").map do |line|
        line.sub(@b2_options[:path_wothout_slash] + "/", '')
      end
    else
      []
    end
  end

  def rm_dirs(remote_paths)
    res = b2_command("ls", "--long", "--recursive", @b2_options[:bucket_name], @b2_options[:path_wothout_slash])
    all_files = res[:stdout].split("\n").map do |line|
      m = line.match(/(?<file_id>[^\s]+)\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+([^\s]+)\s+(?<file_name>.+)$/)
      {
        name: m['file_name'].sub(@b2_options[:path_wothout_slash] + "/", ''),
        id: m['file_id']
      }
    end

    all_files.each do |file|
      if remote_paths.any? {|folder| file[:name].start_with?(folder) }
        DbBackup.logger.info("Deleting file #{file[:name]}")
        b2_command("delete-file-version", file[:id])
      end
    end
  end

  def sync(local_folder, remote_path)
    target_folder = ::File.join(@b2_options[:path_wothout_slash], remote_path)

    files_count = 0
    files_size = 0
    Dir["#{local_folder}/**/*"].count do |file|
      if ::File.file?(file)
        files_count += 1
        files_size += ::File.size(file)
      end
    end
    files_size_mb = (files_size / 1024.0 / 1024.0).round(3)

    DbBackup.logger.info("Uploading #{files_count} #{files_count == 1 ? "file" : "files"} (#{files_size_mb} MiB) " \
                         "to b2://#{@b2_options[:bucket_name]}/#{target_folder} ...")

    b2_command(:sync, local_folder, "b2://#{@b2_options[:bucket_name]}/#{target_folder}")
  end

  def b2_command(command, *args)
    unless ::File.exist?(@auth_file_path)
      DbBackup.cmd("b2", "authorize-account", @b2_options[:account_id], @b2_options[:account_token], @env_vars)
    end

    DbBackup.cmd("b2", command, *args, @env_vars)
  end

end
