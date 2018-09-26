require 'fileutils'
require 'uri'
require 'json'

class DbBackup::Uploaders::S3

  def initialize(options = {})
    @s3_url = options[:source].sub(%r{^s3://}, 'https://')
    @s3_path = URI.parse(@s3_url).path.sub(/^\//, '')

    @s3_url.sub!(/\/#{@s3_path}/, '')
    @s3_path = "s3/" + @s3_path

    @env_vars = {
      "MC_HOSTS_s3" => @s3_url
    }
  end

  def ls(options = {})
    cmd_options = ["--json"]
    if options[:recursive]
      cmd_options << '--recursive'
    end

    res = s3_command(:ls, @s3_path, *cmd_options)

    res[:stdout].to_s.split("\n").map do |line|
      ::JSON.parse(line)['key'].sub(/\/$/, '')
    end
  end

  def sync(local_folder, remote_path)
    DbBackup.logger.info("Creating folder #{@s3_path}/#{remote_path}")
    s3_command(:mb, "#{@s3_path}/#{remote_path}/")

    s3_command(:mirror, local_folder, "#{@s3_path}/#{remote_path}")
  end

  def rm_dirs(remote_paths)
    remote_paths.each do |path|
      DbBackup.logger.info("Deleting folder #{@s3_path}/#{path}")
      s3_command(:rm, "#{@s3_path}/#{path}", "-r", "--force")
    end
  end

  def s3_command(command, *args)
    DbBackup.cmd("mc", command, *args, @env_vars)
  end
end
